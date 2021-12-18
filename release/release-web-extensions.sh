#!/bin/sh

set -eu

# Build the web extensions for Pinput.

# https://stackoverflow.com/a/29835459
release_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
web_src_dir="${release_dir}/../web"

# Clean up from previous builds.
rm -rf \
  "${web_src_dir}/extension/pinput-extension.js" \
  "${web_src_dir}/extension/pinput-extension.js.map" \
  "${web_src_dir}/extension/logo-"* \
  "${release_dir}/artifacts/pinput-web-extension-"*

# Get release metadata.
version="$(cat "${release_dir}/version.txt")"

# Generate shared resources.
webpack --config "${web_src_dir}/webpack.config.js" --mode production
for logo_size in 16 32 48 96 128; do
  convert "${release_dir}/../logo.png" \
    -resize "${logo_size}x${logo_size}" \
    "${web_src_dir}/extension/logo-${logo_size}.png"
done

# Create folders for each manifest version.
for manifest_version in v2 v3; do
  # Map web extension manifest version to the most likely browser to support it.
  if [ "${manifest_version}" = v2 ]; then
    target_browser='firefox'
  elif [ "${manifest_version}" = v3 ]; then
    target_browser='chrome'
  else
    echo "Unknown manifest version: ${manifest_version}" 1>&2
    exit 1
  fi

  # Create extension folders for manual installation.
  artifact_basename="pinput-web-extension-${target_browser}"
  extension_package_dir="${release_dir}/artifacts/${artifact_basename}"
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

  # Zip them for distribution through GitHub releases.
  # `zip` doesn't have an option to change the working directory.
  (
    cd "${release_dir}/artifacts"
    zip "${artifact_basename}-${version}.zip" -r "${artifact_basename}"
  )

  # Clean up by deleting the unpacked extension folder.
  # Comment this line out if you're doing local testing and don't want to unzip the new version every rebuild.
  rm -rf "${extension_package_dir}"
done
