import Darwin
import System

// Swift wrapper functions for the unsupported but useful process info library `libproc`.
// Needs `libproc.h` to be in the bridging header.
//
// See these two files for the last time Apple bothered to release source (Mac OS X 10.8.4):
// https://opensource.apple.com/source/Libc/Libc-825.26/darwin/libproc.c.auto.html
// https://opensource.apple.com/source/Libc/Libc-825.26/darwin/libproc.h.auto.html

/// Returns a list of every process ID visible to the calling process.
func listAllPids() throws -> [pid_t] {
    var numPids = proc_listallpids(nil, 0)
    guard numPids >= 0 else {
        throw Errno(rawValue: errno)
    }
    let allPids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(numPids))
    defer {
        allPids.deallocate()
    }
    numPids = proc_listallpids(allPids, numPids)
    guard numPids >= 0 else {
        throw Errno(rawValue: errno)
    }
    return Array(UnsafeMutableBufferPointer(start: allPids, count: Int(numPids)))
}

/// Returns the executable path for a process.
func pidPath(_ pid: pid_t) throws -> String {
    let path = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(PROC_PIDPATHINFO_SIZE))
    let pathLen = proc_pidpath(pid, path, UInt32(PROC_PIDPATHINFO_SIZE))
    defer {
        path.deallocate()
    }
    guard pathLen > 0 else {
        throw Errno(rawValue: errno)
    }
    return String(cString: path)
}

/// Returns the filename associated with a memory region.
func regionFilename(_ pid: pid_t, _ address: mach_vm_address_t) throws -> String {
    let filename = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
    let filenameLen = proc_regionfilename(pid, address, filename, UInt32(MAXPATHLEN))
    defer {
        filename.deallocate()
    }
    guard filenameLen > 0 else {
        throw Errno(rawValue: errno)
    }
    return String(cString: filename)
}
