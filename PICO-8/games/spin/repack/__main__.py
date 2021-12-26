#!/usr/bin/env python3

import csv
import zlib
from collections import Counter
from itertools import chain
from pathlib import Path
from typing import DefaultDict

from . import delta
from .bits import BitVector, concat_bits
from .typedefs import Sample


def read_replay(path: Path) -> dict[str, list[Sample]]:
    columns = DefaultDict[str, list[Sample]](list)
    with open(path, 'r') as f:
        reader = csv.reader(f, quoting=csv.QUOTE_NONNUMERIC)
        axes = next(reader)
        for record in reader:
            for axis, sample in zip(axes, record):
                columns[axis].append(int(sample))
    return columns


def main():
    spin_dir = Path(__file__).parents[1]
    columns = read_replay(spin_dir / 'replay.csv')

    # just mash all the columns together for stats
    column = list(chain.from_iterable(columns.values()))
    column_data_bytes = bytes(concat_bits(BitVector(size=16, signed_bits=x) for x in column))
    print(f'len(column_data_bytes): {len(column_data_bytes)}')

    delta_compressed_data_bytes = delta.compress(column)
    print(f'len(compressed_data_bytes): {len(delta_compressed_data_bytes)}')
    decompressed_data_bytes = b''.join(
        bytes(BitVector(size=16, signed_bits=x))
        for x
        in delta.decompress(delta_compressed_data_bytes)
    )
    print(f'column_data_bytes == decompressed_data_bytes: {column_data_bytes == decompressed_data_bytes}')
    byte_counts = Counter(delta_compressed_data_bytes)
    for b, n in byte_counts.most_common():
        print(f'    {b:02x}: {n}')
    print()

    # Compare to a standard compression scheme.
    # (Not that I'd want to implement zlib in PICO-8.)
    zlib_data_bytes = zlib.compress(column_data_bytes)
    print(f'len(zlib_data_bytes): {len(zlib_data_bytes)}')


if __name__ == '__main__':
    main()
