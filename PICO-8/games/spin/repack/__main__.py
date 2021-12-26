#!/usr/bin/env python3

import csv
import zlib
from collections import Counter
from itertools import chain, groupby
from pathlib import Path
from typing import DefaultDict

from . import delta, rle
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
    print(f'len(delta_compressed_data_bytes): {len(delta_compressed_data_bytes)}')

    rle_delta_compressed_data_bytes = b''.join(rle.compress(delta_compressed_data_bytes))
    print(f'len(rle_delta_compressed_data_bytes): {len(rle_delta_compressed_data_bytes)}')

    decompressed_data_bytes = b''.join(
        bytes(BitVector(size=16, signed_bits=x))
        for x
        in delta.decompress(b''.join(rle.decompress(rle_delta_compressed_data_bytes)))
    )
    print(f'column_data_bytes == decompressed_data_bytes: {column_data_bytes == decompressed_data_bytes}')

    # Compare to a standard compression scheme.
    # (Not that I'd want to implement zlib in PICO-8.)
    zlib_data_bytes = zlib.compress(column_data_bytes)
    print(f'len(zlib_data_bytes): {len(zlib_data_bytes)}')

    print('delta_byte_counts:')
    delta_byte_counts = Counter(delta_compressed_data_bytes)
    for b, n in delta_byte_counts.most_common():
        print(f'    {b:02x}: {n}')
    print()

    print('delta_byte_runs:')
    delta_byte_runs = Counter(rle.ilen(g) for _, g in groupby(delta_compressed_data_bytes, lambda x: x))
    for size, n in delta_byte_runs.most_common():
        print(f'    {size}: {n}')
    print()

    print('delta_nibble_counts:')
    delta_compressed_data_nibbles = list(chain.from_iterable(
        [b & 0xf, b >> 4 & 0xf] for b in delta_compressed_data_bytes
    ))
    delta_nibble_counts = Counter(delta_compressed_data_nibbles)
    for y, n in delta_nibble_counts.most_common():
        print(f'    {y:01x}: {n}')
    print()

    print('delta_nibble_runs:')
    delta_nibble_runs = Counter(rle.ilen(g) for _, g in groupby(delta_compressed_data_nibbles, lambda x: x))
    for size, n in delta_nibble_runs.most_common():
        print(f'    {size}: {n}')
    print()

    print('rle_delta_byte_counts:')
    rle_delta_byte_counts = Counter(rle_delta_compressed_data_bytes)
    for b, n in rle_delta_byte_counts.most_common():
        print(f'    {b:02x}: {n}')
    print()


if __name__ == '__main__':
    main()
