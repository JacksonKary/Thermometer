### Begin with functions/executable code in the assmebly file via '.text' directive

.text
.global  set_temp_from_ports
        
## ENTRY POINT FOR REQUIRED FUNCTION
set_temp_from_ports:
        ## Parameter in C code: temp_t *temp
        ## rdi = temp_t *temp         

        ## assembly instructions here
        # BLOCK A - checks if values are in range
        movw    THERMO_SENSOR_PORT(%rip), %dx    # register dx, aka Arg 3 = value from THERMO_SENSOR_PORT
        cmpw    $0, %dx                          # compare THERMO_SENSOR_PORT with 0 (min temp)
        jl      .OUT_OF_RANGE                    # if THERMO_SENSOR_PORT < 0 then jump to .OUT_OF_RANGE
        cmpw    $28800, %dx                      # compare THERMO_SENSOR_PORT with 28800 (max temp)
        jg      .OUT_OF_RANGE                    # if THERMO_SENSOR_PORT > 28800 then jump to .OUT_OF_RANGE

        movb    THERMO_STATUS_PORT(%rip), %cl    # register cl, aka Arg 4 = value from THERMO_STATUS_PORT
        movb    $1, %r8b                         # register r8b, aka Arg 5 = 1 = 0000 0001
        shlb    $2, %r8b                         # r8b << 2 -> r8b = 4 = 0000 0100 -> serves as a mask for the error bit in status_port
        andb    %cl, %r8b                        # r8b = 0000 0100 & cl -> either 0000 0000 for non-error state or 0000 0100 for error-state
    #   shrb    $2, %r8b                         # would set r8b back to 1 -> that's how it was checked as a boolean in "(THERMO_STATUS_PORT & (1 << 2)) >> 2)"... 
                                                 # but is useless in assembly since we can just compare it with 0000 0100 right away
        cmpb    $4, %r8b                         # compare r8b with 0000 0100... if error then r8b = 0000 0100 = 4, else r8b = 0000 0000 = 0
        je      .OUT_OF_RANGE                    # if r8b = 4 then error -> jump to .OUT_OF_RANGE

        # BLOCK B - sets temp fields and rounds to nearest tenth of a degree celsius
        movw    $0, %dx
        movw    THERMO_SENSOR_PORT(%rip), %dx    # register dx, aka Arg 3 = THERMO_SENSOR_PORT
        shrw    $5, %dx                          # dx = THERMO_SENSOR_PORT / 32
        movw    %dx, 0(%rdi)                     # temp->tenths_degrees = dx = THERMO_SENSOR_PORT / 32
        subw    $450, 0(%rdi)                    # temp->tenths_degrees -= 450

                                                 # now check whether we need to round   
                                                 # (THERMO_STATUS_PORT << 11) >> 11 = THERMO_STATUS_PORT % 32        
        movw    THERMO_SENSOR_PORT(%rip), %r8w   # register r8w, aka Arg 5 = THERMO_SENSOR_PORT                       
        shlw    $11, %r8w                        # r8w = r8w << 11 -> r8w = (r8w % 32) * 32
        shrw    $11, %r8w                        # r8w = r8w >> 11 -> r8w = r8w % 32
        cmpw    $15, %r8w                        # compare r8w with 15
        jg      .ROUND_UP                        # if r8w > 15, jump to .ROUND_UP
                                                 # I decided it was better to round up after setting temp->tenths_degrees...
                                                 # it eliminates redundancy from my C code and goes well with the flat computation style of assembly
.CONTINUE:
        movb    $1, 2(%rdi)                      # temp->mode = 1 -> set mode field to Celcius...
                                                 # ^^^(will get overridden if THERMO_STATUS_PORT indicates temp is in degrees Fahrenheit)

        # BLOCK C - converts to fahrenheit if needed
    #   movb    THERMO_STATUS_PORT(%rip), %cl    # register cl, aka Arg 4 = THERMO_STATUS_PORT        -> unneeded, already assigned in BLOCK A
        movb    $1, %r8b                         # register r8b, aka Arg 5 = 1 = 0000 0001
        shlb    $5, %r8b                         # r8b << 5 -> r8b = 32 = 0010 0000 -> serves as a mask for the temperature mode bit (0 for C or 1 for F)
        andb    THERMO_STATUS_PORT(%rip), %r8b   # r8b = 0010 0000 & THERMO_STATUS_PORT -> either 0000 0000 for Celsius or 0010 0000 for Fahrenheit
        cmpb    $32, %r8b                        # compare r8b with 0010 0000... if Fahrenheit then r8b = 0010 0000 = 32, else r8b = 0000 0000 = 0
        je      .FAHRENHEIT_MODE                 # if r8b = 32, jump to .FAHRENHEIT_MODE
