

#define DISPLAY_ADRESS $BB80  ; using top left of status line
#define rtcbuff	$6000


main
	;lda #$42			;; just some nominal values
	;sta rtcbuff,0			;;	
	;lda #$15			;; lines should be commented out or deleted
	;sta rtcbuff,1			;;
	;lda #$18			;; if using a real 1307 module
	;sta rtcbuff,2
	;;;;  set buffer to be 18:15:42			
						
						
						
						; load the 3 bytes then push them to the stack backwards
						; convert to ascii and push to stack
	ldx #0						
	lda rtcbuff,x			; seconds
	jsr hex2char
	tax
	tya
	pha
	txa
	pha
	
	ldx #1						
	lda rtcbuff,x			; minutes
	jsr hex2char
	tax
	tya
	pha
	txa
	pha
	
	ldx #2						
	lda rtcbuff,x			; hours
	jsr hex2char
	tax
	tya
	pha
	txa
	pha

				;;;We now should have 6 items on the stack in the correct order
	
  				; Start at the first character
  	ldx #0
loop_char
  	pla				;get characters from stack in order
	sta DISPLAY_ADRESS,x
	inx
	pla
	sta DISPLAY_ADRESS,x
	inx
  	cpx #8
  	beq end_loop
  	lda #$3A				;ASCII for a ":"
	sta DISPLAY_ADRESS,x
  	inx
  	jmp loop_char  
end_loop
  	rts


	

;  A = entry value
hex2char
  	sed        
  	tax        
  	and #$0F   
  	cmp #9+1   
  	adc #$30   
  	tay        
  	txa        
  	lsr        
  	lsr        
  	lsr        
  	lsr        
  	cmp #9+1   
  	adc #$30   
  	cld
	rts
;  A = MSN ASCII char
;  Y = LSN ASCII char
