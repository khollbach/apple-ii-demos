; Tile the screen with the RC logo, with various artifact colors.

; Built-in (ROM) subroutines
COUT equ $fded
CROUT equ $fd8e
GETLN equ $fd6a
RDKEY equ $fd0c
IOSAVE equ $ff4a
IOREST equ $ff3f
MOVE equ $fe2c
READ equ $fefd
WRITE equ $fecd
WAIT equ $fca8
BELL equ $ff3a
HOME equ $fc58
PRBLNK equ $f948
PRBL2 equ $f94a
PRHEX equ $fde3
PRBYTE equ $fdda
PRNTAX equ $f941
SETINV equ $fe80
SETNORM equ $fe84
; Relevant memory locations
CH equ $24
CV equ $25
INVFLAG equ $32
PROMPT equ $33
A1 equ $3c
A2 equ $3e
A4 equ $42
RNDL equ $4e
RNDH equ $4f
BUF equ $0200
; I/O locations
KBD equ $c000 ; high bit indicates if there's pending input
SPKR equ $c030 ; read to toggle
TEXT_OFF equ $c050
TEXT_ON equ $c051
MIXED_OFF equ $c052
MIXED_ON equ $c053
PAGE2_OFF equ $c054
PAGE2_ON equ $c055
HIRES_OFF equ $c056
HIRES_ON equ $c057

; Global variables.
rng_state equ $fe
flag_bit equ $ff

; This is a terrible hack.
;
; We put a tiny bit of code at $2000, where prodos loads our program into
; memory. This code copies the actual program (`main` through `prog_end`) to
; $6000, and then jumps to it.
;
; Note that merlin32 doesn't put any padding between these two sections. So the
; "bootstrapping" code gets loaded at $2000, and the real program gets loaded at
; like $20ab, before being copied to $6000. But the second `org` command *does*
; ensure that the main code has correct the jump addresses for being loaded and
; run starting at $6000.
    org $2000

    ; dest: $6000
    lda #$00
    sta A4
    lda #$60
    sta A4+1

    ; src: main
    lda #<actual_main
    sta A1
    lda #>actual_main
    sta A1+1

    ; end: prog_end-1
    lda #<actual_prog_end_minus_one
    sta A2
    lda #>actual_prog_end_minus_one
    sta A2+1

    ldy #$00
    jsr MOVE

    jmp $6000

prog_len equ prog_end - main
actual_prog_end equ actual_main + prog_len
actual_prog_end_minus_one equ actual_prog_end - 1

; This is the address of `main` *before* it gets MOVEd to $6000.
actual_main

    org $6000

main
    ; Glitched version (written to Page 2).
    jsr seed_rng
    lda #$20
    sta A2
    jsr tile_screen

    ; Black the screen, so the user can see
    ; the initial screen paint in real time.
    jsr black_screen
    bit HIRES_ON
    bit MIXED_OFF
    bit TEXT_OFF

    ; Clear the input buffer, so the user doesn't accidentally
    ; switch screens before they know what's going on.
    jsr clear_input_buffer

    ; Original version.
    jsr disable_rng
    lda #$00
    sta A2
    jsr tile_screen

    ; Switch back and forth on keypress.
main_loop
    bit PAGE2_OFF
    jsr RDKEY

    bit PAGE2_ON
    jsr RDKEY

    jmp main_loop

; clobbers: a
clear_input_buffer
    lda #$80
clear_buf_loop
    bit KBD
    bpl clear_buf_done
    jsr RDKEY
    jmp clear_buf_loop
clear_buf_done
    rts

