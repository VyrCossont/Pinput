use std::env;
use std::fs::OpenOptions;
use std::path::Path;

use std::process::{Command, ExitStatus};
#[cfg(unix)]
use std::os::unix::process::ExitStatusExt;

use anyhow::{anyhow, Result};
use memchr::memmem;
use memmap::MmapMut;

#[cfg(windows)]
use {
    std::convert::TryFrom,
    std::ptr,
    std::slice,

    windows::core::PWSTR,
    windows::Win32::System::Diagnostics::Debug::{
        CheckSumMappedFile,
        FormatMessageW,
        FORMAT_MESSAGE_ALLOCATE_BUFFER,
        FORMAT_MESSAGE_FROM_SYSTEM,
        FORMAT_MESSAGE_IGNORE_INSERTS,
    },
    windows::Win32::Foundation::GetLastError,
    windows::Win32::System::SystemServices::{LANG_NEUTRAL, SUBLANG_NEUTRAL},
    windows::Win32::System::Memory::LocalFree,
};

/// Run platform-specific code-signing or capability-granting tools.
/// @todo handle cross-builds?
fn main() -> Result<()> {
    let crate_out_dir_env_var = env::var("CRATE_OUT_DIR")?;
    let crate_out_dir = Path::new(crate_out_dir_env_var.as_str());
    // TODO: can we get the executable name from somewhere,
    //  and thus generalize this to other projects?
    let executable_name = if cfg!(windows) {
        "pinput.exe"
    } else {
        "pinput"
    };
    let executable_path = crate_out_dir.join(executable_name);

    match env::consts::OS {
        "macos" => macos_codesign(executable_path.as_path()),
        "linux" => linux_setcap(executable_path.as_path()),
        "windows" => windows_mask(executable_path.as_path()),
        _ => Ok(()),
    }
}

/// @todo use std .exit_ok() instead once that's stable.
trait ExitOkExt {
    fn exit_ok(&self) -> Result<()>;
}

impl ExitOkExt for ExitStatus {
    #[cfg(not(unix))]
    fn exit_ok(&self) -> Result<()> {
        if self.success() {
            Ok(())
        } else if let Some(code) = self.code() {
            Err(anyhow!("Exited with status code: {}", code))
        } else {
            Err(anyhow!("Process terminated by signal"))
        }
    }

    #[cfg(unix)]
    fn exit_ok(&self) -> Result<()> {
        if self.success() {
            Ok(())
        } else if let Some(code) = self.code() {
            Err(anyhow!("Exited with status code: {}", code))
        } else if let Some(signal) = self.signal() {
            Err(anyhow!("Process terminated by signal: {}", signal))
        } else {
            Err(anyhow!("Process terminated under mysterious circumstances"))
        }
    }
}

/// Codesign the executable with an entitlements file that marks it as a debugger.
fn macos_codesign(executable_path: &Path) -> Result<()> {
    let entitlements_path = Path::new("../../macOS/Pinput/Pinput.entitlements");
    // "-" is the ad-hoc signing identity.
    let signing_identity = "-";
    #[allow(unstable_name_collisions)]
    Command::new("/usr/bin/codesign")
        .args([
            "--verbose",
            "--sign", signing_identity,
            "--force",
            "--entitlements",
        ])
        .args([
            entitlements_path.canonicalize()?.as_os_str(),
            executable_path.canonicalize()?.as_os_str(),
        ])
        .status()?
        .exit_ok()
}

/// Set `CAP_SYS_PTRACE` so we can use `ptrace()` without elevating.
/// Note that we have to be elevated to set this xattr.
fn linux_setcap(executable_path: &Path) -> Result<()> {
    #[allow(unstable_name_collisions)]
    Command::new("sudo")
        .args([
            "setcap",
            "cap_sys_ptrace=ep",
        ])
        .args([
            executable_path.canonicalize()?.as_os_str(),
        ])
        .status()?
        .exit_ok()
}

/// Remove unwanted file paths from the executable.
/// This will still leak the length, but it's better than nothing.
fn mask_paths<UpdateChecksum>(executable_path: &Path, update_checksum: UpdateChecksum) -> Result<()>
where UpdateChecksum: FnOnce(&mut MmapMut) -> Result<()> {
    let src_dir = env::var("CRATE_MANIFEST_DIR")?;
    let user_profile = env::var("USERPROFILE")?;

    let executable_file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(executable_path)?;

    let mut executable_mmap = unsafe {
        MmapMut::map_mut(&executable_file)
    }?;

    // Put `src_dir` before `user_profile` in case the latter is a suffix of the former.
    for unwanted in vec![src_dir, user_profile] {
        let masked = unwanted.replace(char::is_alphanumeric, "X");
        let masked_bytes = masked.as_bytes();
        let offsets: Vec<_> = memmem::find_iter(&executable_mmap, &unwanted).collect();
        for offset in offsets {
            executable_mmap[offset..offset + masked_bytes.len()].copy_from_slice(masked_bytes);
        }
    }

    update_checksum(&mut executable_mmap)?;

    executable_mmap.flush()?;

    Ok(())
}

#[cfg(not(windows))]
fn update_pe_checksum(_executable_mmap: &mut MmapMut) -> Result<()> {
    Err(anyhow!("Modifying PE checksums currently requires Windows APIs"))
}

/// There's an excellent chance that this is completely unnecessary.
/// It's zero when written by Rust tools.
/// See https://practicalsecurityanalytics.com/pe-checksum/
/// See https://github.com/graydon/rust-prehistory/blob/master/src/boot/be/pe.ml#L284
#[cfg(windows)]
fn update_pe_checksum(executable_mmap: &mut MmapMut) -> Result<()> {
    let mut file_checksum: u32 = 0;
    let mut computed_checksum: u32 = 0;
    let image_nt_headers = unsafe {
        CheckSumMappedFile(
            executable_mmap.as_ptr() as _,
            u32::try_from(executable_mmap.len())?,
            &mut file_checksum,
            &mut computed_checksum,
        ).as_mut()
    };
    if let Some(image_nt_headers) = image_nt_headers {
        image_nt_headers.OptionalHeader.CheckSum = computed_checksum;
        Ok(())
    } else {
        let message = unsafe {
            let error = GetLastError();
            let message_utf16 = PWSTR(ptr::null_mut());
            let num_wide_chars = FormatMessageW(
                FORMAT_MESSAGE_ALLOCATE_BUFFER
                | FORMAT_MESSAGE_FROM_SYSTEM
                | FORMAT_MESSAGE_IGNORE_INSERTS,
                ptr::null(),
                error.0,
                LANG_NEUTRAL + 1024 * SUBLANG_NEUTRAL,
                message_utf16,
                0,
                ptr::null()
            );
            if num_wide_chars == 0 {
                "CheckSumMappedFile failed, and we couldn't get an error message".to_string()
            } else {
                let message = String::from_utf16_lossy(
                    slice::from_raw_parts(
                        message_utf16.0,
                        num_wide_chars as usize
                    )
                );
                LocalFree(message_utf16.0 as isize);
                message
            }
        };
        Err(anyhow!(message))
    }
}

/// As of 2021, MSVC `cl.exe` doesn't have an equivalent of `-ffile-prefix-map`.
/// See https://blog.conan.io/2019/09/02/Deterministic-builds-with-C-C++.html
/// See https://developercommunity.visualstudio.com/t/map-file-to-a-relative-path/1393881
/// Note that this is only a problem with the MSVC toolchain.
fn windows_mask(executable_path: &Path) -> Result<()> { 
    mask_paths(executable_path, update_pe_checksum)
}
