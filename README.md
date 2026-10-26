# bencode: canonical BEP 3, written and read

A small bencode library in Lean: an encoder that writes the canonical form of a value, and a decoder that accepts exactly that form and refuses everything else. Bencode is the format BitTorrent uses for metadata and tracker responses: integers, byte strings, lists, and dictionaries with keys in strictly increasing byte order.

The encoder is proved: every byte of a decimal form is a digit, a decimal form is never empty, each of the four kinds has exactly one written shape, and no encoding is empty. The decoder runs, is pinned by single-input theorems on the rules that matter, and is compared with a strict reader written from BEP 3 on 200,000 inputs from a recorded seed, most of them mutations of a canonical encoding (see `tests/TEST-RESULTS.md`).

Status: in progress. The specification has not yet been approved by a reviewer apart from its author, so this is not verified.

## What is proved

The statements are in `Spec.lean`, the definitions they use in `Spec/Defs.lean`, and the proofs in `Proofs.lean`. Each claim below names the theorem behind it.

| Claim | Theorem |
|-------|---------|
| Every byte of a decimal form is a digit. | `Spec.digits_digits` |
| A decimal form always has at least one digit, so it is never empty. | `Spec.digits_ne_nil` |
| A byte string is its length in decimal, a colon, then the bytes. | `Spec.encode_bytes_layout` |
| An integer is `i`, its decimal form, then `e`. | `Spec.encode_int_layout` |
| A list is `l`, its items encoded in turn, then `e`. | `Spec.encode_list_layout` |
| A dictionary is `d`, its pairs encoded in turn, key before value, then `e`. | `Spec.encode_dict_layout` |
| Every value's encoding is not empty, so an encoder that writes nothing fails here first. | `Spec.encode_ne_nil` |
| A list's items encoded in turn are the flattened encodings of the items. | `Spec.encodeList_eq_flatten` |
| `i42e` is accepted and reads back as itself. | `Spec.decode_int_example` |
| `i-42e` is accepted and reads back as itself. | `Spec.decode_negative_int_example` |
| `4:spam` is accepted and reads back as itself. | `Spec.decode_bytes_example` |
| `0:` is accepted and reads back as itself. | `Spec.decode_empty_bytes_example` |
| The BEP 3 list example, `l4:spami42ee`, is accepted and reads back as itself. | `Spec.decode_list_example` |
| The BEP 3 dictionary example, `d3:bar4:spam3:fooi42ee`, is accepted and reads back as itself. | `Spec.decode_dict_example` |
| `i03e` is refused, as the canonical form requires. | `Spec.rejects_leading_zero_int` |
| `i-0e` is refused. | `Spec.rejects_negative_zero` |
| `03:abc` is refused: a length with a leading zero. | `Spec.rejects_leading_zero_length` |
| `d3:fooi42e3:bar4:spame` is refused: keys out of order. | `Spec.rejects_unsorted_keys` |
| `1:a1:b` is refused: bytes after a value. | `Spec.rejects_trailing_bytes` |
| `l4:spam` is refused: a list with no `e`. | `Spec.rejects_truncated_list` |
| `9:spam` is refused: a length past the end. | `Spec.rejects_short_bytes` |
| `i3xe` is refused: not a decimal form. | `Spec.rejects_bad_int` |
| The empty input is refused. | `Spec.rejects_empty` |

The command-line tool in `Main.lean` calls these functions directly. The statements about the decoder are single inputs, checked in the kernel; the tests cover it on far more.

## What is not proved

- The decoder in general. That it accepts exactly the canonical encodings is tested on 200,000 inputs, not proved. The single-input statements above pin the rules the tests exercise.
- That the decoder's fuel is enough. It counts four per input byte plus four, well above the number of values a canonical encoding of that length can hold, but the bound itself is not proved; the tests cover nesting and long lists, not every depth.
- Reading and writing requests in `Main.lean`: the hex encoding, the count line, the split into lines, and the UTF-8 conversion. The tests cover them, malformed requests included.
- Speed, and memory: the code works on lists of bytes, which suits proofs, not large torrents.
- Floats and booleans, which BEP 3 does not define; the encoder has no form for them and the decoder refuses `f` and `b`. Also the BitTorrent uses of bencode that sit above the format: metainfo structure, tracker responses, and piece hashes.

## What you must trust

- The Lean kernel and the four external kernels shipped with Lean, which all check the proofs.
- `lake comparator`, which builds the statements and the proofs in a sandbox, exports them, and checks that each proof proves exactly its statement.
- bubblewrap and the Linux kernel's namespaces, which keep the untrusted build from tampering with that check.
- The Lean compiler, with the C compiler and linker shipped with it, and the runtime, which turn the proved definitions into the program that runs.
- Lean's core library, including the compiled code it puts in place of some definitions the proofs reason about (by `implemented_by` and `extern`), such as the fixed-width byte operations and the arithmetic on natural numbers.
- The operating system and hardware it runs on.
- The Python oracle: `tests/reference.py`, written from BEP 3 for these tests, and `bencode.py` when it is installed, which the record names. Python's standard library runs it.

This project has no Lean dependencies beyond Lean itself: `lake-manifest.json` lists none.

## Re-check it

Needs Linux, [elan](https://github.com/leanprover/elan), bubblewrap (`apt install bubblewrap`), and Python 3.11 or later.

```
lake build
lake comparator --paranoid
python3 tests/run_tests.py
```

The tests need no package outside the Python standard library. When `bencode.py` is installed (`pip install bencode.py`), the script also checks that the two oracles agree and names its version in the record.

`lake comparator --paranoid` builds the statements and the proofs in a sandbox. It checks that each theorem in `Proofs.lean` proves exactly the statement in `Spec.lean`, using only the axioms `propext`, `Classical.choice`, and `Quot.sound`, and replays it through every kernel shipped with Lean. The test script builds the tool, compares it with the oracle on the inputs the record names, and rewrites `tests/TEST-RESULTS.md`.

## Layout

- `Bencode.lean`: the code under proof, the encoder and the decoder.
- `Spec.lean`: the statements, with `sorry` for proofs. A reviewer approves this file.
- `Spec/Defs.lean`: the definitions the statements use, with checks against the BEP 3 examples.
- `Proofs.lean`: the proofs, under the same names.
- `Main.lean`: the command-line tool the tests drive.
- `lakefile.toml`: the build. It names the package, its libraries and executable, and the default targets, and sets nothing else.
- `comparator.json`: which theorems `lake comparator` checks, and which axioms it allows.
- `bar.toml`: the record for the bar check: status, authors, approvals, and where things are.
- `SPEC.md`: the specification in plain words.
- `tests/run_tests.py`: the differential tests.
- `tests/reference.py`: the oracle, a strict reader and writer written from BEP 3.
