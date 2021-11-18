#!/bin/sh

set -eu

# Build the .p8.png and web demos of `pinput_tester.png`.

# https://stackoverflow.com/a/29835459
release_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

pico8_src_dir="${release_dir}/../PICO-8"
docs_dir="${release_dir}/../docs"

pico8_apps_path="/Applications/PICO-8.app/Contents/MacOS/pico8"
pico8_itch_path="${HOME}/Library/Application Support/itch/apps/pico-8/pico-8/PICO-8.app/Contents/MacOS/pico8"
pico8_path=$(
  which pico8 \
  || which "${pico8_apps_path}" \
  || which "${pico8_itch_path}" \
  || true
)
if [ -z "${pico8_path}" ]; then
  echo "Couldn't find pico8 anywhere!"
  exit 1
fi

# Export .p8.png version.
"${pico8_path}" \
  "${pico8_src_dir}/pinput_tester.p8" \
  -export "${pico8_src_dir}/pinput_tester.p8.png"

# Export HTML version.
"${pico8_path}" \
  "${pico8_src_dir}/pinput_tester.p8" \
  -export "${pico8_src_dir}/pinput_tester.html"

mv "${pico8_src_dir}/pinput_tester.js" "${docs_dir}/pinput_tester.js"
mv "${pico8_src_dir}/pinput_tester.html" "${docs_dir}/index.html"

# Patch cartridge HTML to include JS version of Pinput and description text.
patch -u \
  -i "${release_dir}/index.html.patch" \
  -d "${docs_dir}"
