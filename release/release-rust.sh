#!/bin/sh

set -eu

# Build and package the Rust version of Pinput.

# https://stackoverflow.com/a/29835459
release_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Get release metadata.
version=$(cat release/version.txt)
# Assume we're building for the current OS and architecture.
os=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${os}" = 'darwin' ]; then
  os='macos'
fi
arch=$(uname -m)
# TODO: (Windows) use `.exe`
exe_suffix=''

# Make a release build with Cargo.
rust_src="${release_dir}/../rust/pinput"
rust_build_dir="${rust_src}/target/release"
pinput_exe_name="pinput${exe_suffix}"
rm -rf "${rust_build_dir}"
# `cargo` has `--manifest-path=../rust/pinput/Cargo.toml`
# to change the working directory, but it doesn't work with `post build`.
(
  cd "${rust_src}"
  # Suppress absolute paths during compilation.
  # TODO: (Windows) does MSVC have flags for this?
  export CFLAGS="\
    -ffile-prefix-map=${HOME}= \
    -ffile-prefix-map=${PWD}= \
  "
  export RUSTFLAGS="\
    --remap-path-prefix=${HOME}= \
    --remap-path-prefix=${PWD}= \
  "
  # TODO: (Windows) add `/PDBALTPATH`:
  #   See https://github.com/rust-lang/rust/issues/87825
  cargo post build --release
)

# Check executable for unwanted strings.
strings "${rust_build_dir}/${pinput_exe_name}" \
  | grep -v -E "${USER}|$(hostname -s)" > /dev/null

# Zip it with a descriptive archive name.
# `zip` doesn't have an option to change the working directory.
archive_name="${release_dir}/artifacts/pinput-rust-${os}-${arch}-${version}.zip"
(
  cd "${rust_build_dir}"
  rm -f "${archive_name}"
  zip "${archive_name}" "${pinput_exe_name}"
)
