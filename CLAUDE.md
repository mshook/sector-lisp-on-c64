# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Port Justine Tunney's [SectorLISP v2 ("friendly" variant)](https://justine.lol/sectorlisp2/) to the Commodore 64, preferably in C64 BASIC rather than 6502 assembly. The "friendly" variant is the extended version that adds `DEFINE` for persistent bindings and `(FOO . BAR)` cons dot notation.

## Reference Files

- **`lisp.js`** — The canonical reference: a C/JavaScript polyglot implementing the full evaluator. The C path is authoritative for logic; the JavaScript path (inside `#if 0`) is used on Justine's website. This is the implementation to translate.
- **`sectorlisp.S`** — x86 real-mode assembly (`.code16`), the original 512-byte MBR boot sector version. Useful for understanding the low-level memory layout, but targets x86, not 6502.

## Building the Reference C Implementation

The shell header in `lisp.js` documents the build steps:

```sh
curl -so bestline.c -z bestline.c https://justine.lol/sectorlisp2/bestline.c
curl -so bestline.h -z bestline.h https://justine.lol/sectorlisp2/bestline.h
cc -w -xc lisp.js bestline.c -o lisp
./lisp           # interactive REPL, prompt is "* "
./lisp -t        # trace mode (prints each function call)
```

## SectorLISP Architecture

**Builtins** (loaded in this exact order at startup): `NIL T EQ CAR CDR ATOM COND CONS QUOTE DEFINE`

**Evaluation model** — pure McCarthy LISP:
- `QUOTE` — returns argument unevaluated
- `COND` — takes a list of `(test expr)` pairs, evaluates first truthy branch
- `DEFINE` — adds a persistent binding to the global alist; the REPL loops back without printing
- `ATOM`, `EQ`, `CAR`, `CDR`, `CONS` — primitive operations
- User-defined functions are lambda lists: `(LAMBDA (args...) body)`

**Memory layout** (in `lisp.js`):
- `M[0..Null-1]` — atom intern table (hash map, open addressing via `Probe`/`Hash`)
- `M[Null..2*Null-1]` — cons cell heap, grows downward from index 0 (negative indices = cons cells)
- Atoms are represented as positive integers (intern table indices); cons cells as negative integers; NIL as `0`
- `cx` tracks the heap free pointer (decrements as cons cells are allocated)

**Garbage collector** — semi-space copying GC (`Gc`/`Copy`). Called after each top-level eval to reclaim temporary cons cells while preserving live values.

**`Assoc`** — walks the environment alist `((name . value) ...)`. Undefined variable prints `?name` and throws.

## C64 Target Considerations

- C64 BASIC is the preferred target (more widely understood than 6502 assembly)
- C64 has ~38KB free RAM for BASIC programs; the cons heap and intern table must fit within this
- BASIC line numbers required; GOSUB/RETURN for subroutines, no recursion stack — may need to simulate the call stack explicitly
- C64 character set is uppercase-only by default, matching SectorLISP's all-caps atom convention
- The 6502 has no hardware multiply/divide; hash functions may need simplification

## Implementation Plan

Two phases: BASIC prototype first (validated on VICE emulator), then 6502 assembly port.

### Phase 1: C64 BASIC (`lisp.bas`)

**Scope:** Minimal core only — no `DEFINE`, no dot notation. Builtins: `NIL T QUOTE COND ATOM EQ CAR CDR CONS`.

**Data representation** (matches `lisp.js` sign convention):
- `0` = NIL
- Positive integer = atom index (intern table)
- Negative integer = cons cell (negated 1-based index)

**Memory layout:**
```basic
DIM AS$(64)   ' atom string table
DIM CH%(256)  ' car array
DIM CD%(256)  ' cdr array
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

**Recursion:** Simulated via parallel stack arrays (`SK%`, `S1%`, `S2%`) since BASIC `GOSUB` cannot recurse.

**REPL skeleton:**
```basic
100 PRINT "* "; : INPUT IN$
110 IX% = 1 : GOSUB 2000
120 EE% = RV% : EA% = 0 : GOSUB 3000
130 PO% = EV% : GOSUB 5000
140 PRINT : GOTO 100
```

### Phase 2: 6502 Assembly (`lisp.asm`)

After BASIC prototype is validated:
- Zero-page registers following `sectorlisp.S` conventions
- Cons heap at fixed RAM address (e.g. `$C000` downward)
- Screen I/O via KERNAL `CHROUT` ($FFD2) and `GETIN` ($FFE4)
- Assembler: ca65 or ACME

## Testing

**Environment:** VICE emulator (`x64sc` for C64)

**Verification test suite:**
```lisp
(QUOTE A)                              → A
(CAR (QUOTE (A B C)))                  → A
(CDR (QUOTE (A B C)))                  → (B C)
(ATOM (QUOTE A))                       → T
(ATOM (QUOTE (A B)))                   → NIL
(EQ (QUOTE A) (QUOTE A))               → T
(CONS (QUOTE A) (QUOTE (B)))           → (A B)
(COND ((ATOM (QUOTE A)) (QUOTE YES)))  → YES
((LAMBDA (X) (CAR X)) (QUOTE (A B)))  → A
```
