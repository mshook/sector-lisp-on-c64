; SectorLISP for Commodore 64 — 6502 assembly
; Translated from lisp.bas
; Build: acme --cpu 6502 lisp.asm

!to "lisp.prg", cbm

; ============================================================
; KERNAL
CHROUT  = $ffd2
CHRIN   = $ffcf
CR      = 13

; ============================================================
; DATA MEMORY
; Code ends around $1220 — all data arrays must start well above that.
ch_lo   = $1400     ; car lo bytes  [index 1..255]
ch_hi   = $1500     ; car hi bytes
cd_lo   = $1600     ; cdr lo bytes
cd_hi   = $1700     ; cdr hi bytes
as_tab  = $1800     ; atom strings: 8 bytes/atom, atom k at as_tab+(k-1)*8
in_buf  = $1c00     ; input line buffer (null-terminated)
tok_buf = $1d00     ; 8-byte token scratch
sk_lo   = $1d40     ; SK stack lo (saved EA)
sk_hi   = $1d80     ; SK stack hi
s1_lo   = $1dc0     ; S1 stack lo
s1_hi   = $1e00     ; S1 stack hi
s2_lo   = $1e40     ; S2 stack lo
s2_hi   = $1e80     ; S2 stack hi
s3_lo   = $1ec0     ; S3 stack lo
s3_hi   = $1f00     ; S3 stack hi

; ============================================================
; ZERO PAGE — 1-byte counters/indices
zNA     = $02       ; NA%  atom count
zNC     = $03       ; NC%  cons count
zSP     = $04       ; SP%  sim-stack pointer
zIX     = $05       ; IX%  input buffer index (0-based)

; 1-byte builtin atom indices
zKN     = $06       ; NIL
zKT     = $07       ; T
zKQ     = $08       ; QUOTE
zKC     = $09       ; COND
zKA     = $0a       ; ATOM
zKE     = $0b       ; EQ
zKR     = $0c       ; CAR
zKD     = $0d       ; CDR
zKO     = $0e       ; CONS

; 2-byte LISP values (lo at base addr, hi at base+1)
zEA     = $10       ; EA%  environment
zRV     = $12       ; RV%  read / general return value
zEV     = $14       ; EV%  eval return value
zEE     = $16       ; EE%  eval: expression
zEF     = $18       ; EF%  eval: function
zEM     = $1a       ; EM%  evlis: list
zEG     = $1c       ; EG%  evlis: head
zES     = $1e       ; ES%  evlis: tail
zEP     = $20       ; EP%  evlis: element
zET     = $22       ; ET%  evcon: test result
zEC     = $24       ; EC%  evcon: cond list
zAF     = $26       ; AF%  apply: function
zAXX    = $28       ; AX%  apply: arg list
zAA     = $2a       ; AA%  apply: environment
zSX     = $2c       ; SX%  assoc: key
zSA     = $2e       ; SA%  assoc: list
zPX     = $30       ; PX%  pairlis: params
zPY     = $32       ; PY%  pairlis: values
zPA     = $34       ; PA%  pairlis: parent env
zPN     = $36       ; PN%  pairlis: param name
zPV     = $38       ; PV%  pairlis: param value
zPP     = $3a       ; PP%  pairlis: cell temp
zRG     = $3c       ; RG%  pairlis: result head
zRS     = $3e       ; RS%  pairlis: result tail
zCC     = $40       ; CC%  cons_alloc: car
zDD     = $42       ; DD%  cons_alloc: cdr
zRH     = $44       ; RH%  read_list: head
zRT     = $46       ; RT%  read_list: tail
zRP     = $48       ; RP%  read_list: element
zPO     = $4a       ; PO%  print_obj: object
zTKP    = $4c       ; token pointer (2-byte address into tok_buf or builtin strings)
zASP    = $4e       ; atom-string pointer (2-byte address into as_tab)
zAX     = $50       ; AX%  intern result (1-byte atom index, hi always 0)
zDM     = $51       ; dump-mode flag: 0=off, 1=on

; ============================================================
; MACROS

; copy 16-bit ZP src -> dst
!macro mv16 .d, .s {
    LDA .s   : STA .d
    LDA .s+1 : STA .d+1
}

; zero a 16-bit ZP location
!macro clr16 .d {
    LDA #0 : STA .d : STA .d+1
}

; given a cons value in ZP .src, load its 1-based index into X
; (cons lo byte = 256-k, negate it: k = -lo)
!macro cidx .src {
    LDA #0 : SEC : SBC .src
    TAX
}

