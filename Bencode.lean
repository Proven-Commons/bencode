/-
  The code under proof: canonical bencode (BEP 3) for integers, byte
  strings, lists, and dictionaries.

  Bytes are `UInt8`. The encoder is total and produces the canonical
  form: decimal numbers with no leading zeros and no minus zero, lengths
  as decimal, dictionaries with keys in strictly increasing byte order.
  The decoder checks each of those rules and refuses anything else,
  including trailing bytes.

  The encoder is the proved part. The decoder runs and is covered by the
  differential tests in `tests/`; the page says so.
-/

namespace Bencode

/-- The alphabet of an encoding. -/
abbrev Bytes := List UInt8

/-- A value: an integer, a byte string, a list, or a dictionary. -/
inductive Value where
  | int : Int → Value
  | bytes : Bytes → Value
  | list : List Value → Value
  | dict : List (Bytes × Value) → Value

/-- The bytes a dictionary key must be in strictly increasing order by. -/
def bytesCmp : Bytes → Bytes → Ordering
  | [], [] => .eq
  | [], _ :: _ => .lt
  | _ :: _, [] => .gt
  | a :: as, b :: bs =>
    if a < b then .lt else if b < a then .gt else bytesCmp as bs

/-- Lexicographic order on byte strings, the order BEP 3 sorts keys by. -/
def bytesLt (a b : Bytes) : Bool := bytesCmp a b == .lt

/-- Key lists that strictly increase. -/
def strictSortedB : List Bytes → Bool
  | [] => true
  | [_] => true
  | a :: b :: rest => bytesLt a b && strictSortedB (b :: rest)

/- Whether a value the canonical encoder writes as itself: every nested
   value is well formed, and dictionary keys strictly increase. -/
mutual
  /-- Well-formedness, and the same for the values of a list and of a
      dictionary. -/
  def wellFormedB : Value → Bool
    | .int _ => true
    | .bytes _ => true
    | .list vs => wellFormedList vs
    | .dict ps => wellFormedPairs ps && strictSortedB (ps.map Prod.fst)

  def wellFormedList : List Value → Bool
    | [] => true
    | v :: vs => wellFormedB v && wellFormedList vs

  def wellFormedPairs : List (Bytes × Value) → Bool
    | [] => true
    | (_, v) :: ps => wellFormedB v && wellFormedPairs ps
end

/-- A value that the canonical encoder writes as itself. -/
def WellFormed (v : Value) : Prop := wellFormedB v = true

/-- A decimal digit. -/
def isDigit (c : UInt8) : Bool := 48 ≤ c.toNat && c.toNat ≤ 57

/-- A digit's value, for a byte that is a digit. -/
def digitVal (c : UInt8) : Nat := c.toNat - 48

/-- The byte for a decimal digit. -/
def digitChar (d : Nat) : UInt8 := UInt8.ofNat (48 + d)

/-- Decimal digits, most significant first, with the digits already
    found held in front of the accumulator. -/
def digitsAux : Nat → Bytes → Bytes
  | 0, acc => acc
  | Nat.succ n, acc => digitsAux (Nat.succ n / 10) (digitChar (Nat.succ n % 10) :: acc)

/-- Decimal digits, most significant first, no leading zeros, one digit
    for zero. -/
def digits (n : Nat) : Bytes :=
  if n = 0 then [48] else digitsAux n []

/-- An integer in decimal, with a minus sign when it is negative. -/
def encodeInt : Int → Bytes
  | .ofNat n => digits n
  | .negSucc n => 45 :: digits (n + 1)

/-- A byte string: its length in decimal, a colon, then the bytes. -/
def encodeBytes (b : Bytes) : Bytes := digits b.length ++ 58 :: b

/- The canonical encoding of a value. -/
mutual
  /-- The canonical encoding of a value, of the items of a list, and of
      the pairs of a dictionary. -/
  def encode : Value → Bytes
    | .int n => 105 :: (encodeInt n ++ [101])
    | .bytes b => encodeBytes b
    | .list vs => 108 :: (encodeList vs ++ [101])
    | .dict ps => 100 :: (encodePairs ps ++ [101])

  /-- The items of a list, each encoded in turn. -/
  def encodeList : List Value → Bytes
    | [] => []
    | v :: vs => encode v ++ encodeList vs

  /-- The pairs of a dictionary, key then value, each pair in turn. -/
  def encodePairs : List (Bytes × Value) → Bytes
    | [] => []
    | (k, v) :: ps => encodeBytes k ++ encode v ++ encodePairs ps
