/-
  Proofs of the statements in `Bencode/Spec.lean`, under the same names.

  The decoder is covered by differential tests, not by a proof, so the
  statements about it are single inputs that `decide` checks in the
  kernel: no `native_decide`, which the bar forbids.
-/

import Bencode
import Bencode.Spec.Defs

open Bencode

namespace Bencode.Proofs

/-- The byte for a digit is a digit. -/
theorem isDigit_digitChar (d : Nat) (h : d < 10) : isDigit (digitChar d) = true := by
  have hlt : 48 + d < 256 := by omega
  simp [isDigit, digitChar, UInt8.toNat_ofNat, Nat.mod_eq_of_lt hlt]
  omega

/-- Every byte of an accumulator of digits, with a number put in front
    of it, stays a digit. -/
theorem digitsAux_digits : ∀ (n : Nat) (acc : Bytes),
    (∀ c ∈ acc, isDigit c = true) → ∀ c ∈ digitsAux n acc, isDigit c = true := by
  intro n
  induction n using Nat.strongRecOn with
  | _ n ih =>
    intro acc h c hc
    match n with
    | 0 =>
      have h0 : digitsAux 0 acc = acc := Bencode.digitsAux.eq_1 acc
      rw [h0] at hc
      exact h c hc
    | Nat.succ k =>
      have hstep : digitsAux (Nat.succ k) acc =
          digitsAux (Nat.succ k / 10) (digitChar (Nat.succ k % 10) :: acc) :=
        Bencode.digitsAux.eq_2 acc k
      rw [hstep] at hc
      refine ih (Nat.succ k / 10) (Nat.div_lt_self (by omega) (by decide)) _ ?_ c hc
      intro d hd
      rcases List.mem_cons.mp hd with rfl | hd
      · exact isDigit_digitChar _ (Nat.mod_lt _ (by decide))
      · exact h d hd

/-- A number that is not zero keeps its digits when they are put in front
    of an accumulator. -/
theorem digitsAux_ne_nil : ∀ (n : Nat) (acc : Bytes), n ≠ 0 → digitsAux n acc ≠ [] := by
  intro n
  induction n using Nat.strongRecOn with
  | _ n ih =>
    intro acc h
    match n with
    | 0 => exact absurd rfl h
    | Nat.succ k =>
      have hstep : digitsAux (Nat.succ k) acc =
          digitsAux (Nat.succ k / 10) (digitChar (Nat.succ k % 10) :: acc) :=
        Bencode.digitsAux.eq_2 acc k
      rw [hstep]
      by_cases hq : Nat.succ k / 10 = 0
      · have hz : digitsAux (Nat.succ k / 10) (digitChar (Nat.succ k % 10) :: acc) =
            digitChar (Nat.succ k % 10) :: acc := by rw [hq]; exact Bencode.digitsAux.eq_1 _
        rw [hz]
        simp
      · exact ih (Nat.succ k / 10) (Nat.div_lt_self (by omega) (by decide)) _ hq

end Bencode.Proofs

theorem Bencode.Spec.digits_digits (n : Nat) : ∀ c ∈ digits n, isDigit c = true := by
  intro c hc
  by_cases h : n = 0
  · subst h
    simp [digits] at hc
    subst hc
    decide +kernel
  · simp [digits, h] at hc
    exact Bencode.Proofs.digitsAux_digits n [] (by simp) c hc

theorem Bencode.Spec.digits_ne_nil (n : Nat) : digits n ≠ [] := by
  by_cases h : n = 0
  · subst h
    simp [digits]
  · simp [digits, h]
    exact Bencode.Proofs.digitsAux_ne_nil n [] h

theorem Bencode.Spec.encode_bytes_layout (b : Bytes) :
    encode (.bytes b) = digits b.length ++ 58 :: b := by
  rfl

theorem Bencode.Spec.encode_int_layout (n : Int) :
    encode (.int n) = 105 :: (encodeInt n ++ [101]) := by
  rfl

theorem Bencode.Spec.encode_list_layout (vs : List Value) :
    encode (.list vs) = 108 :: (encodeList vs ++ [101]) := by
  rfl

theorem Bencode.Spec.encode_dict_layout (ps : List (Bytes × Value)) :
    encode (.dict ps) = 100 :: (encodePairs ps ++ [101]) := by
  rfl

theorem Bencode.Spec.encode_ne_nil (v : Value) : encode v ≠ [] := by
  cases v with
  | int n => simp [encode]
  | bytes b => simp [encode, encodeBytes]
  | list vs => simp [encode]
  | dict ps => simp [encode]

theorem Bencode.Spec.encodeList_eq_flatten (vs : List Value) :
    encodeList vs = (vs.map encode).flatten := by
  induction vs with
  | nil => rfl
  | cons v vs ih =>
    simp [encodeList, List.flatten_cons, ih]

/-! ## The decoder, case by case -/

theorem Bencode.Spec.decode_int_example :
    (decode (Bencode.Spec.ascii "i42e")).map encode = some (Bencode.Spec.ascii "i42e") := by
  decide +kernel

theorem Bencode.Spec.decode_negative_int_example :
    (decode (Bencode.Spec.ascii "i-42e")).map encode = some (Bencode.Spec.ascii "i-42e") := by
  decide +kernel

theorem Bencode.Spec.decode_bytes_example :
    (decode (Bencode.Spec.ascii "4:spam")).map encode = some (Bencode.Spec.ascii "4:spam") := by
  decide +kernel

theorem Bencode.Spec.decode_empty_bytes_example :
    (decode (Bencode.Spec.ascii "0:")).map encode = some (Bencode.Spec.ascii "0:") := by
  decide +kernel

theorem Bencode.Spec.decode_list_example :
    (decode (Bencode.Spec.ascii "l4:spami42ee")).map encode =
      some (Bencode.Spec.ascii "l4:spami42ee") := by
  decide +kernel

theorem Bencode.Spec.decode_dict_example :
    (decode (Bencode.Spec.ascii "d3:bar4:spam3:fooi42ee")).map encode =
      some (Bencode.Spec.ascii "d3:bar4:spam3:fooi42ee") := by
  decide +kernel

theorem Bencode.Spec.rejects_leading_zero_int :
    (decode (Bencode.Spec.ascii "i03e")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_negative_zero :
    (decode (Bencode.Spec.ascii "i-0e")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_leading_zero_length :
    (decode (Bencode.Spec.ascii "03:abc")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_unsorted_keys :
    (decode (Bencode.Spec.ascii "d3:fooi42e3:bar4:spame")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_trailing_bytes :
    (decode (Bencode.Spec.ascii "1:a1:b")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_truncated_list :
    (decode (Bencode.Spec.ascii "l4:spam")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_short_bytes :
    (decode (Bencode.Spec.ascii "9:spam")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_bad_int :
    (decode (Bencode.Spec.ascii "i3xe")).isSome = false := by
  decide +kernel

theorem Bencode.Spec.rejects_empty :
    (decode ([] : Bytes)).isSome = false := by
  decide +kernel
