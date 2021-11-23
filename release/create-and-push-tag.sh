#!/bin/sh

# Note: unlike other release scripts,
# this one interacts with the outside world by pushing to Git.

set -eu

# https://stackoverflow.com/a/29835459
release_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

version="$(cat "${release_dir}/version.txt")"
tag="v${version}"

git tag "${tag}"
git push origin "${tag}"
