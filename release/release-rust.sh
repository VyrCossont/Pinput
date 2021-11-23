#!/bin/sh

set -eu

# Build and package the Rust version of Pinput.

# This script is a bit extra because we want to be able
# to use it with the MinGW version of Bash,
# like the one that comes with Windows Git.
# (We can't use Windows 10 Bash because that just opens Ubuntu in WSL.)

# https://stackoverflow.com/a/29835459
release_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Get release metadata.
version="$(cat release/version.txt)"
# Assume we're building for the current architecture and OS.
arch="$(uname -m)"
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
if [ "${os}" = 'darwin' ]; then
  os='macos'
elif echo "${os}" | grep 'mingw' > /dev/null; then
  os='windows'
fi

# Windows-specific tweaks.

if [ "${os}" = 'windows' ]; then
  exe_suffix='.exe'
else
  exe_suffix=''
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

# If there's no command-line zip, use PowerShell.
if [ "${os}" = 'windows' ] && [ -z "$(which zip 2> /dev/null)" ]; then
  zip_cmd() {
    archive_path="$1"
    shift
    powershell.exe -Command Compress-Archive -Force -DestinationPath "${archive_path}" -Path "$@"
  }
else
  zip_cmd() {
    zip "$@"
  }
fi

if [ "${os}" = 'windows' ]; then
  machine_name="${COMPUTERNAME}"
  user_name="${USERNAME}"
  # HOME on MinGW starts with `/c/Users/`,
  # which we can't use for `-ffile-prefix-map` or `--remap-path-prefix`.
  user_home="${USERPROFILE}"
else
  machine_name="$(hostname -s)"
  user_name="${USER}"
  user_home="${HOME}"
fi

rust_src="${release_dir}/../rust/pinput"
rust_build_dir="${rust_src}/target/release"
pinput_exe_name="pinput${exe_suffix}"
archive_name="${release_dir}/artifacts/pinput-rust-${os}-${arch}-${version}.zip"

# Clean previous build directory and output archive.
rm -rf "${rust_build_dir}" "${archive_name}" \
  || true

# Make a release build with Cargo.
# `cargo` has `--manifest-path=../rust/pinput/Cargo.toml`
# to change the working directory, but it doesn't work with `post build`.
(
  cd "${rust_src}"
  # Suppress absolute paths during compilation.
  if [ "${os}" = 'windows' ]; then
    build_dir="$(cygpath --windows "${PWD}")"
  else
    build_dir="${PWD}"
  fi
  # As of 2021, MSVC cl.exe doesn't have an equivalent of `-ffile-prefix-map`,
  # so we rely on `post_build.rs` to remove unwanted C-related file paths from the executable.
  export CFLAGS="\
    -ffile-prefix-map=${user_home}= \
    -ffile-prefix-map=${build_dir}= \
  "
  if [ "${os}" = 'windows' ]; then
    # See https://github.com/rust-lang/rust/issues/87825
    linker_flags='-Clink-arg=/PDBALTPATH:%_PDB%'
  else
    linker_flags=''
  fi
  export RUSTFLAGS="\
    --remap-path-prefix=${user_home}= \
    --remap-path-prefix=${build_dir}= \
    ${linker_flags} \
  "
  cargo post build --release
)

# Check executable for unwanted strings.
unwanted_pattern="${user_name}|${machine_name}"

unwanted="$(\
  strings_cmd "${rust_build_dir}/${pinput_exe_name}" \
  | grep -i -E "${unwanted_pattern}" \
  || true \
)"
if [ -n "${unwanted}" ] && [ -z "${BYPASS_STRING_CHECK:-}" ]; then
  printf "Unwanted strings found in %s:\n%s\n" \
    "${rust_build_dir}/${pinput_exe_name}" \
    "${unwanted}" \
    1>&2
  exit 1
fi

# Zip it with a descriptive archive name.
# `zip` doesn't have an option to change the working directory.
(
  cd "${rust_build_dir}"
  zip_cmd "${archive_name}" "${pinput_exe_name}"
)

unwanted="$(\
  strings_cmd "${archive_name}" \
  | grep -i -E "${unwanted_pattern}" \
  || true \
)"
if [ -n "${unwanted}" ] && [ -z "${BYPASS_STRING_CHECK:-}" ]; then
  printf "Unwanted strings found in %s:\n%s\n" \
    "${archive_name}" \
    "${unwanted}" \
    1>&2
  exit 1
fi