.ENDD:
        # RETURN
        movl    $0, %eax                         # return 0; return indicates no errors
        ret                                      # eventually return from the function

.FAHRENHEIT_MODE:                                # jump here to convert to degrees Fahrenheit (if 5th bit of THERMO_STATUS_PORT = 1)
        
        movw    0(%rdi), %r9w                    # register r9w, aka Arg 6 = temp->tenths_degrees
        imulw   $9, %r9w                         # r9w = r9w * 9
        # prepare for division
        movq    $0, %rax                         # set rax to all 0's
        movq    $0, %rdx                         # set rdx to all 0's
        movw    %r9w, %ax                        # set ax to short r9w
        cwtl                                     # "convert word to long" sign extend ax to eax
        cltq                                     # "convert long to quad" sign extend eax to rax
        cqto                                     # sign extend rax to rdx
        movq    $5, %rcx                         # set rcx to long 5
        idivq   %rcx                             # divide combined rax/rdx register by 5
                                                 # rax = quotient           rdx = remainder
        addq    $320, %rax                       # rax += 320
                                                 # rax = (THERMO_SENSOR_PORT * 9) integer divided by 5, + 320
        movw    %ax, 0(%rdi)                     # temp->tenths_degrees = rax
        movb    $2, 2(%rdi)                      # temp->mode = 2 -> set mode field to Fahrenheit (overrides earlier state of temp->mode = 1 [Celsius])
        jmp     .ENDD                             # everything is set, jump to return/end      

.ROUND_UP:                                       # jump here if THERMO_SENSOR_PORT % 32 > 15
        incw    0(%rdi)                          # increments temp->tenths_degrees (rounds temp->tenths_degrees up by 1)    
        movl    $0, %eax                         # set return register to 0
        jmp     .CONTINUE                        # jump back after rounding up

.OUT_OF_RANGE:                                   # jump here if initial if statements are failed -> return error
        movw    $0, 0(%rdi)                      # set temp->tenths_degrees = 0; 
        movb    $3, 2(%rdi)                      # set temp->temp_mode = 3; // set mode to error
        movl    $1, %eax                         # return 1; // return indicates error
                                                 # set return register to 1 to indicate that set_temp_from_ports failed/ sensor reads invalid value
        ret                                      # eventually return from the function

### Change to definine semi-global variables used with the next function 
### via the '.data' directive
.data
special_const:
        .int 17                                  # constant to access temp.temp_mode
display_error:
        .int 0b00000110111101111110111110000000  # bits to display error
blank:
        .int 0b0000000                           # "blank"    
negative: 
        .int 0b0000100                           # "negative"
num_array:                                       # num_array [zero, one, two, three, four, five, six, seven, eight, nine] 
        .int 0b1111011                           # "zero" num_array[0]
        .int 0b1001000                           # "one" num_array[1]
        .int 0b0111101                           # "two" num_array[2]
        .int 0b1101101                           # "three" num_array[3]
        .int 0b1001110                           # "four" num_array[4]
        .int 0b1100111                           # "five" num_array[5]
        .int 0b1110111                           # "six" num_array[6]
        .int 0b1001001                           # "seven" num_array[7]
        .int 0b1111111                           # "eight" num_array[8]
        .int 0b1101111                           # "nine" num_array[9]

### Change back to defining functions/execurable instructions
.text
.global  set_display_from_temp

## ENTRY POINT FOR REQUIRED FUNCTION
set_display_from_temp:  
        ## Parameters in C: temp_t temp, int *display
        ## rdi = temp_t temp
        ## rsi = int *display
        ## assembly instructions here

        movl    $0, (%rsi)                       # clear out display/fill display int with 0's
        movq    %rdi, %rcx                       # rcx = rdi   (move temp into rcx)
        sarq    $16, %rcx                        # rcx >> 16,   cl = temp.temp_mode

        cmpb    $1, %cl                          # compare temp.temp_mode with 1 to check Celsius
        je      .CELSIUS                         # jump to .CELSIUS, skips over error
        cmpb    $2, %cl                          # compare temp.temp_mode with 2 to check Fahrenheit
        je      .FAHRENHEIT                      # jump to .FAHRENHEIT, skips over error

