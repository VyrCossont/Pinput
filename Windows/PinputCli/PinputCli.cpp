#ifndef UNICODE
#define UNICODE 1
#endif

#include <iostream>
#include <vector>

#include <Windows.h>
#include <Psapi.h>
#include <memoryapi.h>
#include <processthreadsapi.h>
#include <handleapi.h>
#include <errhandlingapi.h>
#include <WinBase.h>
#include <Shlwapi.h>

constexpr const wchar_t* pico8ExecutableName = L"pico8.exe";

/// <summary>
/// Print the last error from a Windows API function to stderr.
/// </summary>
void printLastError() {
    DWORD error = GetLastError();
    LPWSTR errorMessage = NULL;
    DWORD errorMessageSize = FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER
        | FORMAT_MESSAGE_FROM_SYSTEM
        | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPWSTR)&errorMessage,
        0,
        NULL
    );
    if (errorMessageSize) {
        std::wcerr << "We biffed it: " << std::wstring(errorMessage) << std::endl;
    }
    else {
        std::wcerr << "We biffed it so badly that FormatMessage failed with error " << GetLastError() << std::endl;
    }
}

/// <summary>
/// List processes we can see.
/// </summary>
/// <returns>Vector of PIDs, empty if something went wrong.</returns>
std::vector<DWORD> listPids() {
    DWORD numPidsReserved = 1024;
    DWORD pidsReturnedSize;
    DWORD numPidsReturned;
    DWORD* pidsArray = new DWORD[numPidsReserved];
    for (;;) {
        BOOL ok = K32EnumProcesses(pidsArray, numPidsReserved * sizeof DWORD, &pidsReturnedSize);
        if (!ok) {
            printLastError();
            return std::vector<DWORD>();
        }
        numPidsReturned = pidsReturnedSize / sizeof DWORD;
        if (numPidsReturned < numPidsReserved) {
            break;
        }
        delete[] pidsArray;
        numPidsReserved *= 2;
        pidsArray = new DWORD[numPidsReserved];
    }
    std::vector<DWORD> pids(pidsArray, pidsArray + numPidsReturned);
    delete[] pidsArray;
    return pids;
}

/// <summary>
/// Find PICO-8.
/// </summary>
/// <returns>A handle to a PICO-8 process, or NULL if not found.</returns>
HANDLE findPico8Process() {
    auto pids = listPids();
    if (pids.size() == 0) {
        // This shouldn't ever happen except maybe in a sandbox?
        std::wcerr << "Couldn't list any processes!" << std::endl;
        return NULL;
    }

    for (auto& pid : pids) {
        HANDLE processHandle = OpenProcess(
            PROCESS_QUERY_INFORMATION
            | PROCESS_VM_READ
            | PROCESS_VM_WRITE,
            FALSE,
            pid
        );
        if (!processHandle) {
            // This is common because we won't have permissions to open system processes.
            continue;
        }

        wchar_t processExecutablePath[MAX_PATH];
        DWORD processExecutablePathLength = GetProcessImageFileName(
            processHandle,
            processExecutablePath,
            MAX_PATH
        );
        if (!processExecutablePathLength) {
            std::wcerr << "GetProcessImageFileName failed for PID " << pid << ": ";
            printLastError();
        }
        else {
            LPWSTR processExecutableName = PathFindFileName(processExecutablePath);
            if (PathMatchSpecEx(
                processExecutableName,
                pico8ExecutableName,
                PMSF_NORMAL
            ) == S_OK) {
                return processHandle;
            }
        }

        BOOL ok = CloseHandle(processHandle);
        if (!ok) {
            std::wcerr << "CloseHandle failed for PID " << pid << ": ";
            printLastError();
        }
    }

    return NULL;
}

