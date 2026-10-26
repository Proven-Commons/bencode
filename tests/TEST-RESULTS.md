# Test results

Written by `tests/run_tests.py`. Rerun it to check these numbers.

- Oracle: tests/reference.py, written from BEP 3; cross-checked with bencode.py 4.1.0
- Lean: Lean (version 4.35.0, arm64-apple-darwin24.6.0, commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc, Release)
- Seed: 20261026
- Inputs: 200000
- Mutated: 149967 requests are mutations of a canonical encoding
- Canonical table: 21 canonical forms and 22 refusals, from BEP 3
- Failures: 0

Each request is one encoding in hexadecimal, and the answer must be the
canonical bytes written back (`ok`) or a refusal (`error`). The expected
answer comes from the oracle: the input is canonical exactly when reading
it and writing it back gives the same bytes. A failure is printed above
and makes the script exit non-zero.

bencode.py agreed on 60318 values, 0 disagreements.
