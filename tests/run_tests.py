#!/usr/bin/env python3
"""Differential tests: the Lean bencode decoder and encoder against BEP 3.

The oracle is `tests/reference.py`, a strict bencode reader and writer
written from BEP 3 for these tests and independent of the Lean code. When
`bencode` (the `bencode.py` package) is installed, the script also checks
that the two agree on every generated value, and names its version in the
record; the tests themselves need no package outside the standard
library.

Inputs come from a recorded seed:

- the examples of BEP 3, and a fixed table of canonical forms and refusals;
- random values: integers, byte strings, lists, and dictionaries with
  sorted keys, to a depth of four;
- mutations of their encodings: a byte flipped, inserted, deleted,
  duplicated, or appended, and one encoding prefixed with another.

Every request is one encoding, written in hexadecimal. The answer must be
`ok <hex>` with the same bytes when the oracle reads the input as
canonical, and `error` when it does not. So each input checks the decoder
and the encoder at once: a value read back must be written back exactly.

    python3 tests/run_tests.py [--seed N] [--count N]

It builds the executable if it is missing, writes `tests/TEST-RESULTS.md`,
and exits non-zero if any input disagrees. It needs Python 3.11 or later.
"""

import argparse
import random
import subprocess
import sys
from pathlib import Path

from reference import decode, encode

ROOT = Path(__file__).resolve().parent.parent
EXE = ROOT / ".lake" / "build" / "bin" / "bencode"
RESULTS = ROOT / "tests" / "TEST-RESULTS.md"
BATCH = 2000

CANONICAL = [
    b"i0e", b"i3e", b"i-3e", b"i42e", b"i-42e", b"i9223372036854775807e",
    b"0:", b"1:a", b"4:spam", b"12:hello world!", b"0:0:",
    b"le", b"li1ei2ee", b"l4:spami42ee",
    b"de", b"d1:ai1e", b"d1:ai1e1:bi2ee", b"d3:bar4:spam3:fooi42ee",
    b"d1:ad1:bl1:ci1eeee",
    b"l" + b"i1e" * 100 + b"e",
    b"d" + b"".join(b"%d:k%d" % (len(b"k%d" % i), i) + b"i1e" for i in range(20)) + b"e",
]

REFUSED = [
    b"",
    b"i",
    b"ie",
    b"i03e",
    b"i-0e",
    b"i+3e",
    b"i3",
    b"i3xe",
    b"03:abc",
    b"3:ab",
    b"9:spam",
    b"-1:a",
    b"l4:spam",
    b"li1e",
    b"d3:fooi42e3:bar4:spame",
    b"d1:bi1e1:ai2ee",
    b"d1:ai1e1:ai2ee",
    b"d1:ai1e",
    b"1:a1:b",
    b"i1ei2e",
    b"l1:ae",
    b"e",
]

TOKENS = [b"spam", b"", b"a", b"\x00\xff", b"hello world!", b"k1", b"k2", b"x" * 40]


def value(rng, depth=0):
    """A value the canonical encoder can write: dict keys sorted."""
    kinds = ["int", "bytes"] if depth >= 4 else ["int", "bytes", "list", "dict"]
    kind = rng.choice(kinds)
    if kind == "int":
        return rng.choice([0, 1, -1, 42, -42, 2**31, -(2**40), rng.randint(-10**6, 10**6)])
    if kind == "bytes":
        return bytes(rng.choice(TOKENS) if rng.random() < 0.5 else
                     bytes(rng.randrange(256) for _ in range(rng.randrange(8))))
    if kind == "list":
        return [value(rng, depth + 1) for _ in range(rng.randrange(5))]
    keys = sorted({bytes(rng.choice(TOKENS)) for _ in range(rng.randrange(4))})
    return {k: value(rng, depth + 1) for k in keys}


def mutate(rng, data):
    """One edit that may or may not keep the encoding canonical."""
    if not data:
        return b"i1e"
    i = rng.randrange(len(data))
    kind = rng.choice(["flip", "insert", "delete", "duplicate", "append", "prefix"])
    if kind == "flip":
        return data[:i] + bytes([data[i] ^ (1 << rng.randrange(8))]) + data[i + 1:]
    if kind == "insert":
        return data[:i] + bytes([rng.randrange(256)]) + data[i:]
    if kind == "delete":
        return data[:i] + data[i + 1:]
    if kind == "duplicate":
        return data[:i] + data[i:i + 1] + data[i:]
    if kind == "append":
        return data + bytes([rng.randrange(256)])
    return b"i1e" + data


def verdict(data):
    """The canonical answer: the bytes themselves, or None for a refusal."""
    try:
        return encode(decode(data))
    except (ValueError, TypeError):
        return None


