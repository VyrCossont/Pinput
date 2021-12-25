from repack import write_varint, read_varint, varint_encoded_length, BitVector


class TestVarint:
    def test_write_short(self):
        assert write_varint(0) == BitVector(size=4, bits=0b0000)
        assert write_varint(1) == BitVector(size=4, bits=0b0001)
        assert write_varint(2) == BitVector(size=4, bits=0b0010)
        assert write_varint(3) == BitVector(size=4, bits=0b0011)

    def test_write_short_neg(self):
        assert write_varint(-1) == BitVector(size=4, bits=0b0111)
        assert write_varint(-2) == BitVector(size=4, bits=0b0110)
        assert write_varint(-3) == BitVector(size=4, bits=0b0101)

    def test_write_long(self):
        assert write_varint(0xf) == BitVector(size=8, bits=0b0001_1111)
        assert write_varint(0xff) == BitVector(size=12, bits=0b0011_1111_1111)

    def test_write_long_neg(self):
        assert write_varint(-0x8) == BitVector(size=8, bits=0b0111_1000)
        assert write_varint(-0x80) == BitVector(size=12, bits=0b0110_1000_1000)

    def test_read_short(self):
        assert read_varint(BitVector(size=4, bits=0b0000)) == (4, 0)
        assert read_varint(BitVector(size=4, bits=0b0001)) == (4, 1)

    def test_read_short_neg(self):
        assert read_varint(BitVector(size=4, bits=0b0111)) == (4, -1)

    def test_read_long(self):
        assert read_varint(BitVector(size=8, bits=0b0001_1111)) == (8, 0xf)
        assert read_varint(BitVector(size=12, bits=0b0011_1111_1111)) == (12, 0xff)

    def test_encoded_length(self):
        assert varint_encoded_length(1) == 4
        assert varint_encoded_length(15) == 20
        assert varint_encoded_length(16) == 24
