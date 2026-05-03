; lines.asm - read two lines, print them joined with +
; Build: acme --cpu 6502 --format cbm --outfile lines.prg lines.asm
; Run:   x64sc lines.prg  (or LOAD "lines.prg",8,1 then RUN)

CHROUT  = $ffd2
CHRIN   = $ffcf
CR      = 13

buf1    = $0900         ; 64-byte input buffer 1
buf2    = $0940         ; 64-byte input buffer 2

!to "lines.prg", cbm
* = $0801

; BASIC stub: 10 SYS 2061
!byte $0b,$08, $0a,$00, $9e, $32,$30,$36,$31, $00, $00,$00

* = $080d               ; 2061 decimal

main:

; --- prompt and read line 1 ---
    lda #'1'
    jsr CHROUT
    lda #'?'
    jsr CHROUT
    lda #' '
    jsr CHROUT
    ldx #0
read1:
    jsr CHRIN
    cmp #CR
    beq done1
    sta buf1,x
    inx
    bne read1
done1:
    lda #0
    sta buf1,x

; --- prompt and read line 2 ---
    lda #'2'
    jsr CHROUT
    lda #'?'
    jsr CHROUT
    lda #' '
    jsr CHROUT
    ldx #0
read2:
    jsr CHRIN
    cmp #CR
    beq done2
    sta buf2,x
    inx
    bne read2
done2:
    lda #0
    sta buf2,x

; --- print buf1+buf2 ---
    ldx #0
print1:
    lda buf1,x
    beq sep
    jsr CHROUT
    inx
    bne print1
sep:
    lda #'+'
    jsr CHROUT
    ldx #0
print2:
    lda buf2,x
    beq newline
    jsr CHROUT
    inx
    bne print2
newline:
    lda #CR
    jsr CHROUT
    jmp main
