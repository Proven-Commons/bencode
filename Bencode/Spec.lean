/-
  The specification as Lean statements: the challenge file.

  A reviewer who did not write this file approves it, and `bar.toml`
  records the SHA-256 it had then. The proofs live in `Bencode/Proofs.lean`;
  `lake comparator` checks that each one proves exactly the statement
  written here. The `sorry` below is expected in this file only.

  The definitions the statements use are in `Spec/Defs.lean`, which is
  part of the specification too.
-/

import Bencode
import Bencode.Spec.Defs

open Bencode

/-! ## The decimal form

BEP 3 writes lengths and integers in decimal, and the canonical form has
no leading zeros: `0` is one zero digit, and no other number starts with
one. -/

/-- Every byte of a decimal form is a digit. -/
theorem Bencode.Spec.digits_digits (n : Nat) : ∀ c ∈ digits n, isDigit c = true := sorry

/-- A decimal form always has at least one digit, so it is never empty. -/
theorem Bencode.Spec.digits_ne_nil (n : Nat) : digits n ≠ [] := sorry

/-! ## The layout

Each kind of value has one shape, and the four statements below say which.
They are what an implementation of another language would follow to read
this encoder's output. -/

/-- A byte string is its length in decimal, a colon, then the bytes. -/
theorem Bencode.Spec.encode_bytes_layout (b : Bytes) :
    encode (.bytes b) = digits b.length ++ 58 :: b := sorry

/-- An integer is `i`, its decimal form, then `e`. -/
theorem Bencode.Spec.encode_int_layout (n : Int) :
    encode (.int n) = 105 :: (encodeInt n ++ [101]) := sorry

/-- A list is `l`, its items encoded in turn, then `e`. -/
theorem Bencode.Spec.encode_list_layout (vs : List Value) :
    encode (.list vs) = 108 :: (encodeList vs ++ [101]) := sorry

/-- A dictionary is `d`, its pairs encoded in turn, key before value,
    then `e`. -/
theorem Bencode.Spec.encode_dict_layout (ps : List (Bytes × Value)) :
    encode (.dict ps) = 100 :: (encodePairs ps ++ [101]) := sorry

/-- Every value has a written form that is not empty. So an encoder that
    writes nothing fails this before any other claim is reached. -/
theorem Bencode.Spec.encode_ne_nil (v : Value) : encode v ≠ [] := sorry

/-- A list's items, encoded one after another, are the encodings of the
    items placed one after another. This is the bridge between the
    definition of `encodeList` and the flattened form used in `SPEC.md`. -/
theorem Bencode.Spec.encodeList_eq_flatten (vs : List Value) :
    encodeList vs = (vs.map encode).flatten := sorry

/-! ## The decoder, case by case

The decoder is not proved in general here. These statements are single
inputs, checked by machine, that pin the rules the tests then cover on
many more: what the decoder accepts, and what it refuses. An input is
accepted when the value it decodes to is written back as the same bytes,
which the claims state as `(decode s).map encode = some s`. -/

/-- An integer. -/
theorem Bencode.Spec.decode_int_example :
    (decode (Bencode.Spec.ascii "i42e")).map encode = some (Bencode.Spec.ascii "i42e") := sorry

/-- A negative integer. -/
theorem Bencode.Spec.decode_negative_int_example :
    (decode (Bencode.Spec.ascii "i-42e")).map encode = some (Bencode.Spec.ascii "i-42e") := sorry

/-- A byte string. -/
theorem Bencode.Spec.decode_bytes_example :
    (decode (Bencode.Spec.ascii "4:spam")).map encode = some (Bencode.Spec.ascii "4:spam") := sorry

/-- An empty byte string. -/
theorem Bencode.Spec.decode_empty_bytes_example :
    (decode (Bencode.Spec.ascii "0:")).map encode = some (Bencode.Spec.ascii "0:") := sorry

/-- The list example of BEP 3. -/
theorem Bencode.Spec.decode_list_example :
    (decode (Bencode.Spec.ascii "l4:spami42ee")).map encode =
      some (Bencode.Spec.ascii "l4:spami42ee") := sorry

/-- The dictionary example of BEP 3. -/
theorem Bencode.Spec.decode_dict_example :
    (decode (Bencode.Spec.ascii "d3:bar4:spam3:fooi42ee")).map encode =
      some (Bencode.Spec.ascii "d3:bar4:spam3:fooi42ee") := sorry

/-- An integer with a leading zero is refused, as BEP 3 requires. -/
theorem Bencode.Spec.rejects_leading_zero_int :
    (decode (Bencode.Spec.ascii "i03e")).isSome = false := sorry

/-- Minus zero is refused. -/
theorem Bencode.Spec.rejects_negative_zero :
    (decode (Bencode.Spec.ascii "i-0e")).isSome = false := sorry

/-- A length with a leading zero is refused. -/
theorem Bencode.Spec.rejects_leading_zero_length :
    (decode (Bencode.Spec.ascii "03:abc")).isSome = false := sorry

/-- A dictionary whose keys do not strictly increase is refused. -/
theorem Bencode.Spec.rejects_unsorted_keys :
    (decode (Bencode.Spec.ascii "d3:fooi42e3:bar4:spame")).isSome = false := sorry

/-- Bytes after a value are refused rather than ignored. -/
theorem Bencode.Spec.rejects_trailing_bytes :
    (decode (Bencode.Spec.ascii "1:a1:b")).isSome = false := sorry

/-- A list with no `e` is refused, and is not read as a shorter list. -/
theorem Bencode.Spec.rejects_truncated_list :
    (decode (Bencode.Spec.ascii "l4:spam")).isSome = false := sorry

/-- A length that runs past the end of the input is refused. -/
theorem Bencode.Spec.rejects_short_bytes :
    (decode (Bencode.Spec.ascii "9:spam")).isSome = false := sorry

/-- An integer with a byte that is not a digit, and no `e`, is refused. -/
theorem Bencode.Spec.rejects_bad_int :
    (decode (Bencode.Spec.ascii "i3xe")).isSome = false := sorry

/-- Empty input is refused: it is not the empty list. -/
theorem Bencode.Spec.rejects_empty :
    (decode ([] : Bytes)).isSome = false := sorry
