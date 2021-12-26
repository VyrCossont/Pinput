"""
Delta encoder using varints.

accumulator (i16): Starts at 0.

structure:
    length (varint): Number of 2-byte values in decompressed data.
    values ([varint]): Either literals or deltas.
        Literals are always encoded as 16 data bits, even if this is overlong,
        and deltas with fewer.
        If value has 16 data bits, copy it directly into accmulator.
        If fewer, add it to accumulator.
"""

import operator
from typing import Iterable, Sequence

from .bits import BitVector, concat_bits, signed_bit_length
from .typedefs import Sample
from .varint import read_varint, varint_encoded_length, write_varint


def compress(column: Sequence[Sample]) -> bytes:
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


def decompress(data: bytes) -> Iterable[Sample]:
    bv = BitVector(bytes=data)
    pos, num_samples = read_varint(bv)
    acc = 0
    for _ in range(num_samples):
        d_pos, v = read_varint(bv[pos:])
        d_pos, v = read_varint(bv[pos:pos + d_pos])
        if d_pos >= varint_encoded_length(16):
            # We forced all literals to encode 16 data bits.
            acc = v
        else:
            acc += v
        pos += d_pos
        yield acc