; load CH[cons .src] into A(lo)/Y(hi)
!macro carof .src {
    LDA #0 : SEC : SBC .src : TAX
    LDA ch_lo,X : LDY ch_hi,X
}

; load CD[cons .src] into A(lo)/Y(hi)
!macro cdrof .src {
    LDA #0 : SEC : SBC .src : TAX
    LDA cd_lo,X : LDY cd_hi,X
}

; ============================================================
; BASIC STUB: 10 SYS 2061
* = $0801
!byte $0b,$08, $0a,$00, $9e, $32,$30,$36,$31, $00, $00,$00

; ============================================================
; STARTUP (lines 50-95)
* = $080d

!zone start
start:
    LDA #0
    STA zNA : STA zNC : STA zSP
    STA zEA : STA zEA+1
    STA zDM

    LDA #<str_NIL   : STA zTKP : LDA #>str_NIL   : STA zTKP+1
    JSR intern : LDA zAX : STA zKN

    LDA #<str_T     : STA zTKP : LDA #>str_T     : STA zTKP+1
    JSR intern : LDA zAX : STA zKT

    LDA #<str_QUOTE : STA zTKP : LDA #>str_QUOTE : STA zTKP+1
    JSR intern : LDA zAX : STA zKQ

    LDA #<str_COND  : STA zTKP : LDA #>str_COND  : STA zTKP+1
    JSR intern : LDA zAX : STA zKC

    LDA #<str_ATOM  : STA zTKP : LDA #>str_ATOM  : STA zTKP+1
    JSR intern : LDA zAX : STA zKA

    LDA #<str_EQ    : STA zTKP : LDA #>str_EQ    : STA zTKP+1
    JSR intern : LDA zAX : STA zKE

    LDA #<str_CAR   : STA zTKP : LDA #>str_CAR   : STA zTKP+1
    JSR intern : LDA zAX : STA zKR

    LDA #<str_CDR   : STA zTKP : LDA #>str_CDR   : STA zTKP+1
    JSR intern : LDA zAX : STA zKD

    LDA #<str_CONS  : STA zTKP : LDA #>str_CONS  : STA zTKP+1
    JSR intern : LDA zAX : STA zKO

    ; fall through to repl

; ============================================================
; REPL (lines 100-140)
!zone repl
repl:
    LDA #0 : STA zSP
    LDA #0 : STA zEA : STA zEA+1

    LDA #'*' : JSR CHROUT
    LDA #' ' : JSR CHROUT

    ; read line into in_buf
    LDX #0
.rdch:
    JSR CHRIN
    CMP #CR : BEQ .rddone
    STA in_buf,X
    INX : BNE .rdch
.rddone:
    LDA #0 : STA in_buf,X   ; null-terminate
    LDA #0 : STA zIX        ; reset input index

    ; check for "DUMP" toggle command
    LDA in_buf+0 : CMP #'D' : BNE .not_dump
    LDA in_buf+1 : CMP #'U' : BNE .not_dump
    LDA in_buf+2 : CMP #'M' : BNE .not_dump
    LDA in_buf+3 : CMP #'P' : BNE .not_dump
    LDA in_buf+4 : BNE .not_dump
    LDA zDM : EOR #1 : STA zDM
    JMP repl
.not_dump:

    JSR read_expr

    LDA zDM : BEQ +
    JSR dump
+:

    +mv16 zEE, zRV
    LDA #0 : STA zEA : STA zEA+1
    JSR eval_

    +mv16 zPO, zEV
    JSR print_obj

    LDA #CR : JSR CHROUT
    JMP repl

; ============================================================
; BUILTIN STRINGS
str_NIL:   !text "NIL",0
str_T:     !text "T",0
str_QUOTE: !text "QUOTE",0
str_COND:  !text "COND",0
str_ATOM:  !text "ATOM",0
str_EQ:    !text "EQ",0
str_CAR:   !text "CAR",0
str_CDR:   !text "CDR",0
str_CONS:  !text "CONS",0

; error message strings
str_econd: !text "?COND",0
str_eheap: !text "?HEAP",0
str_equs:  !text "?",0      ; prefix for undefined variable

; ============================================================
; ERROR — print string at zTKP, CR, then restart REPL
; Caller sets zTKP before JSR err (or JMP err_repl directly)
!zone errstr
err_str:
    LDY #0
.lp:
    LDA (zTKP),Y : BEQ .done
    JSR CHROUT
    INC zTKP : BNE .lp : INC zTKP+1 : JMP .lp