.ERROR:                                          # only called when temp.temp_mode != 1 or 2, jumped over otherwise
        movl    display_error(%rip), %r11d       # r11d = error bit sequence
        movl    %r11d, (%rsi)                    # set display bits to show error 
        movl    $1, %eax                         # return 1; // return indicates error
        ret                                      # return from function early with error

.CELSIUS: 
        cmpw    $450, %di                        # compare temp.tenths_degrees with 450
        jg      .ERROR                           # jump to .ERROR, temperature out of bounds (temp.tenths_degrees > 450)
        cmpw    $-450, %di                       # compare temp.tenths_degrees with -450
        jl      .ERROR                           # jump to .ERROR, temperature out of bounds (temp.tenths_degrees < -450)
        movl    $0b01, (%rsi)                    # sets display bits to indicate Celsius 
        jmp     .PREPARE_CALCULATIONS            # jump to .PREPARE_CALCULATIONS

.FAHRENHEIT:
        cmpw    $1130, %di                       # compare temp.tenths_degrees with 1130
        jg      .ERROR                           # jump to .ERROR, temperature out of bounds (temp.tenths_degrees > 1130)
        cmpw    $-490, %di                       # compare temp.tenths_degrees with -490
        jl      .ERROR                           # jump to .ERROR, temperature out of bounds (temp.tenths_degrees < -490)
        movl    $0b10, (%rsi)                    # sets display bits to indicate Celsius 
        jmp     .PREPARE_CALCULATIONS            # jump to .PREPARE_CALCULATIONS

.NEG_TO_POS:
        NEG     %cl                              # cl = -cl,  (used to make cl positive if initially negative) jumped over unless jumped to by .PREPARE_CALCULATIONS
        jmp     .CALCULATE_DISPLAY_DIGITS        # jump to .CALCULATE_DISPLAY_DIGITS

.PREPARE_CALCULATIONS:                           # checks if temp.tenths_degrees is negative
        movw    %di, %cx                         # cx = temp.tenths_degrees
        cmpw    $0, %cx                          # compare temp.tenths_degrees with 0
        jl      .NEG_TO_POS                      # jump to .NEG_TO_POS to change cl to be positive for calculations

.CALCULATE_DISPLAY_DIGITS:                       # calculates digits for (tenths, ones, tens, hundreds) then store them in registers (r11, r10, r9, r8), respectfully
                                                 # prepare for division
        movq    $0, %rax                         # clear return register rax for division               
        movq    $0, %rdx                         # clear Arg 3 rdx for division
        movw    %cx, %ax                         # ax = short cx, where cx = (abs value of temp.tenths_degrees)
        cwtl                                     # "convert word to long" sign extend ax to eax
        cltq                                     # "convert long to quad" sign extend eax to rax
        cqto                                     # sign extend rax to rdx
        movq    $10, %rcx                        # move divisor (10) to rcx
        idivq   %rcx                             # integer divide, rax = quotient, rdx = remainder
        movq    %rdx, %r11                       # tenths place set in 64 bit register, (r11 = tenths)        
        movw    %ax, %cx                         # cx = quotient
                                                 # tenths place set, move on to ones place

                                                 # prepare for division
        movq    $0, %rax                         # clear return register rax for division               
        movq    $0, %rdx                         # clear Arg 3 rdx for division
        movw    %cx, %ax                         # ax = short cx, where cx = (previous quotient)
        cwtl                                     # "convert word to long" sign extend ax to eax
        cltq                                     # "convert long to quad" sign extend eax to rax
        cqto                                     # sign extend rax to rdx
        movq    $10, %rcx                        # move divisor (10) to rcx
        idivq   %rcx                             # integer divide, rax = quotient, rdx = remainder
        movq    %rdx, %r10                       # ones place set in 64 bit register, (r10 = ones)        
        movw    %ax, %cx                         # cx = quotient
                                                 # ones place set, move on to tens place

                                                 # prepare for division
        movq    $0, %rax                         # clear return register rax for division               
        movq    $0, %rdx                         # clear Arg 3 rdx for division
        movw    %cx, %ax                         # ax = short cx, where cx = (previous quotient)
        cwtl                                     # "convert word to long" sign extend ax to eax
        cltq                                     # "convert long to quad" sign extend eax to rax
        cqto                                     # sign extend rax to rdx
        movq    $10, %rcx                        # move divisor (10) to rcx
        idivq   %rcx                             # integer divide, rax = quotient, rdx = remainder
        movq    %rdx, %r9                        # tens place set in 64 bit register, (r9 = tens)        
        movw    %ax, %cx                         # cx = quotient
                                                 # tens place set, move on to hundreds place

                                                 # prepare for division
        movq    $0, %rax                         # clear return register rax for division               
        movq    $0, %rdx                         # clear Arg 3 rdx for division
        movw    %cx, %ax                         # ax = short cx, where cx = (previous quotient)
        cwtl                                     # "convert word to long" sign extend ax to eax
        cltq                                     # "convert long to quad" sign extend eax to rax
        cqto                                     # sign extend rax to rdx
        movq    $10, %rcx                        # move divisor (10) to rcx
        idivq   %rcx                             # integer divide, rax = quotient, rdx = remainder
        movq    %rdx, %r8                        # hundreds place set in 64 bit register, (r8 = hundreds)        
        movw    %ax, %cx                         # cx = quotient (ideally should be empty)

