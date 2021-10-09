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
#include <Xinput.h>

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

constexpr size_t pico8GpioOffsetFromCartridgeRamBase = 0x5f80;
constexpr size_t pico8GpioSize = 0x80;
constexpr size_t pico8RegularMemorySize = 0x8000;
constexpr size_t pico8ExtendedMemorySize = 0x10000;

/// <summary>
/// Print the last error from a Windows API function to stderr.
/// </summary>
void printLastError() {
    DWORD error = GetLastError();
    LPWSTR errorMessage = nullptr;
    DWORD errorMessageSize = FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER
        | FORMAT_MESSAGE_FROM_SYSTEM
        | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr,
        error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPWSTR)&errorMessage,
        0,
        nullptr
    );
    if (errorMessageSize) {
        std::wcerr << std::wstring(errorMessage) << std::endl;
    }
    else {
        std::wcerr << "FormatMessage failed to format error " << error << " with error " << GetLastError() << std::endl;
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
/// <returns>Handle for a PICO-8 process, or null if not found.</returns>
HANDLE findPico8Process() {
    auto pids = listPids();
    if (pids.size() == 0) {
        // This shouldn't ever happen except maybe in a sandbox?
        std::wcerr << "Couldn't list any processes!" << std::endl;
        return nullptr;
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
            HRESULT matchStatus = PathMatchSpecEx(
                processExecutableName,
                pico8ExecutableName,
                PMSF_NORMAL
            );
            if (matchStatus == S_OK) {
                return processHandle;
            }
        }

        BOOL ok = CloseHandle(processHandle);
        if (!ok) {
            std::wcerr << "CloseHandle failed for PID " << pid << ": ";
            printLastError();
        }
    }

    return nullptr;
}

/// <summary>
/// Find module belonging to PICO-8 executable within its process.
/// </summary>
/// <param name="pico8Process">Handle for a PICO-8 process.</param>
/// <returns>Module corresponding to pico8.exe, or null if not found.</returns>
HMODULE findPico8Module(HANDLE pico8Process) {
    BOOL ok;

    // Ask for a count of modules in the target process.
    DWORD modulesSizeNeeded;
    ok = EnumProcessModulesEx(
        pico8Process,
        nullptr,
        0,
        &modulesSizeNeeded,
        LIST_MODULES_ALL
    );
    if (!ok) {
        std::wcerr << "EnumProcessModulesEx (no module array) failed: ";
        printLastError();
        return nullptr;
    }
    DWORD numModules = modulesSizeNeeded / sizeof HMODULE;

    // Get all modules in the target process.
    HMODULE* modules = new HMODULE[numModules];
    ok = EnumProcessModulesEx(
        pico8Process,
        modules,
        numModules * sizeof HMODULE,
        &modulesSizeNeeded,
        LIST_MODULES_ALL
    );
    if (!ok) {
        std::wcerr << "EnumProcessModulesEx (with module array) failed: ";
        printLastError();
        return nullptr;
    }

    for (DWORD i = 0; i < numModules; i++) {
        auto module = modules[i];

        wchar_t moduleFilename[MAX_PATH];
        DWORD moduleFilenameLength = GetModuleBaseName(pico8Process, module, moduleFilename, MAX_PATH);
        if (!moduleFilenameLength) {
            // We're looking for PICO-8, so modules without names aren't it.
            continue;
        }

        HRESULT matchStatus = PathMatchSpecEx(
            moduleFilename,
            pico8ExecutableName,
            PMSF_NORMAL
        );
        if (matchStatus == S_OK) {
            delete[] modules;
            return module;
        }
    }

    delete[] modules;
    return nullptr;
}

