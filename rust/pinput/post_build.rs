use std::env;
use std::path::Path;
use std::process::{Command, ExitStatus};
#[cfg(unix)]
use std::os::unix::process::ExitStatusExt;

use anyhow::{anyhow, Result};

/// Run platform-specific code-signing or capability-granting tools.
/// @todo handle cross-builds?
fn main() -> Result<()> {
    let crate_out_dir_env_var = env::var("CRATE_OUT_DIR")?;
    let crate_out_dir = Path::new(crate_out_dir_env_var.as_str());
    // TODO: can we get the executable name from somewhere,
    //  and thus generalize this to other projects?
    let executable_name = "pinput";
    let executable_path = crate_out_dir.join(executable_name);

    match env::consts::OS {
        "macos" => macos_codesign(executable_path.as_path()),
        "linux" => linux_setcap(executable_path.as_path()),
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