.SET_BITS:                                       # sets display bits --continues from previous line (section name added for readability)
        leaq    num_array(%rip), %rdx            # rdx = pointer to beginning of num_array       
        movq    %r8, %rcx                        # rcx = r8, move the hundreds digit into rcx
        cmpq    $0, %rcx                         # compare 0 with hundreds digit
        jg      .SET_HUNDREDS                    # if hundreds > 0, then print out the digit
.HUNDREDS_ELSE:                                  # continue through from earlier (ELSE IF)
        cmpw    $0, %di                          # compare 0 with temp.tenths_degrees
        jl      .SECOND_CONDITION                # jump to .SECOND_CONDITION if temp.tenths_degrees < 0 
                                                 # first condition of elseif not met... move on to ELSE
//      movl    blank(%rip), %ecx                # ecx = blank int = 0b0000000      - UNNECCESARY, JUST SHIFT AND 7 ZEROS FILL IN
        shll    $7, (%rsi)                       # int display << 7 (all zeros fill in which represents a blank display digit)       

.SET_BITS_TENS:                                  # hundreds bits now set in every case, time to set tens bits
                                                 ## if(temp_tens == 0 && temp_hundreds > 0)
        movq    %r9, %rcx                        # rcx = r9 = tens digit
        cmpq    $0, %rcx                         # compare 0 with tens
        je      .SECOND_CONDITION_TENS           # jump to .SECOND_CONDITION_TENS
                                                 # first condition of the if failed ande every if case involved tens = 0, so just add tens != 0 to display int
        movq    %r9, %rcx                        # rcx = r9, move the tens digit into rcx
        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r9]
        shll    $7, (%rsi)                       # int display << 7 (makes room for new display bit bundle)
        orl     %ecx, (%rsi)                     # essentially copies the 7 bits of ecx into display int
                                                 # display now has (01 or 10), 7 bits for hundreds, and 7 bits for tens place

.SET_BITS_ONES:                                  # tens bits now set in every case, time to set ones bits
        cmpq    $0, %r10                         # compare 0 with ones (r10)
        jg      .ONES_NON_ZERO                   # jump to .ONES_NON_ZERO to set the display ints to ones since ones > 0
                                                 # ELSE, ones = 0
        cmpq    $0, %r8                          # compare 0 with hundreds (r8)
        je      .NEG_OR_BLANK                    # jump to .NEG_OR_BLANK to determine which path it should go down
        jg      .ONES_ZERO                       # jump to .ONES_ZERO to set ones digit in display to zero

.SET_BITS_TENTHS:                                # set the final 7 bits of display, aka the tenths digit        
        cmpq    $0, %r11                         # compare 0 with tenths (r11)
        jge     .SET_TENTHS                      # jump to .SET_TENTHS to set the display bits
        jmp     .END                             # all of display int's bits are set, return
.END:
        movl    $0, %eax                         # return 0; indicates success
        ret                                      # eventually return from the function

.ONES_ZERO:                                      # ones is zero in all other cases
        movq    %r10, %rcx                       # rcx = r10, move the ones digit into rcx
        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r10]
        shll    $7, (%rsi)                       # int display << 7 (makes room for new display bit bundle)
        orl     %ecx, (%rsi)                     # essentially copies the 7 bits of ecx into display int
                                                 # display now has (01 or 10), 7 bits for hundreds, 7 bits for tens, and 7 bits for the ones place

