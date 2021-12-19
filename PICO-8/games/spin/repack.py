#!/usr/bin/env python3
from __future__ import annotations
import sys
from collections import Counter
from functools import reduce
from itertools import chain, groupby, islice
from math import ceil
import operator
from pathlib import Path
from statistics import quantiles, mean, median, mode
import re
from typing import NamedTuple, DefaultDict, List, Iterable, Optional, Union
import zlib

"""
Prototype compressor for Spin replay data: recordings of analog stick positions.
Currently uses very inefficient delta encoder and gets about 50% compression.
Compression code is absurd. Do not read. Decompression code is better.
(I wanted to see how much compression I could get without actually knowing anything about compression.)
No Lua implementation exists yet.

accumulator (i16): starts at 0

structure:
    length (u16): Number of 2-byte values in decompressed data
    runs ([run]): not actually runs in RLE sense, maybe groups would be a better name.

run:
    b (u4): bit size of symbols in run - 1.
        b = 15 indicates that the run content is 16-bit literals, not deltas.
    n (u4): number of symbols in run - 1
    symbols ([literal]|[delta]): not actually symbols in Huffman sense, maybe elements would be a better name.

literal (i16): signed value to be copied directly into accumulator

delta (i<b> where b in [1, 15]): signed value to be added to accumulator
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


def chunked(iterable, n):
    iterator = iter(iterable)
    while True:
        chunk = list(islice(iterator, n))
        if not chunk:
            return
        yield chunk


def signed_bit_length(x: int) -> int:
    b = 1
    while True:
        if -(2 ** (b - 1)) <= x <= (2 ** (b - 1)) - 1:
            return b
        b += 1


def bit_mask(b: int) -> int:
    return ~-(1 << b)


def signed_bits(b: int, x: int) -> BitVector:
    return BitVector(size=b, bits=bit_mask(b) & x)


def unsigned_bits(b: int, x: int) -> BitVector:
    assert x >= 0
    return BitVector(size=b, bits=x)


def concat_bits(bvs: Iterable[BitVector]) -> BitVector:
    return reduce(operator.add, bvs, BitVector(size=0))


def bits_to_bytes(bv: BitVector) -> bytes:
    assert len(bv) % 8 == 0
    return bytes(int(bv[i:i + 8]) for i in range(0, len(bv), 8))


def as_signed(bv: BitVector) -> int:
    b = len(bv)
    x = int(bv)
    return x - (1 << b) if x >= (1 << (b - 1)) else x


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

    # let's get those stats
    bit_lengths = Counter()

    bytes_before = 2 * len(column)
    print(f'bytes_before: {bytes_before}')

    initial_acc = 0
    deltas = [initial_acc - column[0]] + list(map(operator.sub, column[1:], column[:-1]))
    print(f'longest delta: {max(deltas, key=lambda delta: signed_bit_length(delta)):x}')

    for d in deltas:
        bit_lengths[signed_bit_length(d)] += 1

    run_lengths = [len(list(run)) for _, run in groupby(deltas, lambda delta: signed_bit_length(delta))]
    print(f'len(run_lengths): {len(run_lengths)}')
    print(f'max(run_lengths): {max(run_lengths)}')
    print(f'mean(run_lengths): {mean(run_lengths)}')
    print(f'median(run_lengths): {median(run_lengths)}')
    print(f'mode(run_lengths): {mode(run_lengths)}')
    print(f'quantiles(run_lengths, n=16): {quantiles(run_lengths, n=16)}')

    print()

    print('bit_lengths:')
    for k in sorted(bit_lengths.keys(), reverse=True):
        n = bit_lengths[k]
        print(f'  {k}: {n}')

    print()

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


class Symbol:
    pass

    def bit_length(self) -> int:
        raise NotImplementedError

    def bits(self) -> BitVector:
        raise NotImplementedError


class Run(Symbol):
    b: int
    syms: List[Symbol]

    def __init__(self, b: int, syms: List[Symbol]):
        assert 1 <= b <= 16
        assert 1 <= len(syms) <= 16
        self.b = b
        self.syms = syms

    # noinspection PyMethodMayBeStatic
    def bit_length(self) -> int:
        return 8 + self.b * len(self.syms)

    def bits(self) -> BitVector:
        return concat_bits(
            chain(
                [
                    unsigned_bits(4, self.b - 1),
                    unsigned_bits(4, len(self.syms) - 1),
                ],
                (sym.bits() for sym in self.syms)
            )
        )


# TODO: using symmetric signed deltas would let us represent 0 as a 0-bit delta, instead of a 1-bit delta
class Delta(Symbol):
    d: int

    def __init__(self, d: int):
        self.d = d

    def bit_length(self) -> int:
        return signed_bit_length(self.d)

    def bits(self) -> BitVector:
        return signed_bits(self.bit_length(), self.d)


class Literal(Symbol):
    x: int

    def __init__(self, x: int):
        assert signed_bit_length(x) <= 16, x
        self.x = x

    # noinspection PyMethodMayBeStatic
    def bit_length(self) -> int:
        return 16

    def bits(self) -> BitVector:
        return signed_bits(self.bit_length(), self.x)


def compress(column) -> bytes:
    """Now let's try to compress it!"""

    initial_acc = 0
    deltas = [initial_acc - column[0]] + list(map(operator.sub, column[1:], column[:-1]))
    symbols = []
    for x, d in zip(column, deltas):
        if signed_bit_length(d) >= 16:
            symbols.append(Literal(x))
        else:
            symbols.append(Delta(d))

    runs = list(chain.from_iterable(
        (Run(b, list(chunk)) for chunk in chunked(run, 16))
        for b, run
        in groupby(symbols, lambda sym: sym.bit_length())
    ))

    print('compressed:')
    # Run lengths here are shorter because runs are capped at 16 symbols.
    run_lengths = [len(run.syms) for run in runs]
    print(f'len(run_lengths): {len(run_lengths)}')
    print(f'max(run_lengths): {max(run_lengths)}')
    print(f'mean(run_lengths): {mean(run_lengths)}')
    print(f'median(run_lengths): {median(run_lengths)}')
    print(f'mode(run_lengths): {mode(run_lengths)}')
    print(f'quantiles(run_lengths, n=16): {quantiles(run_lengths, n=16)}')

    print()

    compressed_data_bits = Literal(len(column)).bits() + concat_bits(run.bits() for run in runs)
    return bytes(compressed_data_bits)


def decompress(data: bytes) -> Iterable[int]:
    bv = BitVector(bytes=data)
    samples = int(bv[:16])
    pos = 16
    count = 0
    acc = 0
    while count < samples:
        run_b = 1 + int(bv[pos: pos + 4])
        run_count = 1 + int(bv[pos + 4: pos + 8])
        pos += 8
        for _ in range(run_count):
            v = as_signed(bv[pos: pos + run_b])
            if run_b == 16:
                acc = v
            else:
                acc += v
            pos += run_b
            count += 1
            yield acc


if __name__ == '__main__':
    main()
