from math import ceil
from typing import Optional

from .bits import bit_mask, BitVector, concat_bits, signed_bit_length


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
        x |= int(bv[pos:pos + group_size]) << b
        b += group_size
        if bv[pos + group_size] == 0:
            break
        pos += 1 + group_size
    return (
        1 + group_size + pos,
        x - (1 << b) if x >= (1 << (b - 1)) else x
    )
