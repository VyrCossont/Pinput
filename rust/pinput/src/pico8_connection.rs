use sysinfo;
use proc_maps;
use sysinfo::{System, SystemExt, Process, ProcessExt, RefreshKind};
use std::path::{Path, PathBuf};
use plist;
use std::ffi::OsStr;
use proc_maps::MapRange;
use serde::Deserialize;
use process_memory;
use process_memory::{DataMember, Pid, ProcessHandle, TryIntoProcessHandle};
use memchr::memmem;
use uuid::Uuid;

use super::constants::PINPUT_MAGIC;
use super::gamepad::PinputGamepadArray;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("no running PICO-8 processes found")]
    NoPico8ProcessesFound,

    #[error("Pinput magic bytes not found in PICO-8 process (PID {0})")]
    PinputNotEnabled(Pid),

    #[error("Pinput magic bytes not found in a PICO-8 process memory region")]
    PinputMagicNotFound,

    #[error("couldn't find app bundle containing {path}")]
    AppBundle { path: PathBuf },

    #[error("couldn't read `Info.plist` from app bundle")]
    Plist(#[from] plist::Error),

    #[error("I/O error")]
    IOError(#[from] std::io::Error),
}

/// File name of the regular PICO-8 executable (not the one from a standalone cartridge).
#[cfg(windows)]
static PICO8_EXECUTABLE_NAME: &str = "pico8.exe";

/// File name of the regular PICO-8 executable (not the one from a standalone cartridge).
#[cfg(not(windows))]
static PICO8_EXECUTABLE_NAME: &str = "pico8";

/// Subset of `Info.plist` for a macOS app.
/// See <https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html#//apple_ref/doc/uid/10000123i-CH101-SW19>.
#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct InfoPlist {
    /// Name of the app's main executable file.
    c_f_bundle_executable: String,
    /// Bundle ID, used for identifying a specific app to various system APIs, and to Pinput.
    c_f_bundle_identifier: String,
}

/// If this file is inside a macOS app bundle, return the path to that bundle.
fn find_app_bundle_path(path: &Path) -> Result<&Path, Error> {
    let app_extension = Some(OsStr::new("app"));
    path.ancestors()
        .find(|path| path.extension() == app_extension)
        .ok_or_else(|| Error::AppBundle { path: PathBuf::from(path) })
}

/// Assume the path is for a macOS app bundle.
/// Load the `Info.plist` for that bundle.
fn load_info_plist(app_bundle_path: &Path) -> Result<InfoPlist, plist::Error> {
    let info_plist_path = app_bundle_path.join("Contents/Info.plist");
    plist::from_file(info_plist_path)
}

// TODO: run this check only on macOS
fn is_main_executable_of_pico8_bundle(path: &Path) -> Result<bool, Error> {
    let app_bundle_path = find_app_bundle_path(path)?;
    let info_plist = load_info_plist(app_bundle_path)?;

    let in_pico8_bundle = info_plist.c_f_bundle_identifier == "com.lexaloffle.pico8"
        || info_plist.c_f_bundle_identifier.starts_with("com.pico8_author.");

    let bundle_main_executable_path =
        app_bundle_path
        .join("Contents/MacOS")
        .join(info_plist.c_f_bundle_executable);
    let is_bundle_main_executable = path == bundle_main_executable_path;

    Ok(in_pico8_bundle && is_bundle_main_executable)
}

/// Detect both PICO-8 and standalone cartridges.
fn is_pico8_exe(path: &Path) -> Result<bool, Error> {
    if path.ends_with(PICO8_EXECUTABLE_NAME) {
        Ok(true)
    } else if is_main_executable_of_pico8_bundle(path)? {
        Ok(true)
    } else {
        // PICO-8 on Windows doesn't use the PE `VERSIONINFO` resource that is the closest
        // equivalent of `Info.plist`, either in the regular PICO-8 binary or standalone cartridges,
        // so we can't detect PICO-8 as easily on Windows.
        // Linux doesn't have *any* kind of convenient executable metadata.
        // TODO: parse candidate executable files, look for symbols like `_p8_*`.
        Ok(false)
    }
}

