"""A strict bencode reader and writer, written from BEP 3 for the tests.

This is the oracle, and it is deliberately independent of the Lean code:
it was written from the BEP, not translated from `Bencode.lean`. It is
also strict where bencode.py is lenient, because the property this
library claims is that the reader accepts exactly the canonical form:

- numbers have no leading zeros, and `-0` is refused;
- lengths have no leading zeros;
- dictionary keys are byte strings in strictly increasing byte order;
- nothing follows the value;
- input ends where the value ends.

`decode` raises `ValueError` for anything else. `encode` writes the
canonical form and sorts dictionary keys, so `encode(decode(b)) == b`
exactly when `b` is canonical.
"""


def encode(value):
    if isinstance(value, bool):
        raise TypeError("bencode has no booleans")
    if isinstance(value, int):
        return b"i" + str(value).encode() + b"e"
    if isinstance(value, (bytes, bytearray)):
        data = bytes(value)
        return str(len(data)).encode() + b":" + data
    if isinstance(value, (list, tuple)):
        return b"l" + b"".join(encode(v) for v in value) + b"e"
    if isinstance(value, dict):
        out = b"d"
        for key in sorted(value):
            if not isinstance(key, (bytes, bytearray)):
                raise TypeError("keys are byte strings")
            out += encode(bytes(key)) + encode(value[key])
        return out + b"e"
    raise TypeError(f"no bencode form for {type(value).__name__}")


def decode(data):
    if not isinstance(data, (bytes, bytearray)):
        raise TypeError("decode takes bytes")
    value, i = _value(bytes(data), 0)
    if i != len(data):
        raise ValueError("trailing bytes")
    return value


def _value(data, i):
    if i >= len(data):
        raise ValueError("input ends where a value starts")
    c = data[i:i + 1]
    if c == b"i":
        return _int(data, i + 1)
    if c == b"l":
        return _list(data, i + 1)
    if c == b"d":
        return _dict(data, i + 1)
    if c.isdigit():
        return _bytes(data, i)
    raise ValueError(f"no value starts with {c!r}")


def _nat(data, i):
    j = i
    while j < len(data) and data[j:j + 1].isdigit():
        j += 1
    if j == i:
        raise ValueError("no digits")
    digits = data[i:j]
    if len(digits) > 1 and digits[:1] == b"0":
        raise ValueError("leading zero")
    return int(digits), j


def _int(data, i):
    sign = 1
    if i < len(data) and data[i:i + 1] == b"-":
        sign = -1
        i += 1
    n, j = _nat(data, i)
    if j >= len(data) or data[j:j + 1] != b"e":
        raise ValueError("integer without e")
    if sign == -1 and n == 0:
        raise ValueError("minus zero")
    return sign * n, j + 1


def _bytes(data, i):
    n, j = _nat(data, i)
    if j >= len(data) or data[j:j + 1] != b":":
        raise ValueError("length without colon")
    start = j + 1
    if start + n > len(data):
        raise ValueError("length runs past the end")
    return data[start:start + n], start + n


def _list(data, i):
    items = []
    while True:
        if i >= len(data):
            raise ValueError("list without e")
        if data[i:i + 1] == b"e":
            return items, i + 1
        value, i = _value(data, i)
        items.append(value)


def _dict(data, i):
    pairs = {}
    previous = None
    while True:
        if i >= len(data):
            raise ValueError("dictionary without e")
        if data[i:i + 1] == b"e":
            return pairs, i + 1
        key, i = _bytes(data, i)
        if previous is not None and not previous < key:
            raise ValueError("keys do not strictly increase")
        previous = key
        value, i = _value(data, i)
        pairs[key] = value
