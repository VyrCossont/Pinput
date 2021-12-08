#!/bin/sh

set -eu

# Build the web extensions for Pinput,
# currently in unpacked format.

# https://stackoverflow.com/a/29835459
release_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
web_src_dir="${release_dir}/../web"

# Clean up from previous builds.
rm -rf \
  "${web_src_dir}/extension/pinput-extension.js" \
  "${web_src_dir}/extension/pinput-extension.js.map" \
  "${web_src_dir}/extension/logo-"* \
  "${release_dir}/artifacts/pinput-web-extension-"*

# Generate shared resources.
webpack --config "${web_src_dir}/webpack.config.js" --mode production
for logo_size in 16 32 48 96 128; do
  convert "${release_dir}/../logo.png" \
    -resize "${logo_size}x${logo_size}" \
    "${web_src_dir}/extension/logo-${logo_size}.png"
done

# Create folders for each manifest version.
for manifest_version in v2 v3; do
  extension_package_dir="${release_dir}/artifacts/pinput-web-extension-m${manifest_version}"
  mkdir -p "${extension_package_dir}"
  cp \
    "${web_src_dir}/extension/pinput-extension.js" \
    "${extension_package_dir}"
  cp \
    "${web_src_dir}/extension/logo-"* \
    "${extension_package_dir}"
  cp \
    "${web_src_dir}/extension/${manifest_version}/manifest.json" \
    "${extension_package_dir}"
done
