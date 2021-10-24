use sdl2;
use sysinfo;
use proc_maps;
use sysinfo::{System, SystemExt, Process, ProcessExt, RefreshKind};
use std::path::Path;
use plist;
use std::ffi::OsStr;
use proc_maps::MapRange;
use serde::Deserialize;

#[cfg(windows)]
static PICO8_EXECUTABLE_NAME: &str = "pico8.exe";

#[cfg(not(windows))]
static PICO8_EXECUTABLE_NAME: &str = "pico8";

/// Subset of Info.plist for a macOS app.
#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct InfoPlist {
    c_f_bundle_executable: String,
    c_f_bundle_identifier: String,
}

/// If this file is inside a macOS app bundle, return the path to that bundle.
fn get_app_bundle(path: &Path) -> Option<&Path> {
    path.ancestors().find(|path| path.extension() == Some(OsStr::new("app")))
}

/// Assume the path is for a macOS app bundle.
/// Load the `Info.plist` for that bundle.
fn get_info_plist(path: &Path) -> Option<InfoPlist> {
    plist::from_file(path.join("Contents/Info.plist")).ok()
}

/// Detect both PICO-8 and standalone cartridges.
fn is_pico8_exe(path: &Path) -> bool {
    if path.ends_with(PICO8_EXECUTABLE_NAME) {
        true
    } else if let Some(app_bundle_path) = get_app_bundle(path) {
        // TODO: run this check only on macOS
        if let Some(info_plist) = get_info_plist(app_bundle_path) {
            let in_pico8_bundle = info_plist.c_f_bundle_identifier == "com.lexaloffle.pico8"
                || info_plist.c_f_bundle_identifier.starts_with("com.pico8_author.");
            let bundle_executable_path = app_bundle_path
                .join("Contents/MacOS")
                .join(info_plist.c_f_bundle_executable);
            in_pico8_bundle && path == bundle_executable_path
        } else {
            false
        }
    } else {
        // PICO-8 on Windows doesn't use the PE `VERSIONINFO` resource that is the closest
        // equivalent of `Info.plist`, either in the regular PICO-8 binary or standalone cartridges,
        // so we can't detect PICO-8 as easily on Windows.
        // Linux doesn't have *any* kind of convenient executable metadata.
        // TODO: parse candidate executable files, look for symbols like `_p8_*`.
        false
    }
}

fn is_pico8_process(process: &Process) -> bool {
    is_pico8_exe(process.exe())
}

fn is_pico8_memory_region(map: &MapRange) -> bool {
    map.is_read() && map.is_write() && !map.is_exec()
        && map.filename().as_ref().map_or(false, |path| {
            is_pico8_exe(Path::new(path.as_str()))
        })
}

fn main() {
    let sdl_context = sdl2::init()
        .expect("Couldn't initialize SDL!");
    let game_controller_subsystem = sdl_context.game_controller()
        .expect("Couldn't initialize SDL game controller subsystem!");
    let num_joysticks = game_controller_subsystem.num_joysticks()
        .expect("Couldn't count joysticks!");
    let num_gamepads = (0..num_joysticks)
        .map(|i| game_controller_subsystem.is_game_controller(i))
        .filter(|x| *x)
        .count();
    println!(
        "Hello, world! Found {} joysticks including {} gamepads",
        num_joysticks,
        num_gamepads
    );

    let system = System::new_with_specifics(RefreshKind::new().with_processes());
    let pico8_pid = *system.processes().iter().filter(|(pid, process)| {
        if is_pico8_process(process) {
            println!("Found {} @ {}", pid, process.exe().to_string_lossy());
            true
        } else {
            false
        }
    }).last().expect("Couldn't find a PICO-8 process!").0;
    println!("Found PICO-8: PID {}", pico8_pid);

    // Print PICO-8 process's memory map.
    // TODO: need to be root or in an entitled binary to do this on macOS
    // https://dev.to/jasonelwood/setup-gdb-on-macos-in-2020-489k
    let maps = proc_maps::get_process_maps(pico8_pid).expect("Couldn't map PICO-8!");
    for map in maps.iter().filter(|map| is_pico8_memory_region(*map)) {
        println!(
            "{}+{}: [{}{}{}] {}",
            map.start(),
            map.size(),
            if map.is_read() { "r" } else { "-" },
            if map.is_write() { "w" } else { "-" },
            if map.is_exec() { "x" } else { "-" },
            map.filename().as_ref().unwrap_or(&"???".to_string())
        );
    }
}
