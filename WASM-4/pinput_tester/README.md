# pinput_tester

A [Pinput](../../README.md) extended gamepad tester written in Rust for the [WASM-4](https://wasm4.org) fantasy console.

## Building

Build the cart by running:

```shell
cargo build --release
```

## Running

Then run it with:

```shell
w4 run-native target/wasm32-unknown-unknown/release/pinput_tester.wasm
```

(Note that Pinput is not yet available for the web runtime, so you need to use `run-native` instead of `run`.)

Launch a WASM-4-enabled Rust build of Pinput. The `waiting for Pinput connection...` message from the tester cartridge should disappear and be replaced with a visualization of the state of the first connected gamepad.

For more info about setting up WASM-4, see the [quickstart guide](https://wasm4.org/docs/getting-started/setup?code-lang=rust#quickstart).
