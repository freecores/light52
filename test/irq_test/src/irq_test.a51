; irq_test.a51 -- First interrupt service test.
;
; This progam is only meant to work in the simulation test bench, because it
; requires the external interrupt inputs to be wired to the P1 output port.
; They are in the simulation test bench entity but not in the synthesizable
; demo top entity.
;
; Its purpose is to demonstrate the working of the interrupt service logic. No
; actual tests are performed (other than the co-simulation tests), only checks.
;
;-------------------------------------------------------------------------------

        ; Include the definitions for the light52 derivative
        $nomod51
        $include (light52.mcu)
        
ext_irq_ctr     set     060h        ; Incremented by external irq routine

    
        ;-- Macros -------------------------------------------------------------

        ; putc: send character in A to console (UART)
putc    macro   character
        local   putc_loop
        mov     SBUF,character
putc_loop:
        ;mov     a,SCON
        ;anl     a,#10h
        ;jz      putc_loop
        endm
        
        ; put_crlf: send CR+LF to console
put_crlf macro
        putc    #13
        putc    #10
        endm
    
    
        ;-- Reset & interrupt vectors ------------------------------------------

        org     00h
        ljmp    start               ;
        org     03h
        ljmp    irq_ext
        org     0bh
        ljmp    irq_timer
        org     13h
        ljmp    irq_wrong
        org     1bh
        ljmp    irq_wrong
        org     23h
        ljmp    irq_wrong


        ;-- Main test program --------------------------------------------------
        org     30h
start:

        ; Disable all interrupts.
        mov     IE,#00

        
        ;---- External interrupt test --------------------------------------
        
        ; We'll be asserting the external interrupt request line 0, making
        ; sure the interrupt enable flags work properly. No other interrupt
        ; will be asserted simultaneously or while in the interrupt service
        ; routine.
        
        ; Trigger external IRQ with IRQs disabled, it should be ignored.
        mov     P1,#01h             ; Assert external interrupt line 0...
        nop                         ; ...give the CPU some time to acknowledge
        nop                         ; the interrupt...
        nop
        mov     a,ext_irq_ctr       ; ...and then make sure it hasn't.
        cjne    a,#00,fail_unexpected
        setb    EXTINT0.0           ; Clear external IRQ flag

        ; Trigger timer IRQ with external IRQ enabled but global IE disabled
        mov     IE,#01h             ; Enable external interrupt...
        mov     P1,#01h             ; ...and assert interrupt line.
        nop                         ; Wait a little...
        nop
        nop
        mov     a,ext_irq_ctr       ; ...and make sure the interrupt was NOT
        cjne    a,#00,fail_unexpected   ; serviced.
        setb    EXTINT0.0           ; Clear timer IRQ flag

        ; Trigger external IRQ with external and global IRQ enabled
        mov     P1,#00h             ; Clear the external interrupt line...
        mov     IE,#81h             ; ...before enabling interrupts globally.
        mov     ext_irq_ctr,#00     ; Reset the interrupt counter...
        mov     P1,#01h             ; ...and assert the external interrupt.
        nop                         ; Give it some time to be acknowledged...
        nop
        nop
        mov     a,ext_irq_ctr       ; ...and make sure it has been serviced.
        cjne    a,#01,fail_expected
        setb    EXTINT0.0          ; Clear timer IRQ flag

        ; End of irq test, print message and continue
        mov     DPTR,#text2
        call    puts

        ;---- Timer test ---------------------------------------------------
        ; Assume the prescaler is set for a 20us count period.
        
        ; All we will do here is make sure the counter changes at the right
        ; time, i.e. 20us after being started. We will NOT test the full
        ; functionality of the timer (not in this version of the test).
        
        mov     IE,#000h            ; Disable all interrupts...
                                    ; ...and put timer in
        mov     TSTAT,#00           ; Stop timer...
        mov     TH,#00              ; ...set counter = 0...
        mov     TL,#00              ;
        mov     TCH,#0c3h           ; ...and set Compare register = 50000.
        mov     TCL,#050h           ; (50000 counts = 1 second)
        mov     TSTAT,#030h         ; Start counting.

        ; Ok, now wait for a little less than 20us and make sure TH:TL has not
        ; changed yet.
        mov     r0,#95              ; We need to wait for 950 clock cycles...
loop0:                              ; ...and this is a 10-clock loop
        nop
        djnz    r0,loop0
        mov     a,TH
        cjne    a,#000h,fail_timer_error
        mov     a,TL
        cjne    a,#000h,fail_timer_error
        
        ; Now wait for another 100 clock cycles and make sure TH:TL has already
        ; changed.
        mov     r0,#10              ; We need to wait for 100 clock cycles...
loop1:                              ; ...and this is a 10-clock loop
        nop
        djnz    r0,loop1
        mov     a,TH
        cjne    a,#000h,fail_timer_error
        mov     a,TL
        cjne    a,#001h,fail_timer_error

        ; End of timer test, print message and continue
        mov     DPTR,#text5
        call    puts

        ;-- End of test program, enter single-instruction endless loop
quit:   ajmp    $


fail_timer_error:
        mov     DPTR,#text4
        call    puts
        mov     IE,#00h
        ajmp    $


        ; Did not get expected IRQ: print failure message and block.
fail_expected:
        mov     DPTR,#text3
        call    puts
        mov     IE,#00h
        ajmp    $

        ; Got unexpected IRQ: print failure message and block.
fail_unexpected:
        mov     DPTR,#text1
        call    puts
        mov     IE,#00h
        ajmp    $

        ; End of the test code. Now let's define a few utility routines.

;-- puts: output to UART a zero-terminated string at DPTR ----------------------
puts:
        mov     r0,#00h
puts_loop:
        mov     a,r0
        inc     r0
        movc    a,@a+DPTR
        jz      puts_done

        putc    a
        sjmp    puts_loop
puts_done:
        ret

;-- irq_timer: interrupt routine for timer -------------------------------------
; Note we don't bother to preserve any registers.
irq_ext:
        mov     P1,#00h             ; Remove the external interrupt request
        mov     EXTINT0,#0ffh       ; Clear all external IRQ flags
        inc     ext_irq_ctr         ; Increment irq counter
        mov     DPTR,#text0         ; Print IRQ message...
        call    puts
        reti                        ; ...and quit
        
irq_timer:
irq_wrong:
        ajmp    irq_wrong

        ; End of the utility routines. Define constant data and we're done.

text0:  db      '<External irq>',13,10,00h,00h
text1:  db      'Unexpected IRQ',13,10,00h,00h
text2:  db      'IRQ test finished, no errors',13,10,0
text3:  db      'Missing IRQ',13,10,0
text4:  db      'Timer error',13,10,0
text5:  db      'Timer test finished, no errors',13,10,0
    
        end
