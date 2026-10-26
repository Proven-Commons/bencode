# Specification: bencode, BEP 3, first slice

This is the specification a reviewer approves, together with `Spec.lean`,
`Spec/Defs.lean`, and the whole project page. It says what the library
does, what it refuses, and which theorem backs each public claim.

## Scope

A value is an integer, a byte string, a list of values, or a dictionary
from byte strings to values. Bencode is the format BitTorrent uses for
its metadata and its tracker responses.

The format, from BEP 3:

- An integer is `i`, its decimal form, then `e`. The decimal form is
  canonical: no leading zeros, one digit for zero, and `-0` is not
  written.
- A byte string is its length in decimal, a colon, then exactly that
  many bytes.
- A list is `l`, its values in order, then `e`.
- A dictionary is `d`, then each key as a byte string and its value,
  then `e`. Keys are in strictly increasing byte order, compared byte by
  byte.

Integers are unbounded here. BEP 3 leaves their range to the reader; this
library reads any integer that fits the machine, and the encoder writes
any of them.

## Valid inputs and errors

The encoder is total: every value has a canonical encoding.

The decoder accepts an encoding of a value that is canonical, and refuses
the whole input otherwise. It refuses:

- a number with a leading zero, and `-0`;
- a length with a leading zero;
- a length that runs past the end of the input;
- a dictionary whose keys are equal or not strictly increasing;
- bytes after the value, rather than ignoring them;
- input that ends inside a value.

The empty input is refused: it is not the empty list, which is `le`.

## What must always hold

Each property below is a theorem in `Spec.lean`.

| Property | Theorem |
|----------|---------|
| Every byte of a decimal form is a digit. | `Spec.digits_digits` |
| A decimal form always has at least one digit. | `Spec.digits_ne_nil` |
| A byte string is its length in decimal, a colon, then the bytes. | `Spec.encode_bytes_layout` |
| An integer is `i`, its decimal form, then `e`. | `Spec.encode_int_layout` |
| A list is `l`, its items encoded in turn, then `e`. | `Spec.encode_list_layout` |
| A dictionary is `d`, its pairs in turn, key before value, then `e`. | `Spec.encode_dict_layout` |
| Every value's encoding is not empty. | `Spec.encode_ne_nil` |
| A list's items encoded in turn are the flattened encodings of the items. | `Spec.encodeList_eq_flatten` |
| `i42e` is accepted. | `Spec.decode_int_example` |
| `i-42e` is accepted. | `Spec.decode_negative_int_example` |
| `4:spam` is accepted. | `Spec.decode_bytes_example` |
| `0:` is accepted. | `Spec.decode_empty_bytes_example` |
| The BEP 3 list example, `l4:spami42ee`, is accepted. | `Spec.decode_list_example` |
| The BEP 3 dictionary example, `d3:bar4:spam3:fooi42ee`, is accepted. | `Spec.decode_dict_example` |
| `i03e` is refused. | `Spec.rejects_leading_zero_int` |
| `i-0e` is refused. | `Spec.rejects_negative_zero` |
| `03:abc` is refused. | `Spec.rejects_leading_zero_length` |
| `d3:fooi42e3:bar4:spame` is refused: keys out of order. | `Spec.rejects_unsorted_keys` |
| `1:a1:b` is refused: bytes after a value. | `Spec.rejects_trailing_bytes` |
| `l4:spam` is refused: a list with no `e`. | `Spec.rejects_truncated_list` |
| `9:spam` is refused: a length past the end. | `Spec.rejects_short_bytes` |
| `i3xe` is refused: not a decimal form. | `Spec.rejects_bad_int` |
| The empty input is refused. | `Spec.rejects_empty` |

An input is "accepted" in these statements when the value read from it is
written back as the same bytes, stated as `(decode s).map encode = some s`.
That checks the decoder and the encoder at once.

## Oracle

The oracle is `tests/reference.py`, a strict bencode reader and writer
written from BEP 3 for these tests, independent of the Lean code. When
`bencode.py` is installed, the test script also checks that the two agree
on every canonical value it generates, and the record names its version.
The record in `tests/TEST-RESULTS.md` names the seed, the number of
requests, and the failures.

## What the tests cover that the proofs do not

The decoder in general. The statements above pin single inputs; the tests
compare 200,000 encodings, most of them mutations of a canonical encoding,
with the oracle, and require that the decoder accepts exactly the
canonical ones and writes them back unchanged.
