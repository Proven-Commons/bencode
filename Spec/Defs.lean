/-
  The definitions the specification uses, written independently of the
  encoder and decoder in `Bencode.lean` where it matters. Part of the
  approved specification, with `Spec.lean`.

  Both the challenge file and the proofs import this file, so each
  statement means the same thing on both sides.
-/

import Bencode

open Bencode

/-- The bytes of an ASCII string, for the BEP 3 examples. -/
def Spec.ascii (s : String) : Bytes :=
  s.toList.map fun c => c.toNat.toUInt8

-- BEP 3: "i3e" is the integer 3, and reads back as itself.
example : (decode (Spec.ascii "i3e")).map encode = some (Spec.ascii "i3e") := by
  decide +kernel

-- BEP 3: "l4:spami42ee" is the list of "spam" and 42.
example : (decode (Spec.ascii "l4:spami42ee")).map encode =
    some (Spec.ascii "l4:spami42ee") := by
  decide +kernel
