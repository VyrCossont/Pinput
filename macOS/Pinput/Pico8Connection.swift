import Darwin

/// Class that encapsulates a piece of PICO-8's memory, mapped into our address space.
public class Pico8Connection {
    /// PID of PICO-8 process we're connected to.
    public let pid: pid_t
    /// Start of where we've mapped the PICO-8 memory region containing cartridge RAM into our address space.
    internal let dataStart: mach_vm_address_t
    /// Size of the entire region containing cartridge RAM.
    internal let dataSize: mach_vm_size_t

    /// Cartridge RAM proper. Upper half is only valid if PICO-8 is in expanded memory mode.
    public let cartridgeRam: UnsafeMutableRawBufferPointer
    /// GPIO area in cartridge RAM.
    public let gpio: UnsafeMutableRawBufferPointer

    init(
        pid: pid_t,
        dataStart: mach_vm_address_t,
        dataSize: mach_vm_size_t,
        cartridgeRamStart: UnsafeMutableRawPointer
    ) {
        self.pid = pid
        self.dataStart = dataStart
        self.dataSize = dataSize
        self.cartridgeRam = .init(start: cartridgeRamStart, count: pico8ExtendedMemorySize)
        self.gpio = .init(start: cartridgeRamStart.advanced(by: pico8GpioOffsetFromCartridgeRamBase), count: pico8GpioSize)
    }

    deinit {
        do {
            try vmDeallocate(target: mach_task_self_, address: dataStart, size: dataSize)
        } catch {
            logger.log("Couldn't deinit a Pico8Connection: \(String(describing: error), privacy: .public)")
        }
    }

    /// Things that can go wrong while connecting.
    enum Failure: Error {
        case noPico8Process
        case pinputMagicNotFound
    }

    /// Attempt to find and connect to a running PICO-8 process with Pinput magic.
    static func connect() throws -> Pico8Connection {
        guard let pico8Pid = (try? listAllPidsWithPaths())?
                .first(where: { (key, value) in value?.hasSuffix("pico8") ?? false })?
                .key else {
            throw Failure.noPico8Process
        }

        let pico8Task = try taskForPid(pico8Pid)
        let regions = try listRegions(pico8Pid)
        for (start, size, region, filename) in regions {
            if isPico8DataSegment(region, filename) {
                if let (dataStart, cartridgeRamStart) = try scanPico8DataSegmentForMagic(pico8Task, start, size) {
                    return Pico8Connection(
                        pid: pico8Pid,
                        dataStart: dataStart,
                        dataSize: size,
                        cartridgeRamStart: cartridgeRamStart
                    )
                }
            }
        }
        throw Failure.pinputMagicNotFound
    }
}


/// List all PIDs, with their executable paths if they can be found.
func listAllPidsWithPaths() throws -> [pid_t: String?] {
    Dictionary(uniqueKeysWithValues:
        (try listAllPids()).map { pid in
            // It's common to not be able to get paths for some processes.
            (pid, try? pidPath(pid))
        }
    )
}

/// Basically `vmmap`. Scan all of the target process's address space trying to find all the memory regions, until we run out or get an error.
/// See https://opensource.apple.com/source/xnu/xnu-7195.141.2/osfmk/vm/vm_user.c.auto.html
func listRegions(_ pid: pid_t) throws -> [(
    start: mach_vm_address_t,
    size: mach_vm_size_t,
    region: vm_region_basic_info_data_64_t,
    filename: String?
)] {
    let task = try taskForPid(pid)
    var address: mach_vm_address_t = 0
    var regions: [(
        start: mach_vm_address_t,
        size: mach_vm_size_t,
        region: vm_region_basic_info_data_64_t,
        filename: String?
    )] = []
    repeat {
        do {
            let (start, size, info) = try vmRegion(task, address)
            let filename = try? regionFilename(pid, start)
            regions.append((start, size, info, filename))
            address = start + size
        } catch let error as KernelError where error.kr == KERN_INVALID_ADDRESS {
            break
        }
    } while address != 0
    return regions
}

/// Find a memory area that's from PICO-8, readable and writable but not executable.
/// Assume that's where we should look for `pstate` and thus the chunk of memory addressable by cartridges, including GPIO.
/// This is the best we can do without reading linker commands to figure out which regions are actually from the `__DATA` segment,
/// and without using `mach_vm_region_recurse` instead of `mach_vm_region` to get the complete sharing info
/// (the real data stuff is `SM=PRV` in `vmmap`, which is apparently not the same as the `VM_PROT_COW` flag or `region.protection.shared == 0`).
func isPico8DataSegment(_ region: vm_region_basic_info_data_64_t, _ filename: String?) -> Bool {
    guard let filename = filename else {
        return false
    }
    guard filename.hasSuffix("pico8") else {
        return false
    }
    return (region.protection & VM_PROT_READ) != 0
        && (region.protection & VM_PROT_WRITE) != 0
        && (region.protection & VM_PROT_EXECUTE) == 0
}

/// Magic byte sequence that the PICO-8 Pinput client is responsible for loading at the beginning of PICO-8's GPIO area.
/// Equivalent to the arbitrary UUID `0220c746-77ab-446e-bedc-7fd6d277984d`.
let pinputMagic: [UInt8] = [
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
]

let pico8GpioOffsetFromCartridgeRamBase = 0x5f80
let pico8GpioSize = 0x80
let pico8RegularMemorySize = 0x8000
let pico8ExtendedMemorySize = 0x10000

/// Look for the magic UUID in a data segment candidate by mapping it into our address space.
/// If we find it, return the address of the segment in our address space, and the address of the base of cartridge RAM.
/// Otherwise, unmap the data segment candidate before returning.
func scanPico8DataSegmentForMagic(
    _ task: vm_map_t,
    _ start: mach_vm_address_t,
    _ size: mach_vm_size_t
) throws -> (
    dataStart: mach_vm_address_t,
    cartridgeRamStart: UnsafeMutableRawPointer
)? {
    let dataAddress = try vmRemap(
        targetTask: mach_task_self_,
        targetAddress: nil,
        size: size,
        mask: 0,
        flags: .anywhere,
        srcTask: task,
        srcAddress: start,
        copy: false,
        curProtection: [.read, .write],
        maxProtection: [.read, .write],
        inheritance: .default
    ).targetAddress

    let maybeMaybeMagicInDataPtr: UnsafeMutableRawPointer?? = pinputMagic.withContiguousStorageIfAvailable { magicPtr -> UnsafeMutableRawPointer? in
        return memmem(
            UnsafeRawPointer(bitPattern: UInt(dataAddress)),
            Int(size),
            magicPtr.baseAddress,
            pinputMagic.count
        )
    }
    guard let maybeMagicInDataPtr = maybeMaybeMagicInDataPtr else {
        fatalError("pinputMagic.withContiguousStorageIfAvailable should always work!")
    }
    guard let magicInDataPtr = maybeMagicInDataPtr else {
        try vmDeallocate(target: mach_task_self_, address: dataAddress, size: size)
        return nil
    }

    return (
        dataStart: dataAddress,
        cartridgeRamStart: magicInDataPtr.advanced(by: -pico8GpioOffsetFromCartridgeRamBase)
    )
}
