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
