; Prompt the user for input.
; Echo the input string in reverse.
; Repeat.

; Built-in (ROM) subroutines
COUT equ $fded
CROUT equ $fd8e
GETLN equ $fd6a
HOME equ $fc58
; Relevant memory locations
PROMPT equ $33
BUF equ $0200

    org $2000

main
    jsr HOME
    lda #">"
    sta PROMPT
main_loop
    jsr GETLN
    jsr echo_reverse
    jmp main_loop

; inputs: x, BUF
; clobbers: a
echo_reverse
    dex
    cpx FF
    beq echo_reverse_end
    lda BUF,x
    jsr COUT
    jmp echo_reverse
echo_reverse_end
    jsr CROUT
    rts

; inputs: x, BUF
; clobbers: a, y
echo
    ldy #$00
    stx $60
echo_loop
    cpy $60
    beq echo_loop_end

    lda BUF,y
    jsr COUT

    iny
    jmp echo_loop
echo_loop_end

    jsr CROUT
    rts

FF
    hex ff