/// <summary>
/// Find module belonging to PICO-8 executable within its process.
/// </summary>
/// <param name="pico8Handle">Handle to PICO-8 process.</param>
/// <returns>Module corresponding to pico8.exe, or NULL if not found.</returns>
HMODULE findPico8Module(HANDLE pico8Handle) {
    BOOL ok;

    DWORD modulesSizeNeeded;
    ok = EnumProcessModulesEx(
        pico8Handle,
        NULL,
        0,
        &modulesSizeNeeded,
        LIST_MODULES_ALL
    );
    if (!ok) {
        std::wcerr << "EnumProcessModulesEx (no module array) failed on PICO-8 handle: ";
        printLastError();
        return NULL;
    }
    DWORD numModules = modulesSizeNeeded / sizeof HMODULE;
    HMODULE* modules = new HMODULE[numModules];
    ok = EnumProcessModulesEx(
        pico8Handle,
        modules,
        numModules * sizeof HMODULE,
        &modulesSizeNeeded,
        LIST_MODULES_ALL
    );
    if (!ok) {
        std::wcerr << "EnumProcessModulesEx (with module array) failed on PICO-8 handle: ";
        printLastError();
        return NULL;
    }
    std::wcout << "Found " << numModules << " modules" << std::endl;

    for (DWORD i = 0; i < numModules; i++) {
        auto module = modules[i];

        wchar_t moduleFilename[MAX_PATH];
        DWORD moduleFilenameLength = GetModuleBaseName(pico8Handle, module, moduleFilename, MAX_PATH);
        if (!moduleFilenameLength) {
            // We're looking for PICO-8, so modules without names aren't it.
            continue;
        }

        if (PathMatchSpecEx(
            moduleFilename,
            pico8ExecutableName,
            PMSF_NORMAL
        ) == S_OK) {
            delete[] modules;
            return module;
        }
    }

    delete[] modules;
    return NULL;
}

int main()
{
    BOOL ok;

    HANDLE pico8Handle = findPico8Process();
    if (!pico8Handle) {
        std::wcerr << "Couldn't find a running PICO-8 process!" << std::endl;
        return EXIT_FAILURE;
    }

    DWORD pico8Pid = GetProcessId(pico8Handle);
    if (!pico8Pid) {
        std::wcerr << "GetProcessId failed on PICO-8 handle: ";
        printLastError();
        return EXIT_FAILURE;
    }
    std::wcout << "PICO-8 PID = " << pico8Pid << std::endl;

    HMODULE pico8Module = findPico8Module(pico8Handle);
    if (!pico8Module) {
        std::wcerr << "Couldn't find a PICO-8 module within the PICO-8 process!" << std::endl;
        return EXIT_FAILURE;
    }
    std::wcout << "PICO-8 module = " << pico8Module << std::endl;

    MODULEINFO moduleInfo;
    ok = GetModuleInformation(pico8Handle, pico8Module, &moduleInfo, sizeof MODULEINFO);
    if (!ok) {
        std::wcerr << "GetModuleInformation failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return EXIT_FAILURE;
    }
    std::wcout << "    lpBaseOfDll = " << moduleInfo.lpBaseOfDll << std::endl;
    std::wcout << "    SizeOfImage = " << moduleInfo.SizeOfImage << std::endl;
    std::wcout << "    EntryPoint = " << moduleInfo.EntryPoint << std::endl;

    // TODO: read entire module into our process memory with ReadProcessMemory

    // TODO: find offset of Pinput magic bytes 0220c74677ab446ebedc7fd6d277984d within that module
    //  lpBaseOfDll = 00400000
    //  SizeOfImage = 5206016
    //  EntryPoint = 004014C0
    //  Cheat Engine shows the magic at pico8.exe+45DB9C,
    //  which is consistent with the above,
    //  and pico8.exe doesn't appear to use ASLR

    // TODO: calculate area corresponding to cartridge RAM

    // TODO: read only that area in future

    // TODO: try writing back changes with WriteProcessMemory

    // TODO: can we get XInput events in a console app?
    
    ok = CloseHandle(pico8Handle);
    if (!ok) {
        std::wcerr << "CloseHandle failed on PICO-8 handle: ";
        printLastError();
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}