/// <summary>
/// Look for Pinput magic within a PICO-8 process.
/// </summary>
/// <param name="pico8Process">Handle for a PICO-8 process.</param>
/// <returns>Address within PICO-8 process's address space corresponding
/// to base of cartridge RAM, or null if not found.</returns>
uint8_t* findPico8CartridgeRamBase(HANDLE pico8Process) {
    BOOL ok;

    HMODULE pico8Module = findPico8Module(pico8Process);
    if (!pico8Module) {
        std::wcerr << "Couldn't find a PICO-8 module within the PICO-8 process!" << std::endl;
        return nullptr;
    }
    std::wcout << "PICO-8 module = " << pico8Module << std::endl;

    MODULEINFO moduleInfo;
    ok = GetModuleInformation(pico8Process, pico8Module, &moduleInfo, sizeof MODULEINFO);
    if (!ok) {
        std::wcerr << "GetModuleInformation failed on PICO-8 module " << pico8Module << ": ";
        printLastError();
        return nullptr;
    }
    std::wcout << "    lpBaseOfDll = " << moduleInfo.lpBaseOfDll << std::endl;
    std::wcout << "    SizeOfImage = " << moduleInfo.SizeOfImage << std::endl;
    std::wcout << "    EntryPoint = " << moduleInfo.EntryPoint << std::endl;

    // Read entire module into our process memory.
    uint8_t* entireModuleBytes = new uint8_t[moduleInfo.SizeOfImage];
    uint8_t* entireModuleBytesEnd = entireModuleBytes + moduleInfo.SizeOfImage;
    SIZE_T numBytesRead;
    ok = ReadProcessMemory(
        pico8Process,
        moduleInfo.lpBaseOfDll,
        entireModuleBytes,
        moduleInfo.SizeOfImage,
        &numBytesRead
    );
    if (!ok) {
        std::wcerr << "ReadProcessMemory (findPico8CartridgeRamBase) failed: ";
        printLastError();
        return nullptr;
    }
    if (numBytesRead < moduleInfo.SizeOfImage) {
        std::wcerr << "ReadProcessMemory (findPico8CartridgeRamBase) failed: expected " << moduleInfo.SizeOfImage
            << " bytes, read only " << numBytesRead << "!" << std::endl;
        return nullptr;
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
        return nullptr;
    }
    size_t pinputMagicOffset = pinputMagicLocation - entireModuleBytes;
    std::wcout << "pinputMagicOffset = " << std::hex << pinputMagicOffset << std::endl;
    delete[] entireModuleBytes;
    
    return (uint8_t*)moduleInfo.lpBaseOfDll + pinputMagicOffset - pico8GpioOffsetFromCartridgeRamBase;
}

/// <summary>
/// Initialize Pinput by zeroing the GPIO area.
/// </summary>
/// <param name="pico8Process">Handle for a PICO-8 process.</param>
/// <param name="pico8GpioBase">Address within PICO-8 process's
/// address space corresponding to base of GPIO area.</param>
/// <returns>True if initialization was successful, false otherwise.</returns>
bool initPinput(
    HANDLE pico8Process,
    uint8_t* pico8GpioBase
) {
    // Zero the whole GPIO area.
    uint8_t pico8GpioBuffer[pico8GpioSize] = {};
    SIZE_T numBytesWritten;
    BOOL ok = WriteProcessMemory(
        pico8Process,
        pico8GpioBase,
        pico8GpioBuffer,
        pico8GpioSize,
        &numBytesWritten
    );
    if (!ok) {
        std::wcerr << "WriteProcessMemory failed: ";
        printLastError();
        return false;
    }
    if (numBytesWritten < pico8GpioSize) {
        std::wcerr << "WriteProcessMemory failed: expected " << pico8GpioSize
            << " bytes, wrote only " << numBytesWritten << "!" << std::endl;
        return false;
    }
    return true;
}

enum PinputGamepadFlags : uint8_t {
    connected = 1 << 0,
    hasBattery = 1 << 1,
    charging = 1 << 2,
    hasGuideButton = 1 << 3,
};

typedef struct _PinputGamepad {
    uint8_t flags;
    uint8_t battery;
    XINPUT_GAMEPAD gamepad;
    uint8_t loFreqRumble;
    uint8_t hiFreqRumble;
} PinputGamepad;

// Slightly faster than 60 FPS.
constexpr int frameLengthMs = 16;

// Check disconnected controllers and battery info every this many frames.
constexpr int recheckFrameInterval = 5;

