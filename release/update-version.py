#!/usr/bin/env python3

"""
Update the project-wide version number across all places it currently lives.
Interactive.
"""

from pathlib import Path
from typing import List
import re


def vparse(s: str) -> List[int]:
    return [int(x) for x in s.strip().split('.')]


def vformat(v: List[int]) -> str:
    return '.'.join(str(x) for x in v)


def main():
    release_dir = Path(__file__).resolve().parent

    with open(release_dir / 'version.txt', 'r+') as f:
        version = vparse(f.read())
        print(f'Current version: {vformat(version)}')

        proposed_version = version[:-1] + [version[-1] + 1]
        next_version = input(f'Enter next version [{vformat(proposed_version)}]: ')
        if next_version:
            next_version = [int(v) for v in next_version.strip().split('.')]
        else:
            next_version = proposed_version
        print(f'Next version: {vformat(next_version)}')

        f.seek(0)
        f.write(f'{vformat(next_version)}\n')
        f.truncate()

    base_dir = release_dir.parent

    for filename in ['Cargo.toml', 'Cargo.lock']:
        with open(base_dir / 'rust/pinput' / filename, 'r+') as f:
            contents = f.read()
            contents = re.sub(
                r'^(name = "pinput"\nversion = ")(\d+\.\d+\.\d+)(")$',
                fr'\g<1>{vformat(next_version)}\g<3>',
                contents,
                count=1,
                flags=re.MULTILINE
            )
            f.seek(0)
            f.write(contents)
            f.truncate()

    for filename in ['pinput.lua', 'pinput_tester.p8']:
        with open(base_dir / 'PICO-8' / filename, 'r+') as f:
            contents = f.read()
            contents = re.sub(
                r'^(--.* v)(\d+\.\d+\.\d+)$',
                fr'\g<1>{vformat(next_version)}',
                contents,
                count=1,
                flags=re.MULTILINE
            )
            f.seek(0)
            f.write(contents)
            f.truncate()

    with open(base_dir / 'web/pinput.js', 'r+') as f:
        contents = f.read()
        contents = re.sub(
            r'^( \* v)(\d+\.\d+\.\d+)(.*)$',
            fr'\g<1>{vformat(next_version)}\g<3>',
            contents,
            count=1,
            flags=re.MULTILINE | re.DOTALL
        )
        f.seek(0)
        f.write(contents)
        f.truncate()

    with open(base_dir / 'web/extension/manifest.json', 'r+') as f:
        contents = f.read()
        contents = re.sub(
            r'^(\s*"version": ")(\d+\.\d+\.\d+)(",)$',
            fr'\g<1>{vformat(next_version)}\g<3>',
            contents,
            count=1,
            flags=re.MULTILINE | re.DOTALL
        )
        f.seek(0)
        f.write(contents)
        f.truncate()

    with open(base_dir / 'Windows/PinputCli/PinputCli.rc', 'r+') as f:
        contents = f.read()
        contents = re.sub(
            r'((?:FILE|PRODUCT)VERSION )(\d+,\d+,\d+,\d+)',
            fr'\g<1>{",".join(str(x) for x in next_version)},0',
            contents
        )
        contents = re.sub(
            r'(VALUE "(?:File|Product)Version", ")(\d+\.\d+\.\d+\.\d+)(")',
            fr'\g<1>{vformat(next_version)}.0\g<3>',
            contents
        )
        f.seek(0)
        f.write(contents)
        f.truncate()

    with open(base_dir / 'macOS/Pinput.xcodeproj/project.pbxproj', 'r+') as f:
        contents = f.read()
        contents = re.sub(
            r'(MARKETING_VERSION = )(\d+\.\d+\.\d+)(;)',
            fr'\g<1>{vformat(next_version)}\g<3>',
            contents
        )
        f.seek(0)
        f.write(contents)
        f.truncate()


if __name__ == '__main__':
    main()
