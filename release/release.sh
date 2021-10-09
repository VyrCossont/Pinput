#!/bin/sh

set -eu

# https://stackoverflow.com/a/29835459
release_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

macos_dir="${release_dir}/../macOS"
archive_path="${macos_dir}/Pinput.xcarchive"
version=$(cat release/version.txt)

# Build and archive
# https://developer.apple.com/library/archive/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588-CH1-HOW_DO_I_BUILD_MY_PROJECTS_FROM_THE_COMMAND_LINE_
xcodebuild \
    -project "${macos_dir}/Pinput.xcodeproj" \
    -scheme Pinput \
    -configuration Release \
    -archivePath "${archive_path}" \
    archive

# Export the archive
# https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow/customizing_the_xcode_archive_process
xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportOptionsPlist "${macos_dir}/ExportOptions.plist" \
    -exportPath "${macos_dir}"

# Zip the exported app, preserving macOS metadata like the +x bit
# https://stackoverflow.com/a/9491755
ditto -c -k --sequesterRsrc --keepParent \
    "${macos_dir}/Pinput.app" \
    "${release_dir}/artifacts/pinput-macos-${version}.zip"
