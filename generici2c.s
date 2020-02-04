;;;==================================================================
;;;		Generic I2C Read and Write Routines for Oric
;;;==================================================================

#define DISPLAY_ADRESS $BB80  ; using top left of status line
#define rtcbuff	$6000


RxBuffL		=	$00		; receive buffer pointer low byte	- ZP location change as required
TxBuffL		=	RxBuffL		
RxBuffH		=	$01		; receive buffer pointer high byte	ZP location change as required
TxBuffH		=	RxBuffH	
ByteBuff	=	$02		; byte buffer for Tx/Rx routines	ZP location change as required
I2cCountL	=	$03		; Tx/Rx byte count low byte			ZP location change as required
I2cCountH	=	$04		; Tx/Rx byte count high byte		ZP location change as required
RWFlag		= 	$05
OldPCR		=	$06		; temp store for via pcr 
DevAddress	=	$07		; main device address
DevReadAdd	=	$08		; some devices have a 2nd address for read/write ops
DelayFlag	=	$09		; Set to 1 to have a delay after each sent byte (LCDs Need this).. otherwise 0
DATFlag		= 	$0A		;Set to 1 to have #00 sent before a read.

I2CPort		=	$301		; 6522 Via Output Register Port A	(change to suit system)
ViaDDRA		=	I2CPort+2	; 6522 Via Data Direction Register Port A
ViaPCR		= 	I2CPort+12	; Preipeheral Control Register to Diable AY chip
;;PORT-A-SDA	=	%00000001	;SDA is 1st byte of Port A of 6522 (pin 2 of chip)
;;PORT-A-CLK		%00000010	;CLK is 2nd byte of Port A	of 6522 (pin3 of chip)

;;; For an Oric Computer the following would be needed :-
;;;	A cable that connected pin 3 , 5 and 4 of the printer port
;;; These are as you look at the back of the Oric the 2nd and 3rd pins of the bottom row
;;; And Any of the top row that you like (they are all ground)
;;; Pin 3 is the SDA line
;;; Pin 5 is the ClK line
;;; Pin 4 is a GND line
;;; You could take +5v from pin 33 of the expansion port (bottom far right looking from back)
;;;
;;; The Oric Via is mapped at #300-#30F so for this the I2CPort should be set at #301
;;; 

*= $4000

Init
	lda ViaPCR
	sta OldPCR
	lda #%11101110
	sta ViaPCR
	lda #$FF			;; Setup 6522 Via
	sta ViaDDRA
	sta I2CPort
	jsr StopI2c			;; Ensure I2C is in known condition
	lda #0
	sta I2cCountH		;; limit to 255 bytes send/receive at the moment

GetData
	lda RWFlag				; test for read or write needed (0 is write, 1 = read)
	bne RcvRoutine
	jsr StopI2c	
	jsr SendAddr			; send address to activate device (starts in write mode)
	jsr SendData
	jmp EndofGetorSend
RcvRoutine
	jsr StopI2c	
	lda DATFlag
	beq NoZero
	jsr SendAddr
	LDA #00					; send #00 to select first register. device auto increments
	JSR ByteOut
NoZero	
	jsr SndReadAdd
	jsr ReadData
EndofGetorSend
	jsr StopI2c				;stop i2c
	lda OldPCR
	sta ViaPCR				; reset via to original condition
	rts						;return to monitor/basic/calling routine
	

SendAddr
	LDA	I2CPort			; get i2c port state
	ORA	#$01			; release data
	STA	I2CPort			; out to i2c port
	LDA	#$03			; release clock
	STA	I2CPort			; out to i2c port

	LDA	#$01			; set for data test
WaitAD
	BIT	I2CPort			; test the clock line
	BEQ	WaitAD			; wait for the data to rise

	LDA	#$02			; set for clock test
WaitAC
	BIT	I2CPort			; test the clock line
	BEQ	WaitAC			; wait for the clock to rise

	JSR	StartI2c		; generate start condition

	LDA	DevAddress
	ROL					; get address (including read/write bit)
	JSR	ByteOut			; send address byte
	BCS	StopI2c			; branch if no ack
	RTS					; else exit

SndReadAdd
	LDA	I2CPort			; get i2c port state
	ORA	#$01			; release data
	STA	I2CPort			; out to i2c port
	LDA	#$03			; release clock
	STA	I2CPort		; out to i2c port

	LDA	#$01			; set for data test
WaitADr
	BIT	I2CPort		; test the clock line
	BEQ	WaitADr			; wait for the data to rise

	LDA	#$02			; set for clock test
WaitACr
	BIT	I2CPort		; test the clock line
	BEQ	WaitACr			; wait for the clock to rise

	JSR	StartI2c		; generate start condition

	LDA	DevReadAdd		; get address (including read/write bit)
	ROL
	ORA #1					
	JSR	ByteOut			; send address byte
	BCS	StopI2c			; branch if no ack
	RTS				; else exit



