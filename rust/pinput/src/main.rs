extern crate sdl2;

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
}
