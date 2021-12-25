#!/usr/bin/env python3
from __future__ import annotations
import sys
from functools import reduce
from itertools import chain
from math import ceil
import operator
from pathlib import Path
import re
from typing import NamedTuple, DefaultDict, List, Iterable, Optional, Union
import zlib

"""
Prototype compressor for Spin replay data: recordings of analog stick positions.
Currently uses very inefficient delta encoder and gets about 50% compression.
No Lua implementation exists yet.

accumulator (i16): starts at 0

structure:
    length (varint): Number of 2-byte values in decompressed data
    values ([varint]): Either literals or deltas.
        Literals are always encoded as 16 data bits, even if this is overlong,
        and deltas with fewer.
        If value has 16 data bits, copy it directly into accmulator.
        If fewer, add it to accumulator.
"""


class BitVector:
    """
    Uses little-endian representation to match PICO-8.
    """

    size: int
    bits: int

    # noinspection PyShadowingBuiltins
    def __init__(
            self,
            size: Optional[int] = None,
            bits: Optional[int] = None,
            bytes: Optional[bytes] = None
    ):
        if bits is not None:
            if size is not None:
                self.size = size
            else:
                self.size = bits.bit_length()
            self.bits = bits
        elif bytes is not None:
            if size is not None:
                self.size = size
            else:
                self.size = len(bytes) * 8
            self.bits = int.from_bytes(bytes, 'little')
        else:
            assert size is not None
            self.size = size
            self.bits = 0

    def __len__(self) -> int:
        return self.size

    def __add__(self, other: BitVector) -> BitVector:
        return BitVector(
            size=self.size + other.size,
            bits=self.bits | other.bits << self.size
        )

    def __iadd__(self, other: BitVector) -> BitVector:
        self.bits |= other.bits << self.size
        self.size += other.size
        return self

    def __getitem__(self, item: Union[int, slice]) -> Union[int, BitVector]:
        if isinstance(item, int):
            if item < 0:
                item += self.size
            return self.bits >> item & 1
        else:
            start, stop, step = item.indices(self.size)
            assert step == 1
            bits = self.bits >> start
            size = stop - start
            bits &= bit_mask(size)
            return BitVector(size=size, bits=bits)

    def __int__(self) -> int:
        return self.bits

    def __str__(self) -> str:
        s = bin(self.bits)[2:]
        fill = '0' * (self.size - len(s))
        return ''.join(reversed(fill + s))

    def __bytes__(self):
        num_bytes = ceil(self.size / 8)
        return self.bits.to_bytes(num_bytes, 'little')

    def __eq__(self, other: BitVector) -> bool:
        return self.size == other.size and self.bits == other.bits

    def __hash__(self) -> int:
        return hash((self.size, self.bits))


class Record(NamedTuple):
    lx: int
    ly: int
    rx: int
    ry: int

    def __repr__(self):
        axes = (
            f'{axis}={getattr(self, axis):08x}'
            for axis in self._fields
        )
        return f'Record({", ".join(axes)})'


def read_replay(path):
    """
    Decode Spin's built-in replay compression, which simply only records output when any axis value changes.
    Note that it has four columns, one for each axis, and a timestamp which can be converted to a frame number.
    TODO: make Spin's replay recording output everything, and use frame numbers instead of timestamps,
            and most of this will no longer be necessary.
    """

    def as_signed_32(x: int):
        return x - 0x100000000 if x >= 0x80000000 else x

    def emit():
        return Record(**{state_k: state_v for state_k, state_v in state.items() if state_k != 'frame'})

    kv_line = re.compile(r'(\w+) = (0x[\da-f]{4}\.[\da-f]{4}),')

    state = {
        'frame': 0,
        'lx': 0,
        'ly': 0,
        'rx': 0,
        'ry': 0,
    }
    yield emit()

    record = {}
    with open(path, 'r') as lua:
        for line in lua:
            line = line.strip().lstrip('-').lstrip()
            if line in {'record_replay = {', '}'}:
                # skip: start of file, end of file
                pass
            elif line == '{':
                # start of record
                record.clear()
            elif line == '},':
                # end of record
                record['frame'] = int(round(record.pop('t') * 60 / 0x10000))
                while state['frame'] < record['frame'] - 1:
                    state['frame'] += 1
                    yield emit()
                state.update(record)
                yield emit()
            else:
                match = kv_line.match(line)
                if match:
                    k, v = match.groups()
                    record[k] = as_signed_32(int(v.replace('.', ''), 0))
                else:
                    print(f"bad line: {line}", file=sys.stderr)