SendData
	JSR	StartI2c
	INC	I2cCountH		; increment count high byte
	LDY	#$00			; set index to zero
WriteLoop
	LDA	(RxBuffL),Y 	; get byte from buffer
	JSR	ByteOut			; send byte to device
	BCS	StopI2c			; branch if no ack
	lda DelayFlag
	bne Skipdelay		;check delay flag is delay is needed (1 set)
	jsr	SpinWheels
Skipdelay
	INY				; increment index
	BNE	NoHiWrInc		; branch if no rollover

	INC	RxBuffH			; else increment pointer high byte
NoHiWrInc
	DEC	I2cCountL		; decrement count low byte
	BNE	WriteLoop		; loop if not all done

	DEC	I2cCountH		; decrement count high byte
	BNE	WriteLoop		; loop if not all done

	RTS

ReadData
	LDY #0
readloop2
	JSR ByteIn
	lda ByteBuff
	STA (TxBuffL),Y
	jsr DoAck2
	INY
	cpy I2cCountL			; have I done number of bytes?
	bne readloop2
	jsr DoNack
	jsr StopI2c			; finish read
	rts

StopI2c
	LDA	#$00			; now hold the data down
	STA	I2CPort			; out to i2c port

	NOP					; need this if running >1.9MHz
	LDA	#$02			; release the clock
	STA	I2CPort			; out to i2c port

	NOP					; need this if running >1.9MHz
	LDA	#$03			; now release the data (stop)
	STA	I2CPort			; out to i2c port
	RTS


StartI2c
	STA	I2CPort			; out to i2c port
	NOP					; need this if running >1.9MHz
	LDA	#$00			; clock low, data low
	STA	I2CPort			; out to i2c port
	RTS

ByteOut
	STA	ByteBuff		; save byte for transmit
	LDX	#$08			; 8 bits to do
OutLoop
	LDA	#$00			; unshifted clock low
	ROL	ByteBuff		; bit into carry
	ROL					; get data from carry
	STA	I2CPort			; out to i2c port
	NOP					; need this if running >1.9MHz
	ORA	#$02			; clock line high
	STA	I2CPort			; out to i2c port
	LDA	#$02			; set for clock test
WaitT1
	BIT	I2CPort			; test the clock line
	BEQ	WaitT1			; wait for the clock to rise

	LDA	I2CPort			; get data bit
	AND	#$01			; set clock low
	STA	I2CPort			; out to i2c port

	DEX					; decrement count
	BNE	OutLoop			; branch if not all done


;
; clock is low, data needs to be released, then the clock needs to be released then
; we need to wait for the clock to rise and get the ack bit.

GetAck
	LDA	#$01			; float data
	STA	I2CPort			; out to i2c port

	LDA	#$03			; float clock, float data
	STA	I2CPort			; out to i2c port

	LDA	#$02			; set for clock test
WaitGA
	BIT	I2CPort			; test the clock line
	BEQ	WaitGA			; wait for the clock to rise

	LDA	I2CPort			; get data
	LSR					; data bit to Cb

	LDA	#$01			; clock low, data released
	STA	I2CPort			; out to i2c port
	RTS



; input byte from 12c bus, byte is returned in A. entry should be with the clock low
; after generating a start or a previously sent byte
; exits with clock held low

ByteIn
	lda #0
	sta ByteBuff
	LDX	#$08			; 8 bits to do
	LDA	#$01			; release data
	STA	I2CPort			; out to i2c port
InLoop
	LDA	#$03			; release clock
	STA	I2CPort			; out to i2c port

	LDA	#$02			; set for clock test
WaitR1
	BIT	I2CPort			; test the clock line
	BEQ	WaitR1			; wait for the clock to rise

	LDA	I2CPort			; get data
	ROR					; bit into carry
	ROL	ByteBuff		; bit into buffer
	
	LDA	#$01			; set clock low
	STA	I2CPort			; out to i2c port

	DEX					; decrement count
	BNE	InLoop			; branch if not all done
	RTS


;;; Send Ack to tell device to increment register and send next byte

DoAck2
	LDA #0
	STA I2CPort
	NOP
	LDA #2
	STA I2CPort
	NOP
	lda #0
	sta I2CPort
	nop
	RTS


;;; I2C protocol states after all bytes received a "NACK" should be send before a stop
;;; Doesnt seem to send correctly but device works as expected on multiple runs. 

DoNack
	LDA #1
	STA I2CPort
	NOP
	LDA #3
	STA I2CPort
	NOP
	LDA #1
	STA I2CPort
	RTS



;;; Delay routine - sometimes needed on sending data. Depends on device.
;;; LCD displays need delays between commands and data before next byte is sent.
SpinWheels
	pha
	lda #255
	sec
spin
	sbc #1
	bne spin
	pla
	rts
	