.NEGATIVE:
        shll    $7, (%rsi)                       # int display << 7 (makes room for negative's bits)
        movl    negative(%rip), %ecx             # ecx = negative,   moves negative int's bits into ecx
        orl     %ecx, (%rsi)                     # copies negative's bits into display int so a negative symbol is displayed in the ones place
        jmp     .SET_BITS_TENTHS                 # jump to .SET_BITS_TENTHS as ones bit is set, continue to set the tenths place

.NEG_OR_BLANK:                                   # determine between two elseif statements from C code
        cmpq    $0, %r11                         # compare 0 with tenths (r11)
        jg      .NEGATIVE                        # jump to .NEGATIVE to put negative symbol in ones place
                                                 # ELSE, only else case here is blank
        shll    $7, (%rsi)                       # int display << 7 (all zeros shifted in to represent blank)
        orl     %ecx, (%rsi)                     # copies 7 zero bits into display int so a blank is displayed in the ones place
        jmp     .SET_BITS_TENTHS                 # jump to .SET_BITS_TENTHS as ones bit is set, continue to set the tenths place

.SET_TENTHS:                                     # set tenths digit in the display int in all cases
        movq    %r11, %rcx                       # rcx = r11, move the tenths digit into rcx
        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r11]
        shll    $7, (%rsi)                       # int display << 7 (makes room for new display bit bundle)
        orl     %ecx, (%rsi)                     # essentially copies the 7 bits of ecx into display int
                                                 # display now has (01 or 10), 7 bits for hundreds, and 7 bits for tens, 7 bits forones, and 7 bits for the tenths place
        jmp     .END                             # jump to END, everything is set

.ONES_NON_ZERO:                                  # ones > 0
        movq    %r10, %rcx                       # rcx = r10, move the ones digit into rcx
        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r10]
        shll    $7, (%rsi)                       # int display << 7 (makes room for new display bit bundle)
        orl     %ecx, (%rsi)                     # essentially copies the 7 bits of ecx into display int
                                                 # display now has (01 or 10), 7 bits for hundreds, 7 bits for tens, and 7 bits for the ones place
        jmp     .SET_BITS_TENTHS                 # jump to .SET_BITS_TENTHS to set the final 7 bits of display

.SET_HUNDREDS:
        shll    $7, (%rsi)                       # int display << 7 (makes room for new display bit bundle)
        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r8]
        orl     %ecx, (%rsi)                     # essentially copies the 7 bits of ecx into display int
                                                 # display currently has (01 for C or 10 for F and the 7 bits of the hundreds place)
        jmp    .SET_BITS_TENS                    # jump to .SET_BITS_TENS hundreds bit set, continue to set the next 7 

.SECOND_CONDITION:                               # first part of elseif statement satisfied, check second condition
        cmpq    $0, %r9                          # compare tens digit with 0
        jne     .BOTH_COONDITIONS_MET            # jump to .BOTH_CONDITIONS_MET since both conditions of the elseif were met

                                                 # ELSE
//      movl    blank(%rip), %ecx                # ecx = blank int = 0b0000000      - UNNECCESARY, JUST SHIFT AND 7 ZEROS FILL IN
        shll    $7, (%rsi)                       # int display << 7 (all zeros fill in which represents a blank display digit)
        jmp     .SET_BITS_TENS                   # jump to .SET_BITS_TENS as hundreds bit has been set in all cases, continue to set the tens place

.BOTH_COONDITIONS_MET:                           # else if(temp.tenths_degrees < 0 && temp_tens != 0){ // put negative symbol if there's no hundreds place and if negative temp
        shll    $7, (%rsi)                       # int display << 7 (makes room for negative's bits)
        movl    negative(%rip), %ecx             # ecx = negative,   moves negative int's bits into ecx
        orl     %ecx, (%rsi)                     # copies negative's bits into display int so a negative symbol is displayed in the hundreds place
        jmp     .SET_BITS_TENS                   # jump to .SET_BITS_TENS as hundreds bit is set, continue to set the tens place

.TENS_BLANK:                                     # sets tens display digit to blank
        shll    $7, (%rsi)                       # int display << 7 (all zeros fill in which represetns a blank display digit)
        jmp     .SET_BITS_ONES                   # jump to .SET_BITS_ONES, tens place display digit set