.done:
    LDA #CR : JSR CHROUT
    JMP repl

; ============================================================
; SKIP_WS — advance zIX past whitespace in in_buf
!zone skipws
skip_ws:
    LDX zIX
.lp:
    LDA in_buf,X : BEQ .done
    CMP #' '+1 : BCS .done
    INX : JMP .lp
.done:
    STX zIX : RTS

; ============================================================
; STRCMP — compare null-terminated strings at zTKP and zASP
; Returns: Z set if equal
!zone strcmp
strcmp:
    LDY #0
.lp:
    LDA (zTKP),Y
    CMP (zASP),Y : BNE .ne
    BEQ .check_end  ; chars equal; check null
.check_end:
    LDA (zTKP),Y    ; if it's null, both ended -> equal
    BEQ .eq
    INY : JMP .lp
.ne:
    RTS             ; Z clear
.eq:
    RTS             ; Z set (LDA #0 set it)

; ============================================================
; INTERN_ASP — set zASP to entry for atom k (1-based) in as_tab
; Input: zAX = k (1..127)
; Computes zASP = as_tab + (k-1)*8
!zone internasp
intern_asp:
    LDA zAX : SEC : SBC #1  ; A = k-1 (0-based)
    STA zASP                 ; use zASP as temp lo
    LDA #0 : STA zASP+1
    ASL zASP : ROL zASP+1   ; *2
    ASL zASP : ROL zASP+1   ; *4
    ASL zASP : ROL zASP+1   ; *8 — zASP:zASP+1 = (k-1)*8
    LDA zASP : CLC : ADC #<as_tab : STA zASP
    LDA zASP+1 : ADC #>as_tab     : STA zASP+1
    RTS

; ============================================================
; 1000 INTERN
!zone intern
intern:
    LDA #1 : STA zAX
.lp:
    ; if zAX > zNA, not found -> allocate
    LDA zNA : CMP zAX : BCC .new   ; NA < AX -> AX > NA -> not found
    ; set zASP = as_tab entry for zAX
    JSR intern_asp
    JSR strcmp
    BEQ .found
    INC zAX : JMP .lp
.found:
    RTS
.new:
    INC zNA
    LDA zNA : STA zAX
    JSR intern_asp          ; zASP = slot for new atom
    ; copy up to 7 bytes + null from zTKP to zASP
    LDY #0
.cp:
    LDA (zTKP),Y : STA (zASP),Y
    BEQ .pad
    INY : CPY #7 : BCC .cp
    LDA #0 : LDY #7 : STA (zASP),Y ; force null at byte 7
    RTS
.pad:
    INY : CPY #8 : BCS .done
    LDA #0 : STA (zASP),Y : JMP .pad
.done:
    RTS

; ============================================================
; 2000 READ_EXPR
!zone readexpr
read_expr:
    JSR skip_ws
    LDX zIX
    LDA in_buf,X : BEQ .nil
    CMP #'(' : BNE .atom
    INC zIX
    JMP read_list

.nil:
    +clr16 zRV : RTS

.atom:
    ; copy token from in_buf[zIX..] into tok_buf, null-terminate
    LDA #<tok_buf : STA zTKP : LDA #>tok_buf : STA zTKP+1
    LDY #0          ; Y = dest index into tok_buf
.scan:
    LDA in_buf,X    ; X = source index into in_buf
    BEQ .tend
    CMP #' '+1 : BCC .tend
    CMP #'(' : BEQ .tend
    CMP #')' : BEQ .tend
    STA tok_buf,Y
    INX : INY : CPY #7 : BCC .scan
.tend:
    LDA #0 : STA tok_buf,Y
    STX zIX         ; advance input past token
    JSR intern
    LDA zAX : STA zRV : LDA #0 : STA zRV+1
    RTS

; ============================================================
; 2100 READ_LIST
!zone readlist
read_list:
    +clr16 zRH : +clr16 zRT
.lp:
    JSR skip_ws
    LDX zIX
    LDA in_buf,X : BNE +
    JMP .end                    ; end of input -> return RH
+:  CMP #')' : BNE +
    JMP .close
+:

    ; push RH, RT on sim stack
    LDX zSP
    LDA zRH : STA s1_lo,X : LDA zRH+1 : STA s1_hi,X
    LDA zRT : STA s2_lo,X : LDA zRT+1 : STA s2_hi,X
    INC zSP

    JSR read_expr               ; -> zRV = element

    +mv16 zRP, zRV

    ; pop RH, RT
    DEC zSP : LDX zSP
    LDA s1_lo,X : STA zRH : LDA s1_hi,X : STA zRH+1
    LDA s2_lo,X : STA zRT : LDA s2_hi,X : STA zRT+1

    ; cons_alloc(RP, 0)
    +mv16 zCC, zRP : +clr16 zDD
    JSR cons_alloc              ; -> zRV = new cell

    ; if RH=0 then RH=RT=RV, else CD[-RT]=RV; RT=RV
    LDA zRH : ORA zRH+1 : BNE .app
    +mv16 zRH, zRV : +mv16 zRT, zRV : JMP .lp
.app:
    ; CD%(-RT%) = RV
    LDA #0 : SEC : SBC zRT : TAX
    LDA zRV : STA cd_lo,X : LDA zRV+1 : STA cd_hi,X
    +mv16 zRT, zRV
    JMP .lp

.close:
    INC zIX
.end:
    +mv16 zRV, zRH : RTS

; ============================================================
; 3000 EVAL
!zone eval
eval_:
    ; 3002: if EE=0, EV=0
    LDA zEE : ORA zEE+1 : BNE +
    +clr16 zEV : RTS

+:  ; 3004: if EE>0 (atom, hi=0), assoc
    LDA zEE+1 : BNE +
    +mv16 zSX, zEE : +mv16 zSA, zEA
    JSR assoc : RTS

+:  ; EE is cons. X = index of EE.
    LDA #0 : SEC : SBC zEE : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1   ; car(EE) → zCC (temp)
    LDA cd_lo,X : STA zEM : LDA cd_hi,X : STA zEM+1   ; cdr(EE) → zEM

    ; 3006: car(EE) == QUOTE?
    LDA zCC+1 : BNE +
    LDA zCC : CMP zKQ : BNE +
    ; EV = CH[-CD[-EE]] = CH[-zEM]
    LDA #0 : SEC : SBC zEM : TAX
    LDA ch_lo,X : STA zEV : LDA ch_hi,X : STA zEV+1
    RTS

+:  ; 3012: car(EE) == COND?
    LDA zCC+1 : BNE +
    LDA zCC : CMP zKC : BNE +
    +mv16 zEC, zEM
    JSR evcon : RTS

+:  ; 3018/3020: function application
    ; Push car(EE) onto sim stack BEFORE evlis — evlis→eval_ will clobber zCC
    LDX zSP
    LDA zCC : STA s1_lo,X : LDA zCC+1 : STA s1_hi,X
    INC zSP
    JSR evlis
    DEC zSP : LDX zSP
    LDA s1_lo,X : STA zAF : LDA s1_hi,X : STA zAF+1   ; AF = saved car(EE)
    +mv16 zAXX, zEV
    +mv16 zAA, zEA
    JSR apply_ : RTS

; ============================================================
; 3100 EVLIS
!zone evlis
evlis:
    +clr16 zEG : +clr16 zES
.lp:
    ; 3105: if EM=0, EV=EG, return
    LDA zEM : ORA zEM+1 : BNE +
    +mv16 zEV, zEG : RTS

+:  ; push EM, EG, ES
    LDX zSP
    LDA zEM : STA s1_lo,X : LDA zEM+1 : STA s1_hi,X
    LDA zEG : STA s2_lo,X : LDA zEG+1 : STA s2_hi,X
    LDA zES : STA s3_lo,X : LDA zES+1 : STA s3_hi,X
    INC zSP

    ; EE = CH[-EM]
    LDA #0 : SEC : SBC zEM : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1
    JSR eval_
    +mv16 zEP, zEV

    ; pop EM, EG, ES
    DEC zSP : LDX zSP
    LDA s1_lo,X : STA zEM : LDA s1_hi,X : STA zEM+1
    LDA s2_lo,X : STA zEG : LDA s2_hi,X : STA zEG+1
    LDA s3_lo,X : STA zES : LDA s3_hi,X : STA zES+1

    ; cons_alloc(EP, 0)
    +mv16 zCC, zEP : +clr16 zDD
    JSR cons_alloc

    ; if EG=0 then EG=ES=RV, else CD[-ES]=RV; ES=RV
    LDA zEG : ORA zEG+1 : BNE .app
    +mv16 zEG, zRV : +mv16 zES, zRV : JMP .next
.app:
    LDA #0 : SEC : SBC zES : TAX
    LDA zRV : STA cd_lo,X : LDA zRV+1 : STA cd_hi,X
    +mv16 zES, zRV
.next:
    ; EM = CD[-EM]
    LDA #0 : SEC : SBC zEM : TAX
    LDA cd_lo,X : STA zEM : LDA cd_hi,X : STA zEM+1
    JMP .lp

; ============================================================
; 3200 EVCON
!zone evcon
evcon:
    ; 3205: if EC>=0, error
    LDA zEC+1 : BNE +
    LDA #<str_econd : STA zTKP : LDA #>str_econd : STA zTKP+1
    LDA #0 : STA zSP : JMP err_str
+:
    ; push EC
    LDX zSP
    LDA zEC : STA s1_lo,X : LDA zEC+1 : STA s1_hi,X
    INC zSP

    ; EE = CH[-CH[-EC]]  (Caar(EC))
    LDA #0 : SEC : SBC zEC : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1   ; zEE = CH[-EC] = car(EC)
    LDA #0 : SEC : SBC zEE : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1   ; zEE = CH[-car(EC)] = caar(EC)
    JSR eval_
    +mv16 zET, zEV

    ; pop EC
    DEC zSP : LDX zSP
    LDA s1_lo,X : STA zEC : LDA s1_hi,X : STA zEC+1

    ; 3225: if ET<>0 then EE=CH[-CD[-CH[-EC]]], eval, return
    LDA zET : ORA zET+1 : BEQ .skip
    ; EE = cadar(EC) = CH[-CD[-CH[-EC]]]
    LDA #0 : SEC : SBC zEC : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1   ; car(EC)
    LDA #0 : SEC : SBC zEE : TAX
    LDA cd_lo,X : STA zEE : LDA cd_hi,X : STA zEE+1   ; cdr(car(EC))
    LDA #0 : SEC : SBC zEE : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1   ; car(cdr(car(EC)))
    JSR eval_ : RTS

.skip:
    ; 3230: EC = CD[-EC]
    LDA #0 : SEC : SBC zEC : TAX
    LDA cd_lo,X : STA zEC : LDA cd_hi,X : STA zEC+1
    JMP evcon

; ============================================================
; 3300 APPLY
!zone apply
apply_:
    ; 3302: if AF<0, lambda
    LDA zAF+1 : BPL +
    JMP apply_lambda
+:

    ; 3305: CONS
    LDA zAF : CMP zKO : BNE +
    ; CC=CH[-AXX], DD=CH[-CD[-AXX]]
    LDA #0 : SEC : SBC zAXX : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1
    LDA cd_lo,X : STA zDD : LDA cd_hi,X : STA zDD+1
    ; DD = CH[-DD] (cadr of arg list)
    LDA #0 : SEC : SBC zDD : TAX
    LDA ch_lo,X : STA zDD : LDA ch_hi,X : STA zDD+1
    JSR cons_alloc : +mv16 zEV, zRV : RTS

+:  ; 3312: EQ
    LDA zAF : CMP zKE : BNE +
    LDA #0 : SEC : SBC zAXX : TAX
    LDA ch_lo,X : STA zDD : LDA ch_hi,X : STA zDD+1   ; car(AXX) in zDD
    LDA cd_lo,X : STA zCC : LDA cd_hi,X : STA zCC+1   ; cdr(AXX)
    LDA #0 : SEC : SBC zCC : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1   ; cadr(AXX) in zCC
    ; EV = (car==cadr) ? KT : 0
    +clr16 zEV
    LDA zDD   : CMP zCC   : BNE .eq_done
    LDA zDD+1 : CMP zCC+1 : BNE .eq_done
    LDA zKT : STA zEV
.eq_done:
    RTS

+:  ; 3320: ATOM
    LDA zAF : CMP zKA : BNE +
    LDA #0 : SEC : SBC zAXX : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1
    +clr16 zEV
    ; ATOM = T if car(AXX) >= 0 (hi byte = 0)
    LDA zCC+1 : BNE .atom_done     ; negative (cons) -> NIL
    LDA zKT : STA zEV
.atom_done:
    RTS

+:  ; 3328: CAR
    LDA zAF : CMP zKR : BNE +
    LDA #0 : SEC : SBC zAXX : TAX      ; index of AXX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1   ; car(AXX)
    LDA #0 : SEC : SBC zCC : TAX
    LDA ch_lo,X : STA zEV : LDA ch_hi,X : STA zEV+1   ; car(car(AXX))
    RTS

+:  ; 3332: CDR
    LDA zAF : CMP zKD : BNE +
    LDA #0 : SEC : SBC zAXX : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1
    LDA #0 : SEC : SBC zCC : TAX
    LDA cd_lo,X : STA zEV : LDA cd_hi,X : STA zEV+1
    RTS

+:  ; 3336: not a builtin — look it up in env (mirrors lisp.bas fix)
    +mv16 zSX, zAF : +mv16 zSA, zAA
    JSR assoc
    +mv16 zAF, zEV
    JMP apply_

; ============================================================
; 3380 APPLY_LAMBDA
!zone applylambda
apply_lambda:
    ; PX = CH[-CD[-AF]]   (car of cdr of lambda = param list)
    LDA #0 : SEC : SBC zAF : TAX
    LDA cd_lo,X : STA zPX : LDA cd_hi,X : STA zPX+1   ; cdr(AF)
    LDA #0 : SEC : SBC zPX : TAX
    LDA ch_lo,X : STA zPX : LDA ch_hi,X : STA zPX+1   ; car(cdr(AF))
    ; PY = AXX
    +mv16 zPY, zAXX
    ; PA = AA
    +mv16 zPA, zAA
    JSR pairlis

    ; push EA, set EA = pairlis result
    LDX zSP
    LDA zEA : STA sk_lo,X : LDA zEA+1 : STA sk_hi,X
    INC zSP
    +mv16 zEA, zEV

    ; EE = CH[-CD[-CD[-AF]]]  (body = caaddr(lambda))
    LDA #0 : SEC : SBC zAF : TAX
    LDA cd_lo,X : STA zEE : LDA cd_hi,X : STA zEE+1   ; cdr(AF)
    LDA #0 : SEC : SBC zEE : TAX
    LDA cd_lo,X : STA zEE : LDA cd_hi,X : STA zEE+1   ; cdr(cdr(AF))
    LDA #0 : SEC : SBC zEE : TAX
    LDA ch_lo,X : STA zEE : LDA ch_hi,X : STA zEE+1   ; car(cdr(cdr(AF)))
    JSR eval_

    ; pop EA
    DEC zSP : LDX zSP
    LDA sk_lo,X : STA zEA : LDA sk_hi,X : STA zEA+1
    RTS

; ============================================================
; 4000 ASSOC
!zone assoc
assoc:
    ; 4005: if SA=0, undefined variable
    LDA zSA : ORA zSA+1 : BNE +
    ; print "?" then atom name
    LDA #'?' : JSR CHROUT
    LDA zSX : STA zAX       ; zAX = atom index
    JSR intern_asp          ; zASP = string for zAX
    +mv16 zTKP, zASP
    JSR err_str             ; prints string, CR, jumps to repl

+:  ; 4010: if CH[-CH[-SA]] = SX then EV = CD[-CH[-SA]]
    LDA #0 : SEC : SBC zSA : TAX
    LDA ch_lo,X : STA zCC : LDA ch_hi,X : STA zCC+1   ; CH[-SA] = car(SA)
    LDA #0 : SEC : SBC zCC : TAX
    LDA ch_lo,X : STA zDD : LDA ch_hi,X : STA zDD+1   ; CH[-car(SA)] = caar(SA)
    ; compare zDD with zSX
    LDA zSX : CMP zDD : BNE .next
    LDA #0  : CMP zDD+1 : BNE .next
    ; found: EV = CD[-CH[-SA]] = cdar(SA)
    LDA #0 : SEC : SBC zCC : TAX
    LDA cd_lo,X : STA zEV : LDA cd_hi,X : STA zEV+1
    RTS

.next:
    ; 4020: SA = CD[-SA]
    LDA #0 : SEC : SBC zSA : TAX
    LDA cd_lo,X : STA zSA : LDA cd_hi,X : STA zSA+1
    JMP assoc

; ============================================================
; 4100 PAIRLIS
!zone pairlis
pairlis:
    +clr16 zRG : +clr16 zRS
.lp:
    ; 4105: if PX=0, done
    LDA zPX : ORA zPX+1 : BEQ +    ; PX=0 → end of params
    JMP .body                        ; PX≠0 → main loop body
+:  ; PX=0: end of params — link tail to parent env
    LDA zRS : ORA zRS+1 : BNE +
    JMP .done                        ; RS=0 → nothing to link
+:  LDA #0 : SEC : SBC zRS : TAX
    LDA zPA : STA cd_lo,X : LDA zPA+1 : STA cd_hi,X
    JMP .done
.body:
    ; 4110: PN=CH[-PX], PV=CH[-PY]
    LDA #0 : SEC : SBC zPX : TAX
    LDA ch_lo,X : STA zPN : LDA ch_hi,X : STA zPN+1
    LDA #0 : SEC : SBC zPY : TAX
    LDA ch_lo,X : STA zPV : LDA ch_hi,X : STA zPV+1

    ; 4115: if PA<>0 and CH[-CH[-PA]]=PN then PA=CD[-PA]
    LDA zPA : ORA zPA+1 : BEQ .noskim
    LDA #0 : SEC : SBC zPA : TAX
    LDA ch_lo,X : STA zPP : LDA ch_hi,X : STA zPP+1   ; CH[-PA]=car(PA)
    LDA #0 : SEC : SBC zPP : TAX
    LDA ch_lo,X : STA zPP : LDA ch_hi,X : STA zPP+1   ; CH[-car(PA)]=caar(PA)
    LDA zPP : CMP zPN : BNE .noskim
    LDA zPP+1 : CMP zPN+1 : BNE .noskim
    ; PA = CD[-PA]
    LDA #0 : SEC : SBC zPA : TAX
    LDA cd_lo,X : STA zPA : LDA cd_hi,X : STA zPA+1
.noskim:
    ; 4120: cons_alloc(PN, PV) -> PP
    +mv16 zCC, zPN : +mv16 zDD, zPV
    JSR cons_alloc : +mv16 zPP, zRV
    ; 4125: cons_alloc(PP, 0)
    +mv16 zCC, zPP : +clr16 zDD
    JSR cons_alloc

    ; 4130: if RG=0, RG=RS=RV, else CD[-RS]=RV; RS=RV
    LDA zRG : ORA zRG+1 : BNE .app
    +mv16 zRG, zRV : +mv16 zRS, zRV : JMP .adv
.app:
    LDA #0 : SEC : SBC zRS : TAX
    LDA zRV : STA cd_lo,X : LDA zRV+1 : STA cd_hi,X
    +mv16 zRS, zRV
.adv:
    ; 4145: PX=CD[-PX], PY=CD[-PY]
    LDA #0 : SEC : SBC zPX : TAX
    LDA cd_lo,X : STA zPX : LDA cd_hi,X : STA zPX+1
    LDA #0 : SEC : SBC zPY : TAX
    LDA cd_lo,X : STA zPY : LDA cd_hi,X : STA zPY+1
    JMP .lp

.done:
    LDA zRG : ORA zRG+1 : BNE +
    +mv16 zEV, zPA : RTS
+:  +mv16 zEV, zRG : RTS

; ============================================================
; 5000 PRINT_OBJ
!zone printobj
print_obj:
    ; 5002: if PO=0, print "NIL"
    LDA zPO : ORA zPO+1 : BNE +
    LDA #'N' : JSR CHROUT
    LDA #'I' : JSR CHROUT
    LDA #'L' : JSR CHROUT : RTS

+:  ; 5004: if PO>0 (atom, hi=0), print atom string
    LDA zPO+1 : BNE +
    LDA zPO : STA zAX
    JSR intern_asp          ; zASP = string for zAX
    LDY #0
.lp:
    LDA (zASP),Y : BEQ .done
    JSR CHROUT : INY : JMP .lp
.done: RTS

+:  ; 5006: cons cell — print list
    LDA #'(' : JSR CHROUT

    ; push PO
    LDX zSP
    LDA zPO : STA s1_lo,X : LDA zPO+1 : STA s1_hi,X
    INC zSP

.list_loop:
    ; 5010: PO = CH[-S1[SP]]
    LDX zSP : DEX
    LDA s1_lo,X : STA zPP : LDA s1_hi,X : STA zPP+1   ; S1[SP] in zPP
    LDA #0 : SEC : SBC zPP : TAX
    LDA ch_lo,X : STA zPO : LDA ch_hi,X : STA zPO+1
    JSR print_obj

    ; 5012: PO = CD[-S1[SP]]
    LDX zSP : DEX
    LDA s1_lo,X : STA zPP : LDA s1_hi,X : STA zPP+1
    LDA #0 : SEC : SBC zPP : TAX
    LDA cd_lo,X : STA zPO : LDA cd_hi,X : STA zPO+1

    ; pop S1
    DEC zSP

    ; 5014: if PO=0, print ")"
    LDA zPO : ORA zPO+1 : BNE +
    LDA #')' : JSR CHROUT : RTS

+:  ; 5016: if PO<0 (cons), print " " and continue list
    LDA zPO+1 : BMI .more
    ; 5018: PO>0 (atom) — print " . atom )"
    LDA #' ' : JSR CHROUT
    LDA #'.' : JSR CHROUT
    LDA #' ' : JSR CHROUT
    JSR print_obj
    LDA #')' : JSR CHROUT : RTS

.more:
    LDA #' ' : JSR CHROUT
    ; push PO, loop
    LDX zSP
    LDA zPO : STA s1_lo,X : LDA zPO+1 : STA s1_hi,X
    INC zSP
    JMP .list_loop

; ============================================================
; 6000 CONS_ALLOC
!zone consalloc
cons_alloc:
    LDA zNC : CMP #255 : BCC +
    LDA #<str_eheap : STA zTKP : LDA #>str_eheap : STA zTKP+1
    LDA #0 : STA zSP : JMP err_str
+:
    INC zNC
    LDX zNC
    LDA zCC   : STA ch_lo,X
    LDA zCC+1 : STA ch_hi,X
    LDA zDD   : STA cd_lo,X
    LDA zDD+1 : STA cd_hi,X
    ; RV = -NC (16-bit: lo = 256-NC, hi = $FF)
    LDA #0 : SEC : SBC zNC : STA zRV
    LDA #$ff : STA zRV+1
    RTS

; ============================================================
; 7000 DUMP
!zone dump
dump:
    ; AS:
    LDA #'A' : JSR CHROUT
    LDA #'S' : JSR CHROUT
    LDA #':' : JSR CHROUT
    LDX #1
.as_lp:
    LDA zNA : BEQ .as_done      ; NA=0, nothing to print
    TXA : CMP zNA : BCC .as_body : BEQ .as_body : BCS .as_done
.as_body:
    ; print " X="
    LDA #' ' : JSR CHROUT
    TXA : JSR print_byte_dec
    LDA #'=' : JSR CHROUT
    ; print atom string for atom X
    STX zAX : JSR intern_asp
    LDY #0
.asn: LDA (zASP),Y : BEQ .asne
    JSR CHROUT : INY : JMP .asn
.asne:
    INX : JMP .as_lp
.as_done:
    LDA #CR : JSR CHROUT

    ; CH:
    LDA #'C' : JSR CHROUT
    LDA #'H' : JSR CHROUT
    LDA #':' : JSR CHROUT
    LDX #1
.ch_lp:
    LDA zNC : BEQ .ch_done
    TXA : CMP zNC : BCC .ch_body : BEQ .ch_body : BCS .ch_done
.ch_body:
    LDA #' ' : JSR CHROUT
    TXA : JSR print_byte_dec
    LDA #'=' : JSR CHROUT
    LDA ch_hi,X : JSR print_byte_dec
    LDA ch_lo,X : JSR print_byte_dec
    INX : JMP .ch_lp
.ch_done:
    LDA #CR : JSR CHROUT

    ; CD:
    LDA #'C' : JSR CHROUT
    LDA #'D' : JSR CHROUT
    LDA #':' : JSR CHROUT
    LDX #1
.cd_lp:
    LDA zNC : BEQ .cd_done
    TXA : CMP zNC : BCC .cd_body : BEQ .cd_body : BCS .cd_done
.cd_body:
    LDA #' ' : JSR CHROUT
    TXA : JSR print_byte_dec
    LDA #'=' : JSR CHROUT
    LDA cd_hi,X : JSR print_byte_dec
    LDA cd_lo,X : JSR print_byte_dec
    INX : JMP .cd_lp
.cd_done:
    LDA #CR : JSR CHROUT
    RTS

!zone printbyte
; print_byte_dec: print A as signed decimal (for dump)
; handles 0, positive (1..127), and negative ($ff=$fe=$80 as -1..-128)
print_byte_dec:
    BEQ .zero
    BPL .pos
    ; negative: print '-' then negate
    PHA
    LDA #'-' : JSR CHROUT
    PLA
    EOR #$ff : CLC : ADC #1     ; negate
    JMP .pos
.zero:
    LDA #'0' : JSR CHROUT : RTS
.pos:
    ; print 1-3 decimal digits for value 1..255
    ; divide by 100, 10, 1
    LDX #0      ; hundreds
.h: CMP #100 : BCC .tens
    SBC #100 : INX : JMP .h
.tens:
    PHA
    CPX #0 : BEQ .skip_h
    TXA : CLC : ADC #'0' : JSR CHROUT
.skip_h:
    PLA
    LDX #0
.t: CMP #10 : BCC .ones
    SBC #10 : INX : JMP .t
.ones:
    PHA
    CPX #0 : BEQ .skip_t
    TXA : CLC : ADC #'0' : JSR CHROUT
.skip_t:
    PLA
    CLC : ADC #'0' : JSR CHROUT
    RTS