end

/- The number of values in a value, dictionaries counted by value. The
   decoder's fuel is four times this, so the bound is generous. -/
mutual
  /-- The size of a value, of a list of values, and of a dictionary. -/
  def size : Value → Nat
    | .int _ => 1
    | .bytes _ => 1
    | .list vs => 1 + sizeList vs
    | .dict ps => 1 + sizePairs ps

  def sizeList : List Value → Nat
    | [] => 0
    | v :: vs => size v + sizeList vs

  def sizePairs : List (Bytes × Value) → Nat
    | [] => 0
    | (_, v) :: ps => size v + sizePairs ps
end

/-- Decimal digits read from the left, to the first byte that is not a
    digit, with the value of the digits already read. -/
def scanNat (acc : Nat) : Bytes → Nat × Bytes
  | [] => (acc, [])
  | c :: cs =>
    if isDigit c then scanNat (acc * 10 + digitVal c) cs else (acc, c :: cs)

/-- A decimal number at the front of the input, with no leading zeros,
    and the rest. `0` is the one number that is a single zero digit. -/
def readNat : Bytes → Option (Nat × Bytes)
  | [] => none
  | c :: cs =>
    if isDigit c then
      if c = 48 then
        match cs with
        | [] => some (0, [])
        | d :: _ => if isDigit d then none else some (0, cs)
      else scanNat (digitVal c) cs
    else none

/-- An integer between `i` and `e`, with no leading zeros and no minus
    zero. -/
def readInt : Bytes → Option (Int × Bytes)
  | [] => none
  | 45 :: cs =>
    match readNat cs with
    | some (0, _) => none
    | some (n, 101 :: rest) => some (.negSucc (n - 1), rest)
    | _ => none
  | cs =>
    match readNat cs with
    | some (n, 101 :: rest) => some (.ofNat n, rest)
    | _ => none

/-- A byte string at the front of the input: a length, a colon, and that
    many bytes, then the rest. -/
def readBytes : Bytes → Option (Bytes × Bytes)
  | [] => none
  | s =>
    match readNat s with
    | some (n, 58 :: rest) =>
      if rest.length < n then none else some (rest.take n, rest.drop n)
    | _ => none

mutual

  /-- One value, with `fuel` counting the values still allowed: one for
      each item, one for each nesting. -/
  def decodeAux : Nat → Bytes → Option (Value × Bytes)
    | 0, _ => none
    | _ + 1, [] => none
    | n + 1, c :: cs =>
      if c = 105 then
        match readInt cs with
        | some (k, rest) => some (.int k, rest)
        | none => none
      else if c = 108 then
        match decodeItems n cs with
        | some (vs, rest) => some (.list vs, rest)
        | none => none
      else if c = 100 then
        match decodePairs n cs with
        | some (ps, rest) => some (.dict ps, rest)
        | none => none
      else if isDigit c then
        match readBytes (c :: cs) with
        | some (b, rest) => some (.bytes b, rest)
        | none => none
      else none

  /-- The items of a list, from the byte after its `l`, to the byte after
      its `e`. -/
  def decodeItems : Nat → Bytes → Option (List Value × Bytes)
    | 0, _ => none
    | _ + 1, [] => none
    | n + 1, c :: cs =>
      if c = 101 then some ([], cs)
      else
        match decodeAux n (c :: cs) with
        | none => none
        | some (v, rest) =>
          match decodeItems n rest with
          | none => none
          | some (vs, r) => some (v :: vs, r)

  /-- The pairs of a dictionary, from the byte after its `d`, to the byte
      after its `e`. Keys must strictly increase, so a pair is refused
      when its key is not below the next key already read. -/
  def decodePairs : Nat → Bytes → Option (List (Bytes × Value) × Bytes)
    | 0, _ => none
    | _ + 1, [] => none
    | n + 1, c :: cs =>
      if c = 101 then some ([], cs)
      else
        match readBytes (c :: cs) with
        | none => none
        | some (k, rest) =>
          match decodeAux n rest with
          | none => none
          | some (v, rest2) =>
            match decodePairs n rest2 with
            | none => none
            | some (ps, r) =>
              match ps with
              | [] => some ([(k, v)], r)
              | (k2, _) :: _ =>
                if bytesLt k k2 then some ((k, v) :: ps, r) else none

end

/-- A whole value: the decoder must end at the last byte. -/
def decode (s : Bytes) : Option Value :=
  match decodeAux (4 * s.length + 4) s with
  | some (v, []) => some v
  | _ => none

end Bencode
