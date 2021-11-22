use std::convert::TryFrom;
use std::env;
use std::fs::OpenOptions;
use std::path::Path;
use std::process::{Command, ExitStatus};
#[cfg(unix)]
use std::os::unix::process::ExitStatusExt;

use anyhow::{anyhow, Result};
#[cfg(windows)]
use memchr::memmem;
#[cfg(windows)]
use memmap::MmapMut;
#[cfg(windows)]
use windows::Win32::System::Diagnostics::Debug::CheckSumMappedFile;

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
fn update_pe_checksum(executable_path: &Path) -> Result<()> {
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
    dbg!(file_checksum);
    dbg!(computed_checksum);
    dbg!(image_nt_headers.is_some());
    // TODO: update PE checksum
    // See https://microsoft.github.io/windows-docs-rs/doc/windows/Win32/System/Diagnostics/Debug/struct.IMAGE_NT_HEADERS64.html#structfield.OptionalHeader
    // See https://microsoft.github.io/windows-docs-rs/doc/windows/Win32/System/Diagnostics/Debug/struct.IMAGE_OPTIONAL_HEADER64.html#structfield.CheckSum
    Ok(())
}

/// As of 2021, MSVC `cl.exe` doesn't have an equivalent of `-ffile-prefix-map`.
/// See https://blog.conan.io/2019/09/02/Deterministic-builds-with-C-C++.html
/// See https://developercommunity.visualstudio.com/t/map-file-to-a-relative-path/1393881
/// Note that this is only a problem with the MSVC toolchain.
#[cfg(windows)]
fn windows_mask(executable_path: &Path) -> Result<()> { 
    mask_paths(executable_path, update_pe_checksum)
}
