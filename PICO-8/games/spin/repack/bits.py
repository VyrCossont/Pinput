from __future__ import annotations

import operator
from functools import reduce
from math import ceil
from typing import Iterable, Optional, Union


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
            signed_bits: Optional[int] = None,
            bytes: Optional[bytes] = None
    ):
        if bits is not None:
            if size is not None:
                self.size = size
            else:
                self.size = bits.bit_length()
            self.bits = bits

        elif signed_bits is not None:
            if size is not None:
                self.size = size
            else:
                self.size = signed_bit_length(signed_bits)
            self.bits = signed_bits & bit_mask(self.size)

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


def signed_bit_length(x: int) -> int:
    if x < 0:
        return 1 + (-x - 1).bit_length()
    else:
        return 1 + x.bit_length()


def bit_mask(b: int) -> int:
    return ~-(1 << b)


def concat_bits(bvs: Iterable[BitVector]) -> BitVector:
    return reduce(operator.add, bvs, BitVector(size=0))