fn is_pico8_process(process: &Process) -> Result<bool, Error> {
    is_pico8_exe(process.exe())
}

#[cfg(not(target_os = "linux"))]
fn is_pico8_data_segment(map: &MapRange) -> Result<bool, Error> {
    let map_permissions_rw_only = map.is_read() && map.is_write() && !map.is_exec();
    let map_is_from_pico8_executable: bool;
    if let Some(path) = map.filename() {
        map_is_from_pico8_executable = is_pico8_exe(Path::new(&path))?;
    } else {
        map_is_from_pico8_executable = false;
    }
    Ok(map_permissions_rw_only && map_is_from_pico8_executable)
}

/// On Linux (at least the amd64 version),
/// the area of memory containing `pstate` is an anonymous mapping.
#[cfg(target_os = "linux")]
fn is_pico8_data_segment(map: &MapRange) -> Result<bool, Error> {
    let map_permissions_rw_only = map.is_read() && map.is_write() && !map.is_exec();
    Ok(map_permissions_rw_only && map.filename().is_none())
}

/// Return offset of Pinput magic from memory region's base.
fn find_pinput_magic(handle: &ProcessHandle, map: &MapRange) -> Result<usize, Error> {
    let data = process_memory::copy_address(
        map.start(),
        map.size(),
        handle,
    )?;
    memmem::find(&data, PINPUT_MAGIC.as_bytes())
        .ok_or(Error::PinputMagicNotFound)
}

/// Encapsulates a connection to a PICO-8 process.
#[derive(Debug)]
pub struct Pico8Connection {
    /// The PID is just for display right now.
    pub pid: Pid,
    /// First 16 bytes of GPIO mapped as a UUID.
    pub gpio_as_uuid: DataMember<Uuid>,
    /// All 128 bytes of GPIO mapped as an array of gamepads.
    pub gpio_as_gamepads: DataMember<PinputGamepadArray>,
}

impl Pico8Connection {
    pub fn new(
        pid: Pid,
        handle: ProcessHandle,
        gpio_address: usize,
    ) -> Pico8Connection {
        Pico8Connection{
            pid,
            gpio_as_uuid: DataMember::new_offset(handle, vec![gpio_address]),
            gpio_as_gamepads: DataMember::new_offset(handle, vec![gpio_address]),
        }
    }

    pub fn try_new() -> Result<Self, Error> {
        let system = System::new_with_specifics(
            RefreshKind::new().with_processes()
        );

        let pico8_pid = *system.processes().iter()
            .filter(|(_, process)| is_pico8_process(process).unwrap_or(false))
            .next()
            .ok_or(Error::NoPico8ProcessesFound)?
            .0;
        let pico8_handle = pico8_pid.try_into_process_handle()?;

        // TODO: need to be root or in an entitled binary to do this on macOS
        // https://dev.to/jasonelwood/setup-gdb-on-macos-in-2020-489k
        // TODO: need `setcap cap_sys_ptrace=eip pinput` to do this on Linux
        let gpio_address = proc_maps::get_process_maps(pico8_pid)?.into_iter()
            .filter(|map| is_pico8_data_segment(map).unwrap_or(false))
            .flat_map(|map| {
                // TODO: some permission errors should probably break out of this,
                //  since that might mean we don't have the right entitlement or capability.
                let offset = find_pinput_magic(&pico8_handle, &map).ok()?;
                Some(map.start() + offset)
            })
            .next()
            .ok_or(Error::PinputNotEnabled(pico8_pid))?;

        Ok(Pico8Connection::new(
            pico8_pid,
            pico8_handle,
            gpio_address,
        ))
    }
}

