import Darwin

// Swift wrapper functions for Mach VM functions. Source available at
// https://opensource.apple.com/source/xnu/xnu-7195.141.2/osfmk/vm/

/// Error wrapping a Mach `kern_return_t` and its associated display string.
struct KernelError: Error {
    let kr: kern_return_t
    let text: String
    let function: String

    init(_ kr: kern_return_t, _ function: String = #function) {
        self.kr = kr
        self.text = String(cString: mach_error_string(kr))
        self.function = function
    }
}

/// Get the Mach task port for another process.
func taskForPid(_ pid: pid_t) throws -> mach_port_name_t {
    var task: mach_port_name_t = 0
    let kr = task_for_pid(mach_task_self_, pid, &task)
    guard kr == KERN_SUCCESS else {
        throw KernelError(kr)
    }
    return task
}

/// Find the memory region associated with an address.
/// If there isn't one at that address, it will scan upwards for the next region.
/// https://web.mit.edu/darwin/src/modules/xnu/osfmk/man/vm_region.html
func vmRegion(_ task: mach_port_name_t, _ address: mach_vm_address_t) throws -> (
    start: mach_vm_address_t,
    size: mach_vm_size_t,
    info: vm_region_basic_info_data_64_t
) {
    var start = address
    var size: mach_vm_size_t = 0
    var info = vm_region_basic_info_data_64_t()
    /// `VM_REGION_BASIC_INFO_COUNT_64` is missing as a symbol, but defined in XNU source `osfmk/mach/vm_region.h` as
    var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_64>.size / MemoryLayout<Int32>.size)
    var objectName: mach_port_t = 0
    try withUnsafeMutablePointer(to: &info, { infoStructPtr in
        try infoStructPtr.withMemoryRebound(to: Int32.self, capacity: 1) { infoIntPtr in
            let kr = mach_vm_region(
                task,
                &start,
                &size,
                VM_REGION_BASIC_INFO_64,
                infoIntPtr,
                &count,
                &objectName
            )
            guard kr == KERN_SUCCESS else {
                throw KernelError(kr)
            }
        }
    })
    return (start, size, info)
}

/// See `VM_FLAGS_USER_REMAP` in `vm_statistics.h`.
struct VmRemapFlags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let fixed = VmRemapFlags(rawValue: VM_FLAGS_FIXED)
    public static let anywhere = VmRemapFlags(rawValue: VM_FLAGS_ANYWHERE)
    public static let randomAddr = VmRemapFlags(rawValue: VM_FLAGS_RANDOM_ADDR)
    public static let overwrite = VmRemapFlags(rawValue: VM_FLAGS_OVERWRITE)
    public static let returnDataAddr = VmRemapFlags(rawValue: VM_FLAGS_RETURN_DATA_ADDR)
    public static let resilientCodesign = VmRemapFlags(rawValue: VM_FLAGS_RESILIENT_CODESIGN)
    public static let resilientMedia = VmRemapFlags(rawValue: VM_FLAGS_RESILIENT_MEDIA)
}

/// See `vm_prot.h` and `shared_region.h`.
struct VmProtection: OptionSet {
    public let rawValue: vm_prot_t

    public init(rawValue: vm_prot_t) {
        self.rawValue = rawValue
    }

    public static let none = VmProtection(rawValue: VM_PROT_NONE)
    public static let read = VmProtection(rawValue: VM_PROT_READ)
    public static let write = VmProtection(rawValue: VM_PROT_WRITE)
    public static let execute = VmProtection(rawValue: VM_PROT_EXECUTE)
    public static let all = VmProtection([.read, .write, .execute])

    public static let noChange = VmProtection(rawValue: VM_PROT_NO_CHANGE)
    public static let copy = VmProtection(rawValue: VM_PROT_COPY)
    public static let wantsCopy = VmProtection(rawValue: VM_PROT_WANTS_COPY)
    public static let isMask = VmProtection(rawValue: VM_PROT_IS_MASK)
    public static let stripRead = VmProtection(rawValue: VM_PROT_STRIP_READ)
    public static let executeOnly = VmProtection([.execute, .stripRead])

    public static let cow = VmProtection(rawValue: VM_PROT_COW)
    public static let zf = VmProtection(rawValue: VM_PROT_ZF)
    public static let slide = VmProtection(rawValue: VM_PROT_SLIDE)
    public static let noauth = VmProtection(rawValue: VM_PROT_NOAUTH)
    public static let translatedAllowExecute = VmProtection(rawValue: VM_PROT_TRANSLATED_ALLOW_EXECUTE)
}

/// See `vm_inherit.h`.
enum VmInherit: vm_inherit_t {
    /// `VM_INHERIT_SHARE`
    case share = 0
    /// `VM_INHERIT_COPY`
    case copy = 1
    /// `VM_INHERIT_NONE`
    case none = 2
    /// `VM_INHERIT_DONATE_COPY`
    case donateCopy = 3

    /// `VM_INHERIT_DEFAULT`
    public static let `default` = VmInherit.copy
    /// `VM_INHERIT_LAST_VALID`
    public static let lastValid = VmInherit.none
}

/// Map another process's memory into our address space.
/// See https://web.mit.edu/darwin/src/modules/xnu/osfmk/man/vm_remap.html
func vmRemap(
    targetTask: vm_map_t,
    targetAddress: mach_vm_address_t?,
    size: mach_vm_size_t,
    mask: mach_vm_offset_t,
    flags: VmRemapFlags,
    srcTask: vm_map_t,
    srcAddress: mach_vm_address_t,
    copy: Bool,
    curProtection: VmProtection,
    maxProtection: VmProtection,
    inheritance: VmInherit
) throws -> (
    targetAddress: mach_vm_address_t,
    curProtection: VmProtection,
    maxProtection: VmProtection
) {
    var targetAddress: mach_vm_address_t = targetAddress ?? 0
    var curProtection = curProtection.rawValue
    var maxProtection = maxProtection.rawValue
    let kr = mach_vm_remap(
        targetTask,
        &targetAddress,
        size,
        mask,
        flags.rawValue,
        srcTask,
        srcAddress,
        copy ? 1 : 0,
        &curProtection,
        &maxProtection,
        inheritance.rawValue
    )
    guard kr == KERN_SUCCESS else {
        throw KernelError(kr)
    }
    return (
        targetAddress,
        VmProtection(rawValue: curProtection),
        VmProtection(rawValue: maxProtection)
    )
}

/// Deallocate a memory region.
/// Doesn't need to be one created with `mach_vm_allocate`;
/// it can free those from `mach_vm_remap` too.
/// See http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/vm_deallocate.html
func vmDeallocate(
    target: vm_map_t,
    address: mach_vm_address_t,
    size: mach_vm_size_t
) throws {
    let kr = mach_vm_deallocate(target, address, size)
    guard kr == KERN_SUCCESS else {
        throw KernelError(kr)
    }
}
