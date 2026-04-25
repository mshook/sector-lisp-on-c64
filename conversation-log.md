# Conversation Log

## Topic: SectorLISP on C64 — Planning Session

---

**User:** I assume that many C64 games are implemented in assembler. Is that correct?

**Claude:** Yes, that's correct. The vast majority of C64 games were written in 6502 assembly language, for a few practical reasons:

- **Performance** — the C64's 1 MHz 6502 needed hand-optimized code to achieve smooth scrolling, sprites, and sound. BASIC is interpreted and roughly 100x slower.
- **Memory control** — assembly gives direct access to hardware registers (VIC-II for graphics, SID for sound, CIA for I/O) with no overhead layer.
- **Size** — tight loops and clever register use kept games small enough to fit on a 170KB floppy or cartridge ROM.

A smaller number of games used C (compiled with tools like CC65) or mixed BASIC launchers with machine code subroutines via `SYS` calls. Pure BASIC games exist but are mostly simple — text adventures, turn-based puzzles, that sort of thing.

For this project: if you want a LISP interpreter fast enough to feel interactive on real C64 hardware, 6502 assembly is the practical path. BASIC is much more approachable to read and write, but a LISP eval loop in BASIC will be noticeably slow even for small expressions.

---

**User:** Do you have a planning mode? / yes (entered planning mode)

Clarifying questions answered:
- **Target language:** Both — BASIC first, then Assembly
- **Environment:** VICE emulator
- **Scope:** Minimal core only (no DEFINE, no dot notation)

---

## Approved Implementation Plan

### Phase 1: C64 BASIC Prototype (`lisp.bas`)

**Data representation** (matches `lisp.js` sign convention):
- `0` = NIL
- Positive integer = atom index (intern table)
- Negative integer = cons cell (negated 1-based index)

**Memory layout:**
```
DIM AS$(64)   ' atom string table
DIM CH%(256)  ' car array
DIM CD%(256)  ' cdr array
```
Builtins interned at startup: NIL, T, QUOTE, COND, ATOM, EQ, CAR, CDR, CONS

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

**Recursion:** Simulated via parallel stack arrays (`SK%`, `S1%`, `S2%`) since BASIC GOSUB cannot recurse.

**REPL:**
```
100 PRINT "* "; : INPUT IN$
110 IX% = 1 : GOSUB 2000
120 EE% = RV% : EA% = 0 : GOSUB 3000
130 PO% = EV% : GOSUB 5000
140 PRINT : GOTO 100
```

### Phase 2: 6502 Assembly Port (`lisp.asm`)

After BASIC prototype is validated:
- Zero-page registers for AX, DX, SI (following `sectorlisp.S` conventions)
- Cons heap at fixed RAM address (e.g. `$C000` downward)
- Screen I/O via KERNAL `CHROUT` ($FFD2) and `GETIN` ($FFE4)
- Assembler: ca65 or ACME

### Verification Test Suite

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

---

## Status

- [x] CLAUDE.md created
- [x] Implementation plan approved
- [ ] Phase 1: `lisp.bas` — not yet started (user interrupted)
- [ ] Phase 2: `lisp.asm` — pending Phase 1