def signed_bit_length(x: int) -> int:
    if x < 0:
        return 1 + (-x - 1).bit_length()
    else:
        return 1 + x.bit_length()


def bit_mask(b: int) -> int:
    return ~-(1 << b)


def signed_bits(b: int, x: int) -> BitVector:
    return BitVector(size=b, bits=bit_mask(b) & x)


def concat_bits(bvs: Iterable[BitVector]) -> BitVector:
    return reduce(operator.add, bvs, BitVector(size=0))


def varint_encoded_length(b: int, group_size: int = 3) -> int:
    """
    :param b: Length of data in bits.
    :param group_size: Number of data bits in each encoding group.
    :return: Total data and continuation bits it'd take to encode the data as a varint.
    """
    num_groups = ceil(b / group_size)
    return num_groups * (1 + group_size)


def write_varint(x: int, group_size: int = 3, force_bit_length: Optional[int] = None) -> BitVector:
    """
    Write signed integer as nibbles,
    each one consisting of a continuation flag
    (1 for more nibbles, 0 for last),
    followed by 3 data bits, least significant bits first.
    """
    groups = []
    b = force_bit_length or signed_bit_length(x)
    num_groups = ceil(b / group_size)
    for i in range(num_groups):
        bits = x & bit_mask(group_size)
        if i != num_groups - 1:
            bits |= 1 << group_size
        groups.append(BitVector(
            size=1 + group_size,
            bits=bits
        ))
        x >>= group_size
    return concat_bits(groups)


def read_varint(bv: BitVector, group_size: int = 3) -> (int, int):
    """
    Read signed integer from nibbles.
    :return: (total number of data and continuation bits used to store integer, value)
    """
    x = 0
    b = 0
    pos = 0
    while True:
        x |= int(bv[pos:pos+group_size]) << b
        b += group_size
        if bv[pos + group_size] == 0:
            break
        pos += 1 + group_size
    return (
        1 + group_size + pos,
        x - (1 << b) if x >= (1 << (b - 1)) else x
    )


def main():
    replay_lua = Path(__file__).parent / 'replay.lua'
    replay = list(read_replay(replay_lua))
    columns = DefaultDict[str, List[int]](list)
    for frame in replay:
        for k, v in frame._asdict().items():
            # Spin shifts inputs in the range -32768–32767 (i16) right by 15
            # to put them in the PICO-8 16.16 range of -1 (0xffff.8000) to 1 (0x0000.ffff).
            # We load them as i32 so this second shift recovers the original values.
            columns[k].append(v >> 1)

    # just mash all the columns together for stats
    column = list(chain.from_iterable(columns.values()))
    column_data_bytes = bytes(concat_bits(signed_bits(16, x) for x in column))
    print(f'len(column_data_bytes): {len(column_data_bytes)}')

    compressed_data_bytes = compress(column)
    print(f'len(compressed_data_bytes): {len(compressed_data_bytes)}')
    decompressed_data_bytes = b''.join(
        bytes(signed_bits(16, x))
        for x
        in decompress(compressed_data_bytes)
    )
    print(f'column_data_bytes == decompressed_data_bytes: {column_data_bytes == decompressed_data_bytes}')

    # Compare to a standard compression scheme.
    # (Not that I'd want to implement zlib in PICO-8.)
    zlib_data_bytes = zlib.compress(column_data_bytes)
    print(f'len(zlib_data_bytes): {len(zlib_data_bytes)}')


def compress(column) -> bytes:
    """Now let's try to compress it!"""

    initial_acc = 0
    deltas = [initial_acc - column[0]] + list(map(operator.sub, column[1:], column[:-1]))
    chunks = [write_varint(len(column))]
    for x, d in zip(column, deltas):
        if signed_bit_length(d) >= 16:
            # Write it as a literal of 16 data bits.
            v = write_varint(x, force_bit_length=16)
        else:
            v = write_varint(d)
        chunks.append(v)
    return bytes(concat_bits(chunks))


def decompress(data: bytes) -> Iterable[int]:
    bv = BitVector(bytes=data)
    pos, samples = read_varint(bv)
    acc = 0
    for _ in range(samples):
        d_pos, v = read_varint(bv[pos:])
        d_pos, v = read_varint(bv[pos:pos+d_pos])
        if d_pos >= varint_encoded_length(16):
            # We forced all literals to encode 16 data bits.
            acc = v
        else:
            acc += v
        pos += d_pos
        yield acc


if __name__ == '__main__':
    main()
