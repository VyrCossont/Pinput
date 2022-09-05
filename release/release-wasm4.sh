#!/bin/sh

set -eu

# Build the Pinput test cartridge for WASM-4.

# This script is a bit extra because we want to be able
# to use it with the MinGW version of Bash,
# like the one that comes with Windows Git.
# (We can't use Windows 10 Bash because that just opens Ubuntu in WSL.)

# https://stackoverflow.com/a/29835459
release_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Get release metadata.
version="$(cat "${release_dir}/version.txt")"

# Get current OS.
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
if [ "${os}" = 'darwin' ]; then
  os='macos'
elif echo "${os}" | grep 'mingw' > /dev/null; then
  os='windows'
fi

# Assume SysInternals `strings.exe`, which can find both "ASCII" and "Unicode" strings.
if [ "${os}" = 'windows' ]; then
  strings_cmd() {
    strings.exe -accepteula -nobanner "$@"
  }
else
  strings_cmd() {
    strings "$@"
  }
fi

if [ "${os}" = 'windows' ]; then
  machine_name="${COMPUTERNAME}"
  user_name="${USERNAME}"
else
  machine_name="$(hostname -s)"
  user_name="${USER}"
fi

rust_src="${release_dir}/../WASM-4/pinput_tester"
rust_build_dir="${rust_src}/target/wasm32-unknown-unknown/release"
cartridge_name="pinput_tester.wasm"
artifact_path="${release_dir}/artifacts/pinput_tester-${version}.wasm"

# Clean previous build directory and output archive.
rm -rf "${rust_build_dir}" "${artifact_path}" \
  || true

# Install the WASM target for Rust.
rustup target add wasm32-unknown-unknown

# Make a release build with Cargo.
# The WASI target shouldn't include unwanted strings at all,
# and therefore we don't need to suppress them in the build.
(
  cd "${rust_src}"
  cargo build --release
)

# Check executable for unwanted strings.
unwanted_pattern="${user_name}|${machine_name}"

unwanted="$(\
  strings_cmd "${rust_build_dir}/${cartridge_name}" \
  | grep -i -E "${unwanted_pattern}" \
  || true \
)"
if [ -n "${unwanted}" ] && [ -z "${BYPASS_STRING_CHECK:-}" ]; then
  printf "Unwanted strings found in %s:\n%s\n" \
    "${rust_build_dir}/${cartridge_name}" \
    "${unwanted}" \
    1>&2
  exit 1
fi

# Rename it with a descriptive artifact name.
cp "${rust_build_dir}/${cartridge_name}" "${artifact_path}"
