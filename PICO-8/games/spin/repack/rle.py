"""
Run length encoder.

structure:
    length (i16le): Number of bytes in decompressed data.
    values ([u8|run]): Byte literals may be any value except 0x00.

run:
    marker (u8): Always 0x00.
    n_run_m1 (u8): Number of times to repeat the run, minus 1.
    value (u8): Repeated byte values may be any value including 0x00.
"""

from itertools import groupby
from typing import Any, Iterator


def ilen(iterator: Iterator[Any]) -> int:
    return sum(1 for _ in iterator)


def compress(data: bytes) -> Iterator[bytes]:
    num_bytes = len(data)
    assert num_bytes <= 0x7fff
    yield bytes([
        # low byte of count
        num_bytes & 0xff,
        # high byte of count
        num_bytes >> 8 & 0xff,
    ])
    for b, group in groupby(data, lambda x: x):
        n = ilen(group)
        if n == 1 and b != 0:
            yield bytes([
                # literal byte
                b,
            ])
        else:
            while n >= 1:
                n_run = min(n, 256)
                n -= n_run
                yield bytes([
                    # run marker
                    0,
                    # repetition count - 1
                    n_run - 1,
                    # byte to be repeated
                    b,
                ])


def decompress(compressed: bytes) -> Iterator[bytes]:
    compressed_bytes = iter(compressed)
    num_bytes = next(compressed_bytes)
    num_bytes |= next(compressed_bytes)
    assert 0 <= num_bytes <= 0x7fff
    while num_bytes > 0:
        b = next(compressed_bytes)
        if b != 0:
            num_bytes -= 1
            yield bytes([b])
        else:
            n_run = 1 + next(compressed_bytes)
            b = next(compressed_bytes)
            num_bytes -= n_run
            yield bytes([b] * n_run)
