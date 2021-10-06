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
HANDLE findPico8() {
    const wchar_t* pico8ExecutableName = L"pico8.exe";

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

int main()
{
    HANDLE pico8Handle = findPico8();
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

    BOOL ok = CloseHandle(pico8Handle);
    if (!ok) {
        std::wcerr << "CloseHandle failed on PICO-8 handle: ";
        printLastError();
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}


// 0220c74677ab446ebedc7fd6d277984d

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
