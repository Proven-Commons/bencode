/-
  Command line front end, used by the differential tests.

  Reads one request per line from standard input and writes one answer
  per line. The first line is the number of requests. Each request is an
  encoding written in lowercase hexadecimal, which keeps the batch safe
  to pass as text; an empty line is the empty input.

  Each answer is `ok <hex>`, where the hex is the canonical encoding of
  the value the decoder read, or `error` when the decoder refused the
  input. So `ok` with the same hex means the input was canonical and read
  back as itself, and `error` means it was refused.
-/

import Bencode

open Bencode

/-- All of standard input. -/
def readAll : IO ByteArray := do
  let stdin ← IO.getStdin
  let mut acc := ByteArray.empty
  let mut more := true
  while more do
    let chunk ← stdin.read 65536
    if chunk.size == 0 then more := false else acc := acc.append chunk
  return acc

/-- A hexadecimal digit's value. -/
def hexVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - 48)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 87)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 55)
  else none

/-- Bytes from hexadecimal, two digits each. -/
def parseHex : List Char → Option Bytes
  | [] => some []
  | a :: b :: rest =>
    match hexVal a, hexVal b with
    | some x, some y => (parseHex rest).map fun bs => UInt8.ofNat (x * 16 + y) :: bs
    | _, _ => none
  | [_] => none

/-- The lowercase hexadecimal digit for a value below 16. -/
def hexDigit (n : Nat) : Char :=
  if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n)

/-- A byte as two lowercase hexadecimal digits. -/
def hexByte (b : UInt8) : String :=
  String.ofList [hexDigit (b.toNat / 16), hexDigit (b.toNat % 16)]

/-- Bytes as lowercase hexadecimal. -/
def hexOfBytes (bs : Bytes) : String :=
  String.join (bs.map hexByte)

def main (_ : List String) : IO UInt32 := do
  let input ← readAll
  let some text := String.fromUTF8? input
    | IO.eprintln "input is not UTF-8"; return 1
  let stdout ← IO.getStdout
  match text.splitOn "\n" with
  | [] => IO.eprintln "no count line"; return 1
  | countLine :: rest =>
    let some count := countLine.toNat?
      | IO.eprintln "count is not a number"; return 1
    if rest.length < count then
      IO.eprintln "fewer requests than the count"; return 1
    let mut buf := ""
    for line in rest.take count do
      let answer :=
        match parseHex line.toList with
        | none => "error"
        | some bytes =>
          match decode bytes with
          | none => "error"
          | some v => "ok " ++ hexOfBytes (encode v)
      buf := buf ++ answer ++ "\n"
      if buf.length > 1048576 then
        stdout.putStr buf
        buf := ""
    if !buf.isEmpty then stdout.putStr buf
  return 0