/// <summary>
/// Poll XInput for gamepad input changes and write them to PICO-8 in a fast loop.
/// </summary>
/// <param name="pico8Process">Handle for a PICO-8 process.</param>
/// <param name="pico8GpioBase">Address within PICO-8 process's
/// address space corresponding to base of GPIO area.</param>
void pollXInput(HANDLE pico8Process, uint8_t* pico8GpioBase) {
    BOOL ok;
    
    uint8_t pico8GpioBuffer[pico8GpioSize] = {};

    PinputGamepad* pinputGamepads = (PinputGamepad*)pico8GpioBuffer;
    
    // XInput gamepad connection status.
    bool connected[XUSER_MAX_COUNT] = {};
    DWORD lastPacketNumber[XUSER_MAX_COUNT] = {};
    
    int frame = 0;
    
    // Create a timer that resets every frame.
    // See https://docs.microsoft.com/en-us/windows/win32/sync/using-waitable-timer-objects
    HANDLE timer = CreateWaitableTimer(nullptr, false, nullptr);
    if (!timer) {
        std::wcerr << "CreateWaitableTimer failed: ";
        printLastError();
        return;
    }
    LARGE_INTEGER initialWait;
    initialWait.QuadPart = -10000LL * frameLengthMs;
    ok = SetWaitableTimer(
        timer,
        &initialWait,
        frameLengthMs,
        nullptr,
        nullptr,
        true
    );
    if (!ok) {
        std::wcerr << "SetWaitableTimer failed: ";
        printLastError();
        return;
    }

    for (;;) {
        // If this read fails, the PICO-8 process probably quit.
        SIZE_T numBytesRead;
        ok = ReadProcessMemory(
            pico8Process,
            pico8GpioBase,
            pico8GpioBuffer,
            pico8GpioSize,
            &numBytesRead
        );
        if (!ok) {
            std::wcerr << "ReadProcessMemory failed: ";
            printLastError();
            break;
        }
        if (numBytesRead < pico8GpioSize) {
            std::wcerr << "ReadProcessMemory failed: expected " << pico8GpioSize
                << " bytes, read only " << numBytesRead << "!" << std::endl;
            break;
        }

        // If we see Pinput magic, at startup or after, we need to initialize as if we'd just started up.
        if (std::equal(pico8GpioBuffer, pico8GpioBuffer + sizeof pinputMagic, pinputMagic)) {
            initPinput(pico8Process, pico8GpioBase);
            frame = 0;
            for (int player = 0; player < XUSER_MAX_COUNT; player++) {
                connected[player] = false;
                lastPacketNumber[player] = 0;
            }
            // TODO: switch off currently playing rumble
        }

        bool recheck = frame == 0;
        for (int player = 0; player < XUSER_MAX_COUNT; player++) {
            if (connected[player] || recheck) {
                XINPUT_STATE state = {};
                DWORD result = XInputGetState(player, &state);

                connected[player] = result == ERROR_SUCCESS;

                // TODO: handle rumble based on what we read from GPIO

                if (!connected[player] || lastPacketNumber[player] == state.dwPacketNumber) {
                    continue;
                }

                lastPacketNumber[player] = state.dwPacketNumber;

                pinputGamepads[player].gamepad = state.Gamepad;

                if (recheck) {
                    XINPUT_BATTERY_INFORMATION batteryInfo = {};
                    result = XInputGetBatteryInformation(player, BATTERY_DEVTYPE_GAMEPAD, &batteryInfo);

                    pinputGamepads[player].flags = PinputGamepadFlags::connected;
                    if (batteryInfo.BatteryType != BATTERY_TYPE_WIRED) {
                        pinputGamepads[player].flags |= PinputGamepadFlags::hasBattery;
                        if (batteryInfo.BatteryLevel == BATTERY_LEVEL_FULL) {
                            pinputGamepads[player].battery = UINT8_MAX;
                        }
                        else if (batteryInfo.BatteryLevel == BATTERY_LEVEL_MEDIUM) {
                            pinputGamepads[player].battery = (uint8_t)((uint16_t)UINT8_MAX * 2 / 3);
                        }
                        else if (batteryInfo.BatteryLevel == BATTERY_LEVEL_LOW) {
                            pinputGamepads[player].battery = (uint8_t)((uint16_t)UINT8_MAX * 1 / 3);
                        }
                        else {
                            pinputGamepads[player].battery = 0;
                        }
                    }
                    else {
                        pinputGamepads[player].battery = 0;
                    }
                }
            }
        }
        frame = (frame + 1) % recheckFrameInterval;

        // If this write fails, the PICO-8 process probably quit.
        SIZE_T numBytesWritten;
        ok = WriteProcessMemory(
            pico8Process,
            pico8GpioBase,
            pico8GpioBuffer,
            pico8GpioSize,
            &numBytesWritten
        );
        if (!ok) {
            std::wcerr << "WriteProcessMemory failed: ";
            printLastError();
            break;
        }
        if (numBytesWritten < pico8GpioSize) {
            std::wcerr << "WriteProcessMemory failed: expected " << pico8GpioSize
                << " bytes, wrote only " << numBytesWritten << "!" << std::endl;
            break;
        }

        // Wait for the timer.
        DWORD waitStatus = WaitForSingleObject(timer, INFINITE);
        if (waitStatus == WAIT_FAILED) {
            std::wcerr << "WaitForSingleObject failed for timer: ";
            printLastError();
        }
    }

    ok = CloseHandle(timer);
    if (!ok) {
        std::wcerr << "CloseHandle failed for timer: ";
        printLastError();
    }
}

