use sdl2;
use libproc::libproc::proc_pid;
use proc_maps;
use std::path::Path;

// Note: neither name is correct for standalone PICO-8 cartridges.
// We'll need to find a way to detect them too.

#[cfg(windows)]
static PICO8_EXECUTABLE_NAME: &str = "pico8.exe";

#[cfg(not(windows))]
static PICO8_EXECUTABLE_NAME: &str = "pico8";

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

    // TODO: why does listpids return a different type from the types all other proc_pid functions take as input?
    let pids = proc_pid::listpids(proc_pid::ProcType::ProcAllPIDS)
        .expect("Couldn't list all PIDs!");
    println!("Found {} PIDs", pids.len());
    let pids_with_names = pids.iter().map(|pid| {
        let name = proc_pid::name(*pid as i32).ok();
        let path = proc_pid::pidpath(*pid as i32).ok();
        (*pid, name, path)
    });
    let pico8_pid = pids_with_names.filter_map(|(pid, _, path)| {
        if let Some(path) = path {
            if Path::new(&path).ends_with(PICO8_EXECUTABLE_NAME) {
                Some(pid)
            } else {
                None
            }
        } else {
            None
        }
    }).next().expect("Couldn't find a PICO-8 process!");
    println!("Found PICO-8: PID {}", pico8_pid);

    // Print PICO-8 process's memory map.
    // TODO: need to be root or in an entitled binary to do this on macOS
    // https://dev.to/jasonelwood/setup-gdb-on-macos-in-2020-489k
    let maps = proc_maps::get_process_maps(pico8_pid as i32).expect("Couldn't map PICO-8!");
    for map in maps {
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
