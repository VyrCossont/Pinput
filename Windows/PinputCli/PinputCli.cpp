#ifndef UNICODE
#define UNICODE 1
#endif

#include <algorithm>
#include <iomanip>
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
constexpr const uint8_t pinputMagic[] = {
    0x02, 
    0x20,
    0xc7,
    0x46,
    0x77,
    0xab,
    0x44,
    0x6e,
    0xbe,
    0xdc,
    0x7f,
    0xd6,
    0xd2,
    0x77,
    0x98,
    0x4d,
};

constexpr DWORD pico8GpioOffsetFromCartridgeRamBase = 0x5f80;
constexpr DWORD pico8GpioSize = 0x80;
constexpr DWORD pico8RegularMemorySize = 0x8000;
constexpr DWORD pico8ExtendedMemorySize = 0x10000;

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
/// <param name="pico8Process">Handle to PICO-8 process.</param>
/// <returns>Module corresponding to pico8.exe, or NULL if not found.</returns>
HMODULE findPico8Module(HANDLE pico8Process) {
    BOOL ok;

    DWORD modulesSizeNeeded;
    ok = EnumProcessModulesEx(
        pico8Process,
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
        pico8Process,
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
        DWORD moduleFilenameLength = GetModuleBaseName(pico8Process, module, moduleFilename, MAX_PATH);
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

    HANDLE pico8Process = findPico8Process();
    if (!pico8Process) {
        std::wcerr << "Couldn't find a running PICO-8 process!" << std::endl;
        return EXIT_FAILURE;
    }

    DWORD pico8Pid = GetProcessId(pico8Process);
    if (!pico8Pid) {
        std::wcerr << "GetProcessId failed on PICO-8 handle: ";
        printLastError();
        return EXIT_FAILURE;
    }
    std::wcout << "PICO-8 PID = " << pico8Pid << std::endl;

    HMODULE pico8Module = findPico8Module(pico8Process);
    if (!pico8Module) {
        std::wcerr << "Couldn't find a PICO-8 module within the PICO-8 process!" << std::endl;
        return EXIT_FAILURE;
    }
    std::wcout << "PICO-8 module = " << pico8Module << std::endl;

    MODULEINFO moduleInfo;
    ok = GetModuleInformation(pico8Process, pico8Module, &moduleInfo, sizeof MODULEINFO);
    if (!ok) {
        std::wcerr << "GetModuleInformation failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return EXIT_FAILURE;
    }
    std::wcout << "    lpBaseOfDll = " << moduleInfo.lpBaseOfDll << std::endl;
    std::wcout << "    SizeOfImage = " << moduleInfo.SizeOfImage << std::endl;
    std::wcout << "    EntryPoint = " << moduleInfo.EntryPoint << std::endl;

    // Read entire module into our process memory.
    uint8_t* entireModuleBytes = new uint8_t[moduleInfo.SizeOfImage];
    uint8_t* entireModuleBytesEnd = entireModuleBytes + moduleInfo.SizeOfImage;
    size_t numBytesRead;
    ok = ReadProcessMemory(
        pico8Process,
        moduleInfo.lpBaseOfDll,
        entireModuleBytes,
        moduleInfo.SizeOfImage,
        &numBytesRead
    );
    if (!ok) {
        std::wcerr << "ReadProcessMemory failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return EXIT_FAILURE;
    }
    if (numBytesRead < moduleInfo.SizeOfImage) {
        std::wcerr << "ReadProcessMemory read failure: expected " << moduleInfo.SizeOfImage
            << " bytes, read only " << numBytesRead << "!" << std::endl;
        return EXIT_FAILURE;
    }

    // Find offset of Pinput magic bytes from base of module.
    uint8_t* pinputMagicLocation = std::search(
        entireModuleBytes,
        entireModuleBytesEnd,
        pinputMagic,
        pinputMagic + sizeof pinputMagic
    );
    if (pinputMagicLocation == entireModuleBytesEnd) {
        std::wcerr << "Couldn't find Pinput magic!" << std::endl;
        return EXIT_FAILURE;
    }
    size_t pinputMagicOffset = pinputMagicLocation - entireModuleBytes;
    std::wcout << "pinputMagicOffset = " << std::hex << pinputMagicOffset << std::endl;
    delete[] entireModuleBytes;
    void* pico8GpioStart = (uint8_t*)moduleInfo.lpBaseOfDll + pinputMagicOffset;
    
    // Read just the GPIO area.
    uint8_t gpioBuffer[pico8GpioSize];
    ok = ReadProcessMemory(
        pico8Process,
        pico8GpioStart,
        gpioBuffer,
        pico8GpioSize,
        &numBytesRead
    );
    if (!ok) {
        std::wcerr << "ReadProcessMemory (GPIO area only) failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return EXIT_FAILURE;
    }
    if (numBytesRead < pico8GpioSize) {
        std::wcerr << "ReadProcessMemory (GPIO area only) read failure: expected " << pico8GpioSize
            << " bytes, read only " << numBytesRead << "!" << std::endl;
        return EXIT_FAILURE;
    }

    // Print the GPIO area.
    for (int line = 0; line < 8; line++) {
        for (int col = 0; col < 16; col++) {
            std::wcout << std::setw(2) << std::setfill(L'0') << std::hex;
            std::wcout << gpioBuffer[line * 16 + col] << " ";
        }
        std::wcout << std::endl;
    }

    // Zero the magic and write the GPIO buffer back.
    size_t numBytesWritten;
    for (int col = 0; col < 16; col++) {
        gpioBuffer[col] = 0x00;
    }
    ok = WriteProcessMemory(
        pico8Process,
        pico8GpioStart,
        gpioBuffer,
        pico8GpioSize,
        &numBytesWritten
    );
    if (!ok) {
        std::wcerr << "WriteProcessMemory (GPIO area only) failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return EXIT_FAILURE;
    }
    if (numBytesWritten < pico8GpioSize) {
        std::wcerr << "WriteProcessMemory (GPIO area only) write failure: expected " << pico8GpioSize
            << " bytes, wrote only " << numBytesRead << "!" << std::endl;
        return EXIT_FAILURE;
    }

    // TODO: can we get XInput events in a console app?
    
    ok = CloseHandle(pico8Process);
    if (!ok) {
        std::wcerr << "CloseHandle failed on PICO-8 handle: ";
        printLastError();
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}