constexpr int scanIntervalMs = 1000;

int main()
{
    BOOL ok;
    HRESULT hr;

    // We pulled in COM somewhere and need to initialize it.
    // Otherwise the debugger shows "CoInitialize has not been called" exceptions.
    hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (hr != S_OK) {
        goto comShutdown;
    }

    {
        // Create a timer that resets every scan interval.
        // See https://docs.microsoft.com/en-us/windows/win32/sync/using-waitable-timer-objects
        HANDLE timer = CreateWaitableTimer(nullptr, false, nullptr);
        if (!timer) {
            std::wcerr << "CreateWaitableTimer failed: ";
            printLastError();
            return EXIT_FAILURE;
        }
        LARGE_INTEGER initialWait;
        initialWait.QuadPart = -10000LL * scanIntervalMs;
        ok = SetWaitableTimer(
            timer,
            &initialWait,
            scanIntervalMs,
            nullptr,
            nullptr,
            true
        );
        if (!ok) {
            std::wcerr << "SetWaitableTimer failed: ";
            printLastError();
            return EXIT_FAILURE;
        }

        for (;;) {
            HANDLE pico8Process = findPico8Process();
            if (!pico8Process) {
                std::wcerr << "Couldn't find a running PICO-8 process!" << std::endl;
                goto waitForTimer;
            }

            {
                DWORD pico8Pid = GetProcessId(pico8Process);
                if (!pico8Pid) {
                    std::wcerr << "GetProcessId failed on PICO-8 handle: ";
                    printLastError();
                    goto closePico8Process;
                }
                std::wcout << "PICO-8 PID = " << pico8Pid << std::endl;

                {
                    // Memory offset in PICO-8 process's address space, not ours.
                    uint8_t* pico8CartridgeRamBase = findPico8CartridgeRamBase(pico8Process);
                    if (!pico8CartridgeRamBase) {
                        std::wcerr << "Couldn't find Pinput magic in PICO-8 process with PID " << pico8Pid << "!" << std::endl;
                        goto closePico8Process;
                    }

                    {
                        uint8_t* pico8GpioBase = pico8CartridgeRamBase + pico8GpioOffsetFromCartridgeRamBase;
                        pollXInput(pico8Process, pico8GpioBase);
                    }
                }

            closePico8Process:
                ok = CloseHandle(pico8Process);
                if (!ok) {
                    std::wcerr << "CloseHandle failed for PID " << pico8Pid << ": ";
                    printLastError();
                }
            }

        waitForTimer:
            DWORD waitStatus = WaitForSingleObject(timer, INFINITE);
            if (waitStatus == WAIT_FAILED) {
                std::wcerr << "WaitForSingleObject failed for timer: ";
                printLastError();
            }
        }

        ok = CloseHandle(timer);
        if (!ok) {
            std::wcerr << "CloseHandle failed for timer: ";
            printLastError();
        }
    }

comShutdown:
    CoUninitialize();
    
    return EXIT_SUCCESS;
}