.TENS_NEGATIVE:                                  # if tens display digit should be "-" negative symbol
        shll    $7, (%rsi)                       # int display << 7 (makes room for 7 bits of int "negative")
        movl    negative(%rip), %ecx             # ecx = negative, moves negative int's bits into ecx
        orl     %ecx, (%rsi)                     # copies negative's bits into display int so a negative symbol is displayed in the tens place
        jmp     .SET_BITS_ONES                   # jump to .SET_BITS_ONES, tens place display digit set

.TENS_ELSE:                                      # first if statement failed, check the first else if
                                                 ## temp.tenths_degrees < 0 && temp_tens == 0 && temp_hundreds == 0 && temp_ones != 0
        cmpq    $0, %r10                         # compare 0 with ones digit
        je      .TENS_BLANK                      # jump to .TENS_BLANK because it's the only tens condition requiring ones = 0
                                                 # by now, hundreds = 0, tens = 0, ones != 0, check for temp.tenths_degrees < 0
        cmpw    $0, %di                          # compare 0 with temp.tenths_degrees
        jl      .TENS_NEGATIVE                   # jump to .TENS_NEGATIVE because every condition has been met for that
                                                 # every case besides tens != 0 has been satisfied, finish as an else case

.SECOND_CONDITION_TENS:
        cmpq    $0, %r8                          # compare 0 with hundreds
        jg      .BOTH_CONDITIONS_MET_TENS          # if both conditions met, jump to .BOTH_CONDITIONS_MET_TENS    
                                                 # ELSE
        je      .TENS_ELSE                         # jump to TENS_ELSE because tens = 0 and hundreds = 0

.BOTH_CONDITIONS_MET_TENS:                       # if temp_tens == 0 && temp_hundreds > 0
        shll    $7, (%rsi)                       # int display << 7 (creates room for next 7 bits)

        movl    (%rdx,%rcx,4), %ecx              # ecx = num_array[r9]
        orl     %ecx, (%rsi)                     # copies r9 bits (which should be 0 in this case) into display's freshly shifted 7 bits
        jmp     .SET_BITS_ONES                   # jump to .SET_BITS_ONES (tens digit bits are set, move on to ones digit)

.text
.global thermo_update
        
## ENTRY POINT FOR REQUIRED FUNCTION
thermo_update:                           
        subq    $24, %rsp                           # expand stack by 24 bits 
        
        movl    $0, 4(%rsp)                         # add 32 bits of 0 to stack pointer starting at byte 4
        leaq    4(%rsp), %rdi                       # arg 1, rdi points 4 bytes above rsp   
        call    set_temp_from_ports                 # call function, return value in eax
                                                    
        movl    %eax, %r15d                         # move return val to %r15d, a callee register to preserve it over second function call
  
        movl    $0, (%rsp)                          # add 4 bytes(32 bits) of 0 to stack pointer starting at byte 0
        movq    %rsp, %rsi                          # arg 1 = temp_t (4 bytes of 0 currently)
        movl    4(%rsp), %edi                       # arg 2 = display int (4 bytes of 0 currently)      
        call    set_display_from_temp               # return value in eax    

        cmpl    $1, %eax                            # if >0, jump to failure
        je      .FAILURE                            # return of >0 = failure
        cmpl    $1, %r15d                           # compare return with 0
        je      .FAILURE                            # return of >0 = failure
                                                    ## else-success
        
        movl    (%rsp), %ecx                        # ecx = entire stack pointer (32 bits 8 bytes))   
        movl    %ecx, THERMO_DISPLAY_PORT(%rip)     # set DISPLAY_PORT bits



        jmp     .END_TWO                            # jump over failure to celebrate finishing part 1 

.FAILURE:                                           # one or more of the functions returned 1
        movl    $116912000, THERMO_DISPLAY_PORT(%rip) # move error bits into DISPLAY_PORT (in int form)
        addq    $24, %rsp                           # shrink stack back down
        movl    $1, %eax                            # return 1; indicates success
        ret                                         # eventually return from the function       

.END_TWO:                                           # pointless formatting, could have easily been placed above .FAILURE
        
        addq    $24, %rsp                           # shrink stack back down
        movl    $0, %eax                            # move 0 to return register to indicate success
        ret                                         # return 0; success