; inputs: A2 (#$00 or #$20 for Page1 or Page2)
tile_screen
    ; Set initial flag bits.
    lda #$00
    sta flag_bit
    jsr set_sprite_flag_bits

    ldy #$00
loop_y
    ldx #$00

    ; Every odd line, draw a half-logo at the start of the line,
    ; and then shift the x coord over by 1.
    tya
    bit #$02
    beq loop_x
    jsr set_sprite_flag_bits
    jsr draw_half_logo
    jsr set_sprite_flag_bits
    ldx #$01

loop_x
    jsr draw_sprite
    jsr set_sprite_flag_bits

    inx
    inx
    cpx #$28-1
    bmi loop_x

    ; On odd lines, draw the other half-logo at the end of the line.
    tya
    bit #$02
    beq inc_y
    jsr set_sprite_flag_bits
    jsr draw_other_half_logo
    jsr set_sprite_flag_bits

inc_y
    iny
    iny
    cpy #$18
    bmi loop_y

    rts

; inputs: x in 0..=38, y in 0..=22 (decimal)
;   A2 (#$00 or #$20 for Page1 or Page2)
; clobbers nothing
draw_sprite
    ; Draw the quadrants in clockwise order.

    lda #<top_left
    sta A1
    lda #>top_left
    sta A1+1
    jsr draw_quadrant

    inx
    lda #<top_right
    sta A1
    lda #>top_right
    sta A1+1
    jsr draw_quadrant

    iny
    lda #<bottom_right
    sta A1
    lda #>bottom_right
    sta A1+1
    jsr draw_quadrant

    dex
    lda #<bottom_left
    sta A1
    lda #>bottom_left
    sta A1+1
    jsr draw_quadrant

    dey
    rts

; inputs: y in 0..=22 (decimal)
;   A2 (#$00 or #$20 for Page1 or Page2)
; clobbers: x
draw_half_logo
    ldx #$00
    lda #<top_right
    sta A1
    lda #>top_right
    sta A1+1
    jsr draw_quadrant

    iny
    lda #<bottom_right
    sta A1
    lda #>bottom_right
    sta A1+1
    jsr draw_quadrant

    dey
    rts

; inputs: y in 0..=22 (decimal)
;   A2 (#$00 or #$20 for Page1 or Page2)
; clobbers: x
draw_other_half_logo
    ldx #$28-1
    lda #<top_left
    sta A1
    lda #>top_left
    sta A1+1
    jsr draw_quadrant

    iny
    lda #<bottom_left
    sta A1
    lda #>bottom_left
    sta A1+1
    jsr draw_quadrant

    dey
    rts

; inputs: x in 0..40, y in 0..24
;   A1 pointing to sprite data
;   A2 (#$00 or #$20 for Page1 or Page2)
; clobbers nothing
draw_quadrant
    tya
    pha

    jsr base_addr

    ldy #$00
draw_pixel_rows
    lda (A1),y
    sta (A4)

    lda A4+1
    adc #$04
    sta A4+1

    iny
    cpy #$08
    bne draw_pixel_rows

    pla
    tay
    rts

; inputs: x, y
;   A2 (#$00 or #$20 for Page1 or Page2)
; clobbers: a
; output: A4
base_addr
    ; Which band? (0, 1, or 2)
    tya
    lsr a ; shift right three times (i.e. divide by 8)
    lsr a
    lsr a
    sta $60

    ; Which block within the band? (0..=7)
    tya
    and #$08-1 ; keep lowest three bits (i.e. y modulo 8)
    sta $61

    ; Compute band offset; store in $60.
    ; Multiplication is done by iterated addition.
    lda #$00
    clc
band_offset_loop
    dec $60
    bmi band_offset_loop_end
    adc #$28
    jmp band_offset_loop
band_offset_loop_end
    sta $60

    ; Compute block offset; store in $61,$62.
    ; Multiplying by $80 is kind of like dividing by 2.
    lda $61
    ror a ; carry input is still clear from above
    sta $62
    ; "underflow" the carry output into the low byte
    lda #$00
    ror a
    sta $61

    ; base_addr := $2000 + band_offset + block_offset + x
    ; low byte (which can't overflow in this case)
    lda $60
    adc $61
    stx $60
    adc $60
    sta A4
    ; high byte
    lda #$20
    adc $62
    adc A2 ; Optionally +$2000 for Page 2.
    sta A4+1

    rts

; Set the sprite flag bits according to the value in flag_bit.
;
; But if the RNG was *seeded* (with a non-zero value), then
; instead scramble the sprite's flag bits.
;
; inputs: flag_bit (should be either $00 or $80); rng state
; clobbers: $60,61
; outputs: toggles flag_bit if RNG is disabled
set_sprite_flag_bits
    jsr IOSAVE

    lda #<sprite
    sta $60
    lda #>sprite
    sta $61

    ldy #$00
    ldx #$20
ssfb_loop
    ; Flip a coin if the RNG was seeded; else do nothing.
    jsr rng_next
    and #$80
    eor flag_bit
    sta flag_bit

    ; Set flag bit.
    lda ($60),y
    and #$7f
    ora flag_bit
    sta ($60),y

    clc
    lda #$01
    adc $60
    sta $60
    lda #$00
    adc $61
    sta $61

    dex
    bne ssfb_loop

    ; Toggle.
    lda flag_bit
    eor #$80
    sta flag_bit

    jsr IOREST
    rts

; clobbers: a
seed_rng
    lda #$ab ; Use a fixed seed of $ab.
    sta rng_state
    rts

; Seed the RNG with zero, after which it will keep emitting zeros.
; clobbers: a
disable_rng
    lda #$00
    sta rng_state
    rts

; naive xorshift rng, from:
; https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng
;
; Note: if the seed is zero, it will only generate more zeros.
; 
; inputs: rng_state
; outputs: a
rng_next
    lda rng_state
    asl
    bcc no_eor
    eor #$1d
no_eor
    sta rng_state
    rts

; clobbers: a
black_screen
    lda #$00
    sta $2000
    sta $2001
    jsr fill_screen
    rts

; clobbers nothing
fill_screen
    ; dest: $2002
    lda #$02
    sta A4
    lda #$20
    sta A4+1

    ; src: $2000
    lda #$00
    sta A1
    lda #$20
    sta A1+1

    ; end: $3ffd
    lda #$fd
    sta A2
    lda #$3f
    sta A2+1

    jsr IOSAVE
    jsr IOREST
    ldy #$00
    jsr MOVE
    jsr IOREST
    rts

; Note that the bits are "reversed" in the sprite data. This is because the
; constant values are written down in msb-first order, but the Apple II display
; memory mapping uses lsb-first order.
sprite
top_left
    dfb %0_1111110
    dfb %0_0000010
    dfb %0_1111010
    dfb %0_1010010
    dfb %0_1111010
    dfb %0_1001010
    dfb %0_1111010
    dfb %0_1111010

top_right
    dfb %0_0111111
    dfb %0_0100000
    dfb %0_0101111
    dfb %0_0101110
    dfb %0_0101111
    dfb %0_0101100
    dfb %0_0101111
    dfb %0_0101111

bottom_left
    dfb %0_0000010
    dfb %0_1111110
    dfb %0_1100000
    dfb %0_1111100
    dfb %0_0101110
    dfb %0_1010110
    dfb %0_1111110
    dfb %0_0000000

bottom_right
    dfb %0_0100000
    dfb %0_0111111
    dfb %0_0000011
    dfb %0_0011111
    dfb %0_0110101
    dfb %0_0111010
    dfb %0_0111111
    dfb %0_0000000

prog_end
