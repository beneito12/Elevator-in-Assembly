; ECE 0202 Final Project - Elevator Controller
; Uses keypad for input, 2 stepper motors, 7seg display, LEDs
; Built on lab 5 template

     INCLUDE core_cm4_constants.s
     INCLUDE stm32l476xx_constants.s

     IMPORT       System_Clock_Init
     IMPORT       UART2_Init
     IMPORT       USART2_Write

     AREA     main, CODE, READONLY
     EXPORT       __main
     ENTRY

; R5 = current floor (1-3)
; R6 = target floor
; R7 = floor request bits (bit0=floor1, bit1=floor2, bit2=floor3)

__main     PROC

     BL    System_Clock_Init
     BL    UART2_Init

; turn on clocks for GPIOA, GPIOB, GPIOC
      LDR   R0, =RCC_BASE
      LDR   R1, [R0, #RCC_AHB2ENR]
      ORR   R1, R1, #0x07          ; bits 0,1,2 = ports A,B,C
      STR   R1, [R0, #RCC_AHB2ENR]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPIOA setup
;; PA5,6,7 = LEDs
;; PA8-11 = cabin motor (In1-In4 on ULN2003)
;; dont touch PA2/PA3, UART2_Init already set those up
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      LDR   R0, =GPIOA_BASE
      LDR   R1, [R0, #GPIO_MODER]
      ; clear the bits we need
      BIC   R1, R1, #(3<<10) ; PA5
      BIC   R1, R1, #(3<<12) ; PA6
      BIC   R1, R1, #(3<<14) ; PA7
      BIC   R1, R1, #(3<<16) ; PA8
      BIC   R1, R1, #(3<<18) ; PA9
      BIC   R1, R1, #(3<<20) ; PA10
      BIC   R1, R1, #(3<<22) ; PA11
      ; set as outputs
      ORR   R1, R1, #(1<<10)
      ORR   R1, R1, #(1<<12)
      ORR   R1, R1, #(1<<14)
      ORR   R1, R1, #(1<<16)
      ORR   R1, R1, #(1<<18)
      ORR   R1, R1, #(1<<20)
      ORR   R1, R1, #(1<<22)
      STR   R1, [R0, #GPIO_MODER]
      ; push-pull is default so no OTYPER needed for motors
      ; ULN2003 takes regular 3.3V logic

     ; start everything off
     LDR   R1, [R0, #GPIO_ODR]
     BIC   R1, R1, #(0xF<<8) ; motors off
     BIC   R1, R1, #(7<<5)   ; leds off
     STR   R1, [R0, #GPIO_ODR]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPIOB setup
;; PB0,1,4 = keypad columns (input w/ pullup)
;; PB2,3,6,7 = door motor
;; PB12-15 = BCD to 74LS247
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      LDR   R0, =GPIOB_BASE
      LDR   R1, [R0, #GPIO_MODER]
      BIC   R1, R1, #(3<<0)   ; PB0 input
      BIC   R1, R1, #(3<<2)   ; PB1 input
      BIC   R1, R1, #(3<<4)   ; PB2
      BIC   R1, R1, #(3<<6)   ; PB3
      BIC   R1, R1, #(3<<8)   ; PB4 input
      BIC   R1, R1, #(3<<12) ; PB6
      BIC   R1, R1, #(3<<14) ; PB7
      BIC   R1, R1, #(3<<24) ; PB12
      BIC   R1, R1, #(3<<26) ; PB13
      BIC   R1, R1, #(3<<28) ; PB14
      BIC   R1, R1, #(3<<30) ; PB15
      ; motor + display pins as output
      ORR   R1, R1, #(1<<4)
      ORR   R1, R1, #(1<<6)
      ORR   R1, R1, #(1<<12)
      ORR   R1, R1, #(1<<14)
      ORR   R1, R1, #(1<<24)
      ORR   R1, R1, #(1<<26)
      ORR   R1, R1, #(1<<28)
      ORR   R1, R1, #(1<<30)
      STR   R1, [R0, #GPIO_MODER]

     ; pullups on column pins (same as lab 4)
     LDR   R1, [R0, #GPIO_PUPDR]
     BIC   R1, R1, #(3<<0)
     BIC   R1, R1, #(3<<2)
     BIC   R1, R1, #(3<<8)
     ORR   R1, R1, #(1<<0)   ; PB0 pullup
     ORR   R1, R1, #(1<<2)   ; PB1 pullup
     ORR   R1, R1, #(1<<8)   ; PB4 pullup
     STR   R1, [R0, #GPIO_PUPDR]

     ; motors off, display blank
     LDR   R1, [R0, #GPIO_ODR]
     BIC   R1, R1, #0xCC              ; door motor off
     BIC   R1, R1, #(0xF<<12)         ; display off
     STR   R1, [R0, #GPIO_ODR]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GPIOC - keypad rows
;; PC0-3 = rows, open drain
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      LDR   R0, =GPIOC_BASE
      LDR   R1, [R0, #GPIO_MODER]
      BIC   R1, R1, #(3<<0)   ; PC0
      BIC   R1, R1, #(3<<2)   ; PC1
     BIC   R1, R1, #(3<<4)   ; PC2
     BIC   R1, R1, #(3<<6)   ; PC3
     ORR   R1, R1, #(1<<0)   ; PC0 output
     ORR   R1, R1, #(1<<2)   ; PC1 output
     ORR   R1, R1, #(1<<4)   ; PC2 output
     ORR   R1, R1, #(1<<6)   ; PC3 output
     STR   R1, [R0, #GPIO_MODER]

     ; open drain for rows
     LDR   R1, [R0, #GPIO_OTYPER]
     ORR   R1, R1, #(0xF)         ; PC0-3 open drain
     STR   R1, [R0, #GPIO_OTYPER]

     ; rows idle high
     LDR   R1, [R0, #GPIO_ODR]
     ORR   R1, R1, #(0xF)          ; PC0-3 high
     STR   R1, [R0, #GPIO_ODR]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial state
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      MOV   R5, #1            ; start at floor 1
      MOV   R6, #1
      MOV   R7, #0            ; nothing requested yet

     BL    UpdateDisplay
     LDR   R0, =strBoot
     MOV   R1, #24
     BL    USART2_Write

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main loop - scan keypad, service requests
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MainLoop
      BL    ScanKeypad

     CMP   R7, #0
     BEQ   MainLoop          ; nothing to do

      BL    PickClosestFloor
      ; scan keypad for a few seconds
      LDR R4, =1000
QueueLoop
      BL ScanKeypad
      SUBS R4, R4, #1
      BNE QueueLoop
      BL PickClosestFloor

     CMP R5, R6

     BEQ   ServeFloor

MoveLoop
      BL   ScanKeypad        ; keep checking while moving

     CMP   R5, R6
     BEQ   ServeFloor

     CMP   R5, R6
       BGT   GoDown

GoUp
       BL    LedUpOn
       LDR   R0, =strUp
       MOV   R1, #11
       BL    USART2_Write
       BL    MoveUpOneFloor
       ADD   R5, R5, #1
       BL    UpdateDisplay
       B     MoveLoop

GoDown
      BL     LedDownOn
      LDR    R0, =strDown
      MOV    R1, #13
      BL     USART2_Write
      BL     MoveDownOneFloor
      SUB    R5, R5, #1
      BL     UpdateDisplay
      B      MoveLoop

ServeFloor
      ; clear the bit for this floor
      MOV   R0, #1
      SUB   R1, R5, #1
      LSL   R0, R0, R1
      BIC   R7, R7, R0

       BL    LedsOff

       ; print arrived message (patch in floor number)
       LDR   R0, =strArrived
       ADD   R1, R5, #'0'
       STRB R1, [R0, #18]
       MOV   R1, #21
       BL    USART2_Write

       BL    OpenDoor
       BL    DwellTime
       BL    CloseDoor

       B     MainLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ScanKeypad
;; scans 3x4 matrix to check for key presses
;; rows on PC0-3 (output open drain)
;; cols on PB0, PB1, PB4 (input pullup)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ScanKeypad
      PUSH {R0-R4, LR}
      LDR   R0, =GPIOC_BASE
      LDR   R3, =GPIOB_BASE

       ; all rows high first
       LDR   R1, [R0, #GPIO_ODR]
       ORR   R1, R1, #0xF
       STR   R1, [R0, #GPIO_ODR]
     ; pull all rows low to see if anything is pressed
     LDR   R1, [R0, #GPIO_ODR]
     BIC   R1, R1, #0xF
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay

     ; check columns
     LDR   R2, [R3, #GPIO_IDR]
     AND   R4, R2, #(1<<0)
     CBZ   R4, KeyDetected
     AND   R4, R2, #(1<<1)
     CBZ   R4, KeyDetected
     AND   R4, R2, #(1<<4)
     CBZ   R4, KeyDetected

     ; nothing pressed
     LDR   R1, [R0, #GPIO_ODR]
     ORR   R1, R1, #0xF
     STR   R1, [R0, #GPIO_ODR]
     POP   {R0-R4, LR}
     BX    LR
     LTORG

KeyDetected
      ; reset rows
      LDR   R1, [R0, #GPIO_ODR]
      ORR   R1, R1, #0xF
      STR   R1, [R0, #GPIO_ODR]

     ;; now scan each row to find which key

     ; --- row 1 (PC0) = 1, 2, 3 ---
     LDR   R1, [R0, #GPIO_ODR]
     BIC   R1, R1, #(1<<0)
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     LDR   R2, [R3, #GPIO_IDR]
     TST   R2, #(1<<0)
     BEQ   Key1
     TST   R2, #(1<<1)
     BEQ   Key2
     TST   R2, #(1<<4)
     BEQ   Key3
     LDR   R1, [R0, #GPIO_ODR]
     ORR   R1, R1, #(1<<0)
     STR   R1, [R0, #GPIO_ODR]
; --- row 2 (PC1) = 4, 5, 6 ---
LDR   R1, [R0, #GPIO_ODR]
BIC   R1, R1, #(1<<1)
STR   R1, [R0, #GPIO_ODR]
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
LDR   R2, [R3, #GPIO_IDR]
TST   R2, #(1<<0)
BEQ.W KeyIgnore
TST   R2, #(1<<1)
BEQ.W KeyIgnore
TST   R2, #(1<<4)
BEQ.W KeyIgnore
LDR   R1, [R0, #GPIO_ODR]
ORR   R1, R1, #(1<<1)
STR   R1, [R0, #GPIO_ODR]

; --- row 3 (PC2) = 7, 8, 9 ---
LDR   R1, [R0, #GPIO_ODR]
BIC   R1, R1, #(1<<2)
STR   R1, [R0, #GPIO_ODR]
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
LDR   R2, [R3, #GPIO_IDR]
TST   R2, #(1<<0)
BEQ.W KeyIgnore
TST   R2, #(1<<1)
BEQ.W KeyIgnore
TST   R2, #(1<<4)
BEQ.W KeyIgnore
LDR   R1, [R0, #GPIO_ODR]
ORR   R1, R1, #(1<<2)
STR   R1, [R0, #GPIO_ODR]

; --- row 4 (PC3) = *, 0, # ---
LDR   R1, [R0, #GPIO_ODR]
BIC   R1, R1, #(1<<3)
STR   R1, [R0, #GPIO_ODR]
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
BL    ShortDelay
LDR   R2, [R3, #GPIO_IDR]
TST   R2, #(1<<0)
BEQ   KeyStar
       TST   R2, #(1<<1)
       BEQ   Key0
       TST   R2, #(1<<4)
       BEQ   KeyHash
       LDR   R1, [R0, #GPIO_ODR]
       ORR   R1, R1, #(1<<3)
       STR   R1, [R0, #GPIO_ODR]
       B     ScanDone

; --- key handlers ---

Key1
       ORR   R7, R7, #1
       LDR   R0, =strReq1
       MOV   R1, #19
       BL    USART2_Write
       B     Debounce

Key2
       ORR   R7, R7, #2
       LDR   R0, =strReq2
       MOV   R1, #19
       BL    USART2_Write
       B     Debounce

Key3
       ORR   R7, R7, #4
       LDR   R0, =strReq3
       MOV   R1, #19
       BL    USART2_Write
       B     Debounce

KeyStar
      ; emergency stop!!
      BL    AllMotorsOff
      BL    LedsOff
      LDR   R0, =strEmerg
      MOV   R1, #16
      BL    USART2_Write
      ; sit here until they let go of *
HoldEmergency
      LDR   R0, =GPIOC_BASE
      LDR   R1, [R0, #GPIO_ODR]
      ORR   R1, R1, #0xF
      BIC   R1, R1, #(1<<3)   ; only row 4 low
      STR   R1, [R0, #GPIO_ODR]
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      LDR   R0, =GPIOB_BASE
      LDR   R2, [R0, #GPIO_IDR]
      TST   R2, #(1<<0)       ; col 1 still low = still holding *
      BEQ   HoldEmergency
      LDR   R0, =strResume
      MOV   R1, #19
       BL   USART2_Write
       B    ScanDone

Key0
      ; manual override - cycle through floors
      ADD   R6, R6, #1
      CMP   R6, #4
      BNE   ManualOk
      MOV   R6, #1
ManualOk
      MOV   R0, #1
      SUB   R1, R6, #1
      LSL   R0, R0, R1
      ORR   R7, R7, R0
      LDR   R0, =strManual
      MOV   R1, #24
      BL    USART2_Write
      B     Debounce

KeyHash
      ; maintenance - go back to floor 1
      MOV   R7, #1
      MOV   R6, #1
      LDR   R0, =strMaint
      MOV   R1, #37
      BL    USART2_Write
      B     Debounce

KeyIgnore
      B     Debounce

; wait for them to let go of the button
Debounce
      LDR   R0, =GPIOC_BASE
      LDR   R1, [R0, #GPIO_ODR]
      BIC   R1, R1, #0xF      ; all rows low
      STR   R1, [R0, #GPIO_ODR]
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      LDR   R0, =GPIOB_BASE
      LDR   R2, [R0, #GPIO_IDR]
      TST   R2, #(1<<0)
      BEQ   Debounce
      TST   R2, #(1<<1)
      BEQ   Debounce
      TST   R2, #(1<<4)
      BEQ   Debounce
      BL    ShortDelay
      BL    ShortDelay        ; extra settle time
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
      BL    ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay

ScanDone
      LDR    R0, =GPIOC_BASE
      LDR    R1, [R0, #GPIO_ODR]
      ORR    R1, R1, #0xF      ; rows back to idle
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R4, LR}
      BX     LR

     LTORG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PickClosestFloor
;; checks which requested floor is nearest
;; to current position, puts result in R6
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PickClosestFloor
      PUSH {R0-R4, LR}

     ; if were already at a requested floor just stay
     MOV   R0, #1
     SUB   R1, R5, #1
     LSL   R0, R0, R1
     TST   R7, R0
     BEQ   NotHere
     MOV   R6, R5
     B     PickDone

NotHere
      MOV    R2, #127         ; best dist so far
      MOV    R3, R5                 ; fallback

     ; check floor 1
     TST   R7, #1
     BEQ   ChkF2
     MOV   R0, #1
     SUBS R1, R5, R0
     IT    MI
     RSBMI R1, R1, #0         ; abs()
     CMP   R1, R2
     BGE   ChkF2
     MOV   R2, R1
     MOV   R3, #1

ChkF2 TST   R7, #2
      BEQ   ChkF3
      MOV   R0, #2
      SUBS R1, R5, R0
      IT    MI
      RSBMI R1, R1, #0
      CMP   R1, R2
      BGE   ChkF3
      MOV   R2, R1
     MOV     R3, #2

ChkF3 TST   R7, #4
      BEQ   PickResult
      MOV   R0, #3
      SUBS R1, R5, R0
      IT    MI
      RSBMI R1, R1, #0
      CMP   R1, R2
      BGE   PickResult
      MOV   R2, R1
      MOV   R3, #3

PickResult
      MOV    R6, R3
PickDone
      POP    {R0-R4, LR}
      BX     LR

     LTORG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Movement - one floor at a time
;; 200 steps per floor with speed ramping
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MoveUpOneFloor
      PUSH {R0-R4, LR}
      LDR   R4, =200
UpLoop      CMP   R4, #0
      BEQ   UpDone
      BL    CabinStepFwd
      BL    StepDelay
      SUB   R4, R4, #1
      B     UpLoop
UpDone      BL    CabinOff
      POP   {R0-R4, LR}
      BX    LR

MoveDownOneFloor
      PUSH {R0-R4, LR}
      LDR   R4, =200
DnLoop      CMP   R4, #0
      BEQ   DnDone
      BL    CabinStepRev
      BL    StepDelay
      SUB   R4, R4, #1
      B     DnLoop
DnDone      BL    CabinOff
      POP   {R0-R4, LR}
      BX    LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Cabin stepper - PA8=In1 PA9=In2 PA10=In3 PA11=In4
;; full step: 0x3, 0x6, 0xC, 0x9 (shifted to bits 8-11)
;; active high because ULN2003
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CabinStepFwd
      PUSH {R0-R2, LR}
      LDR   R0, =GPIOA_BASE
     LDR   R2, [R0, #GPIO_ODR]
     BIC   R2, R2, #(0xF<<8)

     ORR   R1, R2, #(0x3<<8) ; In1+In2
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #(0x6<<8) ; In2+In3
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #(0xC<<8) ; In3+In4
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #(0x9<<8) ; In4+In1
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay

     POP   {R0-R2, LR}
     BX    LR

CabinStepRev
      PUSH {R0-R2, LR}
      LDR   R0, =GPIOA_BASE
      LDR   R2, [R0, #GPIO_ODR]
      BIC   R2, R2, #(0xF<<8)

     ORR   R1, R2, #(0x9<<8)
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #(0xC<<8)
     STR     R1, [R0, #GPIO_ODR]
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     ORR     R1, R2, #(0x6<<8)
     STR     R1, [R0, #GPIO_ODR]
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     ORR     R1, R2, #(0x3<<8)
     STR     R1, [R0, #GPIO_ODR]
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay
     BL      ShortDelay

     POP     {R0-R2, LR}
     BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Door stepper - PB2=In1 PB3=In2 PB6=In3 PB7=In4
;; same idea as cabin but pins are scattered
;; mask is 0xCC (bits 2,3,6,7)
;; patterns: 0x0C, 0x48, 0xC0, 0x84
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OpenDoor
      PUSH {R0-R4, LR}
      BL    LedDoorOn
      LDR   R0, =strDoorOpen
      MOV   R1, #15
      BL    USART2_Write
      LDR   R4, =120
DoorOpenLp
      CMP   R4, #0
      BEQ   DoorOpenDn
      BL    DoorStepFwd
      BL    MedDelay
      SUB   R4, R4, #1
      B     DoorOpenLp
DoorOpenDn
      BL    DoorOff
      POP   {R0-R4, LR}
      BX    LR

CloseDoor
      PUSH   {R0-R4, LR}
      LDR    R0, =strDoorClose
      MOV    R1, #15
      BL    USART2_Write
      LDR   R4, =120
DoorCloseLp
      CMP   R4, #0
      BEQ   DoorCloseDn
      BL    DoorStepRev
      BL    MedDelay
      SUB   R4, R4, #1
      B     DoorCloseLp
DoorCloseDn
      BL    DoorOff
      BL    LedDoorOff
      POP   {R0-R4, LR}
      BX    LR

DoorStepFwd
      PUSH {R0-R2, LR}
      LDR   R0, =GPIOB_BASE
      LDR   R2, [R0, #GPIO_ODR]
      BIC   R2, R2, #0xCC

     ORR   R1, R2, #0x0C          ; In1+In2
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0x48          ; In2+In3
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0xC0          ; In3+In4
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0x84          ; In4+In1
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay

     POP   {R0-R2, LR}
     BX    LR

DoorStepRev
      PUSH {R0-R2, LR}
      LDR   R0, =GPIOB_BASE
      LDR   R2, [R0, #GPIO_ODR]
      BIC   R2, R2, #0xCC

     ORR   R1, R2, #0x84
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0xC0
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0x48
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     ORR   R1, R2, #0x0C
     STR   R1, [R0, #GPIO_ODR]
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay
     BL    ShortDelay

     POP   {R0-R2, LR}
     BX    LR

; passenger wait time
DwellTime
      PUSH {R0, LR}
      LDR   R0, =40000000
DwellLp     SUBS R0, R0, #1
      BNE   DwellLp
      POP   {R0, LR}
      BX    LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display - BCD on PB12-15
;; 74LS247 takes care of decoding
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateDisplay
      PUSH {R0-R2, LR}
      LDR   R0, =GPIOB_BASE
      LDR   R1, [R0, #GPIO_ODR]
      BIC   R1, R1, #(0xF<<12)
      MOV   R2, R5
      LSL   R2, R2, #12
      ORR   R1, R1, R2
      STR   R1, [R0, #GPIO_ODR]
      POP   {R0-R2, LR}
      BX    LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LEDs - PA5=up PA6=down PA7=door
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LedUpOn
      PUSH {R0-R1, LR}
      BL    LedsOff
      LDR   R0, =GPIOA_BASE
      LDR   R1, [R0, #GPIO_ODR]
      ORR   R1, R1, #(1<<5)
      STR   R1, [R0, #GPIO_ODR]
      POP   {R0-R1, LR}
      BX    LR

LedDownOn
      PUSH   {R0-R1, LR}
      BL     LedsOff
      LDR    R0, =GPIOA_BASE
      LDR    R1, [R0, #GPIO_ODR]
      ORR    R1, R1, #(1<<6)
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R1, LR}
      BX     LR

LedDoorOn
      PUSH   {R0-R1, LR}
      BL     LedsOff
      LDR    R0, =GPIOA_BASE
      LDR    R1, [R0, #GPIO_ODR]
      ORR    R1, R1, #(1<<7)
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R1, LR}
      BX     LR

LedDoorOff
      PUSH   {R0-R1, LR}
      LDR    R0, =GPIOA_BASE
      LDR    R1, [R0, #GPIO_ODR]
      BIC    R1, R1, #(1<<7)
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R1, LR}
      BX     LR

LedsOff
      PUSH   {R0-R1, LR}
      LDR    R0, =GPIOA_BASE
     LDR     R1, [R0, #GPIO_ODR]
     BIC     R1, R1, #(7<<5)   ; clear PA5,6,7 at once
     STR     R1, [R0, #GPIO_ODR]
     POP     {R0-R1, LR}
     BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Motor off helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AllMotorsOff
      PUSH {R0-R1, LR}
      LDR   R0, =GPIOA_BASE
      LDR   R1, [R0, #GPIO_ODR]
      BIC   R1, R1, #(0xF<<8)
      STR   R1, [R0, #GPIO_ODR]
      LDR   R0, =GPIOB_BASE
      LDR   R1, [R0, #GPIO_ODR]
      BIC   R1, R1, #0xCC
      STR   R1, [R0, #GPIO_ODR]
      POP   {R0-R1, LR}
      BX    LR

CabinOff
      PUSH   {R0-R1, LR}
      LDR    R0, =GPIOA_BASE
      LDR    R1, [R0, #GPIO_ODR]
      BIC    R1, R1, #(0xF<<8)
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R1, LR}
      BX     LR

DoorOff
      PUSH   {R0-R1, LR}
      LDR    R0, =GPIOB_BASE
      LDR    R1, [R0, #GPIO_ODR]
      BIC    R1, R1, #0xCC
      STR    R1, [R0, #GPIO_ODR]
      POP    {R0-R1, LR}
      BX     LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Delays
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ShortDelay
      PUSH {R0, LR}
      LDR   R0, =10000
SDLp SUBS R0, R0, #1
      BNE   SDLp
      POP   {R0, LR}
      BX    LR

MedDelay
      PUSH   {R0, LR}
      LDR    R0, =30000
MDLp SUBS    R0, R0, #1
      BNE    MDLp
      POP    {R0, LR}
      BX     LR
; speed ramp for cabin - slow at start/end, fast in middle
; R4 has the step count (200 down to 0)
StepDelay
      PUSH {R0, LR}
      CMP   R4, #160
      BGT   SlowDelay
      CMP   R4, #40
      BLE   SlowDelay
      LDR   R0, =2000         ; cruising speed
      B     RunDelay
SlowDelay
      LDR   R0, =80000        ; accel/decel
RunDelay
      SUBS R0, R0, #1
      BNE   RunDelay
      POP   {R0, LR}
      BX    LR

     ENDP

     ALIGN

     AREA myData, DATA, READWRITE
     ALIGN

strBoot           DCB "Elevator system booted",13,10
strUp       DCB "Moving up",13,10
strDown           DCB "Moving down",13,10
strArrived DCB "Arrived at floor X",13,10
strDoorOpen DCB "Doors opening",13,10
strDoorClose      DCB "Doors closing",13,10
strEmerg    DCB "EMERGENCY STOP",13,10
strResume   DCB "Emergency cleared",13,10
strMaint    DCB "Maintenance mode: return to floor 1",13,10
strManual   DCB "Manual override active",13,10
strReq1           DCB "Floor 1 requested",13,10
strReq2           DCB "Floor 2 requested",13,10
strReq3           DCB "Floor 3 requested",13,10

     END