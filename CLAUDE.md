# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Port Justine Tunney's [SectorLISP v2 ("friendly" variant)](https://justine.lol/sectorlisp2/) to the Commodore 64. The "friendly" variant adds `DEFINE` for persistent bindings and `(FOO . BAR)` cons dot notation. The current port is a minimal core (no `DEFINE`, no dot notation).

## Reference Files

- **`lisp.js`** — The canonical reference: a C/JavaScript polyglot implementing the full evaluator. The C path is authoritative for logic.
- **`sectorlisp.S`** — x86 real-mode assembly (`.code16`), the original 512-byte MBR boot sector version. x86 only — useful for architecture reference, not directly portable.
- **`verify.py`** — Python port of `lisp.bas` for offline test verification. Run `python3 verify.py`.

## Building the Reference C Implementation

```sh
curl -so bestline.c -z bestline.c https://justine.lol/sectorlisp2/bestline.c
curl -so bestline.h -z bestline.h https://justine.lol/sectorlisp2/bestline.h
cc -w -xc lisp.js bestline.c -o lisp
./lisp           # interactive REPL, prompt is "* "
./lisp -t        # trace mode
```

## SectorLISP Architecture

**Builtins** (loaded in this exact order at startup): `NIL T EQ CAR CDR ATOM COND CONS QUOTE DEFINE`

**Evaluation model** — pure McCarthy LISP:
- `QUOTE` — returns argument unevaluated
- `COND` — list of `(test expr)` pairs; evaluates first truthy branch
- `ATOM`, `EQ`, `CAR`, `CDR`, `CONS` — primitive operations
- User-defined functions: `(LAMBDA (args...) body)`

**Value representation** (both BASIC and assembly):
- `0` = NIL
- Positive integer = atom index
- Negative integer = cons cell (negated 1-based index into CH/CD arrays)

## Status

Both phases are implemented and working.

### Phase 1: C64 BASIC (`lisp.bas`) — Complete

Minimal core: `NIL T QUOTE COND ATOM EQ CAR CDR CONS`. Recursion simulated via parallel stack arrays (`SK%`, `S1%`, `S2%`, `S3%`).

Type `DUMP` at the REPL to toggle heap dump output after each read (shows AS, CH, CD arrays).

**Memory:**
```basic
DIM AS$(64)   ' atom string table
DIM CH%(256)  ' car array
DIM CD%(256)  ' cdr array
DIM SK%(64), S1%(64), S2%(64), S3%(64)  ' sim stacks
```

**Subroutine map:**

| Line | Subroutine  | Inputs          | Output |
|------|-------------|-----------------|--------|
| 1000 | INTERN      | TK$             | AX%    |
| 2000 | READ_EXPR   | IN$, IX%        | RV%    |
| 2100 | READ_LIST   | IN$, IX%        | RV%    |
| 3000 | EVAL        | EE%, EA%        | EV%    |
| 3100 | EVLIS       | EM%, EA%        | EV%    |
| 3200 | EVCON       | EC%, EA%        | EV%    |
| 3300 | APPLY       | AF%, AX%, AA%   | EV%    |
| 4000 | ASSOC       | SX%, SA%        | EV%    |
| 4100 | PAIRLIS     | PX%, PY%, PA%   | EV%    |
| 5000 | PRINT_OBJ   | PO%             | —      |
| 6000 | CONS_ALLOC  | CC%, DD%        | RV%    |

### Phase 2: 6502 Assembly (`lisp.asm`) — In progress

**Assembler:** ACME

```sh
acme --cpu 6502 lisp.asm          # produces lisp.prg
acme --cpu 6502 --report listing.txt lisp.asm   # with listing
acme --cpu 6502 --vicelabels labels.txt lisp.asm  # VICE debug labels
x64sc lisp.prg                    # run in VICE
```

**Memory layout:**

```
$0801–$080C   BASIC stub (10 SYS 2061)
$080D–~$1220  Code

$1400         ch_lo / ch_hi   (256 bytes each) — car arrays
$1600         cd_lo / cd_hi   (256 bytes each) — cdr arrays
$1800         as_tab          (8 bytes/atom × 128 atoms) — atom string table
$1c00         in_buf          input line buffer
$1d00         tok_buf         token scratch
$1d40/$1d80   sk_lo/sk_hi     saved-EA stack
$1dc0/$1e00   s1_lo/s1_hi     sim stack slot 1
$1e40/$1e80   s2_lo/s2_hi     sim stack slot 2
$1ec0/$1f00   s3_lo/s3_hi     sim stack slot 3
```

**CRITICAL: all data arrays must be placed above the end of code** (~$1220). ACME places code and data in the address space sequentially; arrays at $1000–$12FF overlap the code region and cause `cons_alloc` to overwrite its own instructions on the first allocation.

**Zero-page layout (key variables, all 2-byte):**

```
$02  zNA/$03 zNC/$04 zSP/$05 zIX   — counters (1 byte each)
$06–$0e  zKN..zKO                  — builtin atom indices (1 byte each)
$10  zEA   environment
$12  zRV   general return value
$14  zEV   eval return value
$16  zEE   eval: input expr
$18  zEF   eval: function (unused in current eval_ — kept for reference)
$1a  zEM   evlis: list
$26  zAF   apply: function
$28  zAXX  apply: arg list
$2a  zAA   apply: env
$40  zCC / $42 zDD   cons_alloc inputs
$4a  zPO   print_obj input
$4c  zTKP  token pointer (into in_buf)
$50  zAX   intern result (1 byte)
$51  zDM   dump mode flag (1 byte)
```

**Key implementation notes:**

- All ZP variables are global. When `eval_` calls `evlis` which calls `eval_` recursively, the inner call overwrites the outer call's working variables. The fix: save critical values to the sim stack (s1/s2/s3 arrays indexed by zSP) before any call that recurses, restore after.
- In `eval_` function application: `car(EE)` (the function) is saved to `s1[SP]` before calling `evlis`, then popped to `zAF` after. Do NOT store it to `zEF` before the QUOTE/COND checks — inner `eval_` calls in evlis will clobber it.
- Cons dereferencing: value V (negative) → index = `LDA #0 : SEC : SBC <V : TAX` → use `ch_lo,X` etc.
- Atom test: `LDA zVAL+1 : BEQ atom_path` (hi byte = 0 for atoms and NIL)
- NIL test: `LDA zVAL : ORA zVAL+1 : BEQ nil_path`

## Testing

**Environment:** VICE emulator (`x64sc`) or online C64 emulator

**Verification test suite** (also in `verify.py`):
```lisp
(QUOTE A)                              → A
(CAR (QUOTE (A B C)))                  → A
(CDR (QUOTE (A B C)))                  → (B C)
(ATOM (QUOTE A))                       → T
(ATOM (QUOTE (A B)))                   → NIL
(EQ (QUOTE A) (QUOTE A))              → T
(CONS (QUOTE A) (QUOTE (B)))          → (A B)
(COND ((ATOM (QUOTE A)) (QUOTE YES))) → YES
((LAMBDA (X) (CAR X)) (QUOTE (A B))) → A
((LAMBDA (X) (X X)) (QUOTE (LAMBDA (X) (QUOTE A)))) → A
```

The last test exercises self-application (basis of recursion): X is bound to the quoted lambda, `(X X)` applies it to itself, the inner call returns A.