def run_tool(inputs):
    """One batch through the executable; returns one answer per input."""
    lines = [str(len(inputs))]
    lines += [data.hex() for data in inputs]
    request = "\n".join(lines) + "\n"
    out = subprocess.run([str(EXE)], input=request.encode("utf-8"),
                         capture_output=True, timeout=1800)
    if out.returncode != 0:
        raise SystemExit(f"the tool exited {out.returncode}: {out.stderr.decode()}")
    answers = out.stdout.decode("utf-8").split("\n")
    if answers and answers[-1] == "":
        answers.pop()
    return answers


def expected(data):
    want = verdict(data)
    return "error" if want is None else "ok " + want.hex()


def check(inputs):
    """Compare one batch. Returns (failures, first few disagreements)."""
    got = run_tool(inputs)
    if len(got) != len(inputs):
        return len(inputs), [f"answered {len(got)} times for {len(inputs)} requests"]
    failures, examples = 0, []
    for data, answer in zip(inputs, got):
        want = expected(data)
        if answer != want:
            failures += 1
            if len(examples) < 5:
                examples.append(f"{data!r} gave {answer!r}, wanted {want!r}")
    return failures, examples


def generate(seed, count):
    """Requests, and how many of them are mutations."""
    rng = random.Random(seed)
    inputs = list(CANONICAL) + list(REFUSED)
    mutated = 0
    while len(inputs) < count:
        data = encode(value(rng))
        inputs.append(data)
        for _ in range(3):
            if len(inputs) < count:
                inputs.append(mutate(rng, data))
                mutated += 1
    return inputs, mutated


def oracle_versions():
    """The oracle's name and version, with bencode.py when it is installed."""
    text = "tests/reference.py, written from BEP 3"
    try:
        import bencode  # noqa: PLC0415
    except ImportError:
        return text + "; bencode.py not installed, so not cross-checked"
    try:
        from importlib.metadata import version as package_version  # noqa: PLC0415
        version = package_version("bencode.py")
    except Exception:  # noqa: BLE001
        version = "unknown"
    return f"{text}; cross-checked with bencode.py {version}"


def cross_check(inputs):
    """When bencode.py is installed, check that it agrees on the values."""
    try:
        import bencode  # noqa: PLC0415
    except ImportError:
        return None
    checked, disagreements = 0, []
    for data in inputs:
        try:
            value = bencode.bdecode(data)
        except Exception:  # noqa: BLE001 - any exception means "refused"
            continue
        try:
            again = bencode.bencode(value)
        except Exception:  # noqa: BLE001
            continue
        if again != data:
            continue
        checked += 1
        try:
            ours = decode(data)
        except ValueError:
            disagreements.append(data)
            continue
        if encode(ours) != again:
            disagreements.append(data)
    return checked, disagreements


def lean_version():
    try:
        out = subprocess.run(["lean", "--version"], capture_output=True, text=True, timeout=60)
        return out.stdout.strip() if out.returncode == 0 else "unknown"
    except OSError:
        return "unknown"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seed", type=int, default=20261026)
    ap.add_argument("--count", type=int, default=200000)
    args = ap.parse_args()

    if not EXE.is_file():
        print("building the executable", flush=True)
        subprocess.run(["lake", "build", "bencode"], cwd=ROOT, check=True)

    inputs, mutated = generate(args.seed, args.count)
    failures, examples = 0, []
    for start in range(0, len(inputs), BATCH):
        f, e = check(inputs[start:start + BATCH])
        failures += f
        examples += e[:5 - len(examples)]
        print(f"  {min(start + BATCH, len(inputs))} of {len(inputs)} requests, "
              f"{failures} failures", flush=True)

    cross = cross_check(inputs)
    cross_line = "bencode.py is not installed; the oracle was not cross-checked"
    if cross is not None:
        checked, disagreements = cross
        cross_line = f"bencode.py agreed on {checked} values, {len(disagreements)} disagreements"
        failures += len(disagreements)
        examples += [f"{d!r} was refused by the reference but accepted by bencode.py"
                     for d in disagreements[:5 - len(examples)]]

    print(f"failures: {failures}")
    for line in examples:
        print("  " + line)

    RESULTS.write_text(f"""# Test results

Written by `tests/run_tests.py`. Rerun it to check these numbers.

- Oracle: {oracle_versions()}
- Lean: {lean_version()}
- Seed: {args.seed}
- Inputs: {len(inputs)}
- Mutated: {mutated} requests are mutations of a canonical encoding
- Canonical table: {len(CANONICAL)} canonical forms and {len(REFUSED)} refusals, from BEP 3
- Failures: {failures}

Each request is one encoding in hexadecimal, and the answer must be the
canonical bytes written back (`ok`) or a refusal (`error`). The expected
answer comes from the oracle: the input is canonical exactly when reading
it and writing it back gives the same bytes. A failure is printed above
and makes the script exit non-zero.

{cross_line}.
""")
    print(f"wrote {RESULTS.relative_to(ROOT)}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
