; Roy Kodman 215583097
; Amit Levy Tzedek 327723656

.model small
.data
.stack 100h

; parameters about ball and players (position, velocity, direction...):
PLAYER1_POSx DW 08d ; coordinates player1's x
PLAYER1_POSy DW 0780h ; coordinates of middle of the rows 0780h = 1920d = 12*160

PLAYER2_POSx DW 148d ; coordinates player2's x
PLAYER2_POSy DW 0780h ; coordinates of middle of the rows 0780h = 1920d = 12*160

BALL_POSx DW 4Eh ; coordinates of middle of the columns 004Eh = 78d = 39*2
BALL_POSy DW 0780h ; coordinates of middle of the rows 0780h = 1920d = 12*160

PLAYER_VEL_Y equ 00A0h ; velocity of rows in columns

BALL_VEL_X DW 2h ; initaliize ball velocity in x scale
BALL_VEL_Y DW 0h ; initialize ball velocity in y scale

BALL_DIRECTION_INDICATOR_X db 1d ; 0 = right, 1 = left
BALL_DIRECTION_INDICATOR_Y db 0d ; 0 = down , 1 = up

BALL_COLOR db 0Bh

; score:
PLAYER1_SCORE db 0 ; Player 1's score
PLAYER2_SCORE db 0 ; Player 2's score
PLAYER1_SCORE_POS equ 190d ; location of Player 1's score on the screen 
PLAYER2_SCORE_POS equ 290d; location of Player 2's score on the screen 

clock_ticks db 3 ; 9 clock ticks and each tick is 55 ms so 9*55 is almost 0.5 seconds 
clock_inter_offset dw ? ; for the deafult clock interrupt offset
clock_inter_segment dw ? ; for the deafult clock interrupt offset

; messages:
GameOverMsg db 'GAME OVER', 0
Player1WonMsg db 'Blue Player Won!', 0
Player2WonMsg db 'Red Player Won!', 0
GameStatisticsTitle db 'Game Statistics', 0
CornerHitsMsg db 'Corner Hits:', 0
CenterHitsMsg db 'Center Hits:', 0
PortalPassMsg db 'Portal Pass:', 0

; Game stats counters:
cornerHitsPlayer1Tens db 0
cornerHitsPlayer1Units db 0
centerHitsPlayer1Tens db 0
centerHitsPlayer1Units db 0
portalPassPlayer1Tens db 0
portalPassPlayer1Units db 0

cornerHitsPlayer2Tens db 0
cornerHitsPlayer2Units db 0
centerHitsPlayer2Tens db 0
centerHitsPlayer2Units db 0
portalPassPlayer2Tens db 0
portalPassPlayer2Units db 0

color db 0 ; define color for numbers prints

; purple ball parameters:
totalPoints DW 0
purpleBallPoints dw 3 ; defines the times when the purple ball appear

; portal flag to prevent loops 
PORTAL_COOLDOWN_FLAG db 0 ; 1 = just teleported, 0 = no teleport in progress

.code

; this function will change the original clock interrupt 
CustomClockInterrupt PROC far
	dec clock_ticks

	jnz original_interrupt ; jump if 3 sec has not passed yet
	
	push es ; save the value of es
	
	mov ax, 0b800h 
	mov es, ax ; place the screen to es
	
	call MoveBall 
	
	pop es ; take back the old value of es
	
original_interrupt: ; go to the original interrupt
	jmp dword ptr [clock_inter_offset]
	
	ret
	
CustomClockInterrupt ENDP


; this function will change to the new custom clock interrupt
StartTime PROC uses es bx ax
	cli ; mask interrupts
	
	mov ax, 0 ; change es
	mov es, ax
	
	mov ax, es:[8*4] ; store the original clock interrupt in the memory
	mov clock_inter_offset, ax
	
	mov ax, es:[8*4 + 2]
	mov clock_inter_segment, ax
	
	
	mov bx, offset CustomClockInterrupt ; change it to be our custom clock interrupt
	mov es:[8*4], bx	
	mov bx, seg CustomClockInterrupt
	mov es:[8*4 + 2], bx
	
	sti ; remove the "mask interrupt"
	
	ret

StartTime ENDP


; this function will change back to the original clock interrupt
StopTime PROC uses es ax bx
	cli ; mask interrupts
	mov ax, 0
	mov es, ax
	
	mov bx, clock_inter_offset ; return the original clock interrupt to its place
	mov es:[32d], bx
	
	mov bx, clock_inter_segment
	mov es:[34d], bx
	
	sti ; remove the "mask interrupt"
	
	ret

StopTime ENDP


; this function print black blocks over ther screen (it creates the base for the game) and create the middle line
printGameWindow PROC uses ax cx si
	mov cx, 2000d ; define number of iterations
	mov ax, 20DBh ; define black block
	mov si, 00h ; define starting point
Loop1:
	mov es:[si], ax ; print the black block in place si
	add si, 2h ; increase si
	dec cx ; cx = cx - 1
	jnz Loop1 ; if cx != 0 ump back to Loop1
	
	mov cx, 27d
	mov bx, 0d
	mov al, '|'
	mov ah, 0Fh
printMiddleLine:
	mov es:[bx + 78d], ax
	
	add bx, 160d
	dec cx
	jnz printMiddleLine
	
	call PrintPortalGates
	
	ret
printGameWindow ENDP


; this function prints the portal gates
PrintPortalGates PROC uses ax bx cx 
	mov cx, 3d ; length of gate
	mov bx, 682d ; starting point of left the portal gate
	mov al, '|'
	mov ah, 2Ah
printLeftPortalGate:
	mov es:[bx], ax
	add bx, 160d
	dec cx
	jnz printLeftPortalGate

	mov cx, 3d ; length of gate
	mov bx, 2518d ; starting point right of the portal gate
	mov al, '|'
	mov ah, 2Ah
printRightPortalGate:
	mov es:[bx], ax
	add bx, 160d
	dec cx
	jnz printRightPortalGate

	ret
PrintPortalGates ENDP

; that function print player1's paddle in (player1x, player1y - 2 ) - (player1x, player1y + 2 ) cordinates
PrintPlayer1 PROC uses ax bx cx
	mov cx, 5d
	mov ax, 21DBh ; define white block
	mov bx, PLAYER1_POSy ; bx save player position y
	add bx, PLAYER1_POSx ; bx now is the position of the player
	SUB bx, 320d

LoopPlayer1:
	mov es:[bx], ax; print the paddle
	mov es:[bx + 2d], ax
	
	add bx, 160d
	
	dec cx
	jnz LoopPlayer1
	
	ret
	
PrintPlayer1 ENDP


; that function print player1's paddle in (player2x, player2y - 2 ) - (player2x, player2y + 2 ) cordinates
PrintPlayer2 PROC uses ax bx cx
	mov cx, 5d
	mov ax, 24DBh ; define white block
	mov bx, PLAYER2_POSy ; bx save player position y
	add bx, PLAYER2_POSx ; bx now is the position of the player
	SUB bx, 320d

LoopPlayer2:
	mov es:[bx], ax ; print the paddle
	mov es:[bx + 2d], ax
	
	add bx, 160d
	
	dec cx
	jnz LoopPlayer2
	
	ret
	
PrintPlayer2 ENDP


; that function clear player1's paddle from the screen
ClearPlayer1 PROC uses ax bx cx
	mov cx, 5d
	mov ax, 20DBh ; define white block
	mov bx, PLAYER1_POSy ; bx save player position y
	add bx, PLAYER1_POSx ; bx now is the position of the player
	SUB bx, 320d

LoopClearPlayer1:
	mov es:[bx], ax ; print the paddle
	mov es:[bx + 2d], ax
	
	add bx, 160d
	
	dec cx
	jnz LoopClearPlayer1
	
	ret
clearPlayer1 ENDP


; that function clear player2's paddle from the screen
ClearPlayer2 PROC uses ax bx cx
	mov cx, 5d
	mov ax, 20DBh ; define white block
	mov bx, PLAYER2_POSy ; bx save player position y
	add bx, PLAYER2_POSx ; bx now is the position of the player
	SUB bx, 320d

LoopClearPlayer2:
	mov es:[bx], ax ; print the paddle
	mov es:[bx + 2d], ax
	
	add bx, 160d
	
	dec cx
	jnz LoopClearPlayer2
	
	ret
clearPlayer2 ENDP


; that function print tha ball in position: (BALL_POSx, BALL_POSy)
PrintBall PROC uses ax bx

	call ClearBall
	
	mov ax, totalPoints
	mov bx, purpleBallPoints
	cmp ax, bx ; check if now 3 points were scored
	je SPECIAL_POINT
	
	mov al, 'O' ; Load ball symbol
	mov ah, BALL_COLOR
	jmp FINISH_PRINT_BALL
SPECIAL_POINT:
	
	mov al, 'O' ; Load ball symbol
	mov ah, 8Dh ; print the ball in blinking purple
	
FINISH_PRINT_BALL:
	mov bx, BALL_POSy ; bx save ball position y
	add bx, BALL_POSx ; bx now is the position of the ball
	mov es:[bx], ax ; print the ball
	ret ; return 
PrintBall ENDP


; this function gets the key that was preseed in register al and move one of the players if a correct key was pressed
keyboardHandler PROC uses ax bx

	mov bh, 80h ; check if the key was pressed or released
	and bh, al
	jnz DONE ; if it was released jump to DONE


	mov bl, 11h ; bl = scan code of w
	cmp bl, al ; compare al and bl
	je player1_MOVE_UP ; if w pressed jump to MOVE_UP 

	
	mov bl, 1Fh ; bl = scan code of s
	cmp bl, al ; compare al and bl
	je player1_MOVE_DOWN ; if s pressed jump to MOVE_IN 
	
	
	mov bl, 48h ; bl = scan code of up arrow
	cmp bl, al ; compare al and bl
	je PLAYER2_MOVE_UP ; if s pressed jump to MOVE_IN 
	
	
	mov bl, 50h ; bl = scan code of s
	cmp bl, al ; compare al and bl
	je player2_MOVE_DOWN ; if s pressed jump to MOVE_IN 
	
	
	jmp DONE ; if nothing was pressed
	
PLAYER1_MOVE_UP:
	mov ax, 0320d ; check if the player is on the highest row
	mov bx, PLAYER1_POSy
	cmp ax, bx
	je DONE ; if he did jump to DONE
	
	
	call clearPlayer1 ; clear the player from the screen
	mov bx, PLAYER_VEL_Y
	sub ds:[PLAYER1_POSy], bx ; update his place
	jmp DONE ; jump to DONE

	
PLAYER1_MOVE_DOWN:
	mov ax, 3520d ; check if the player is on the lowest row
	mov bx, PLAYER1_POSy
	cmp ax, bx
	je DONE ; if he did jump to DONE
	
	
	call clearPlayer1 ; clear the player from the screen
	mov bx, PLAYER_VEL_Y
	add ds:[PLAYER1_POSy], bx ; update his place
	jmp DONE ; jump to DONE
	
	
PLAYER2_MOVE_UP:
	mov ax, 0320d ; check if the player is on the highest row
	mov bx, PLAYER2_POSy
	cmp ax, bx
	je DONE ; if he did jump to DONE
	
	
	call clearPlayer2 ; clear the player from the screen
	mov bx, PLAYER_VEL_Y
	sub ds:[PLAYER2_POSy], bx ; update his place
	jmp DONE ; jump to DONE
	
	
PLAYER2_MOVE_DOWN:
	mov ax, 3520d ; check if the player is on the lowest row
	mov bx, PLAYER2_POSy
	cmp ax, bx
	je DONE ; if he did jump to DONE
	
	
	call clearPlayer2 ; clear the player from the screen
	mov bx, PLAYER_VEL_Y
	add ds:[PLAYER2_POSy], bx ; update his place
	jmp DONE ; jump to DONE
	

DONE:
	ret
keyboardHandler ENDP


; this function move the ball according to his velovity and his cordinates
MoveBall PROC uses ax bx
	mov ds:[clock_ticks], 2d ; control the speed of the ball, as it will be bigger the game will be faster
	
	call ClearBall
	call HandleScoring
	
	; Ball movement logic 
	mov bl, BALL_DIRECTION_INDICATOR_X	
	mov bh, 0d ; check if the ball move to the left or to the right
	cmp bl, bh
	je MOVE_BALL_RIGHT ; if move to the right jump to that case

MOVE_BALL_LEFT:
	mov bl, BALL_DIRECTION_INDICATOR_Y	
	mov bh, 0d
	cmp bl, bh

	je MOVE_BALL_LEFT_AND_DOWN


MOVE_BALL_LEFT_AND_UP:	; if the ball should move up and left
	mov bx, BALL_VEL_X
	sub ds:[BALL_POSx], bx ; move the ball in x scale
	mov bx, BALL_VEL_Y
	sub ds:[BALL_POSy], bx ; move the ball in y scale
	
	call CheckCollisonWithPaddle1
	
	call CheckCollisonWithTheUpperLimit
	
	call CheckCollisionWithLeftPortalGate
	call CheckCollisionWithRightPortalGate
	
	jmp DONE_MOVE_BALL
	
MOVE_BALL_LEFT_AND_DOWN: ; if the ball should move down and left
	
	mov bx, BALL_VEL_X
	sub ds:[BALL_POSx], bx ; move the ball in x scale
	mov bx, BALL_VEL_Y
	add ds:[BALL_POSy], bx ; move the ball in y scale
	
	call CheckCollisonWithPaddle1
	
	call CheckCollisonWithTheLowerLimit
	
	call CheckCollisionWithLeftPortalGate
	call CheckCollisionWithRightPortalGate
	
	jmp DONE_MOVE_BALL
	
	
MOVE_BALL_RIGHT: ; if the ball should move right
	mov bl, BALL_DIRECTION_INDICATOR_Y	
	mov bh, 0d
	cmp bl, bh

	je MOVE_BALL_RIGHT_AND_DOWN

MOVE_BALL_RIGHT_AND_UP: ; if the ball should move right and up
	mov bx, BALL_VEL_X
	add ds:[BALL_POSx], bx ; move the ball in x scale
	mov bx, BALL_VEL_Y
	sub ds:[BALL_POSy], bx ; move the ball in y scale
	
	call CheckCollisonWithPaddle2
	
	call CheckCollisonWithTheUpperLimit
	
	call CheckCollisionWithLeftPortalGate
	call CheckCollisionWithRightPortalGate
	
	jmp DONE_MOVE_BALL
	
MOVE_BALL_RIGHT_AND_DOWN: ; if the ball should move down and up
	mov bx, BALL_VEL_X
	add ds:[BALL_POSx], bx ; move the ball in x scale
	mov bx, BALL_VEL_Y
	add ds:[BALL_POSy], bx ; move the ball in y scale
	
	call CheckCollisonWithPaddle2
	
	call CheckCollisonWithTheLowerLimit
	
	call CheckCollisionWithLeftPortalGate
	call CheckCollisionWithRightPortalGate
	
DONE_MOVE_BALL:
	
	call PrintBall
	call PrintScore
	call PrintPortalGates
	mov ds:[PORTAL_COOLDOWN_FLAG], 0 ; Reset portal cooldown
	ret
MoveBall ENDP


; this function clear the ball from the screend
ClearBall PROC uses ax bx cx
	mov cx, 78d
	mov bx, BALL_POSx ; bx now is the position of the ball
	
	cmp bx, cx
	je FixMiddleLine
	
	add bx, BALL_POSy
	mov ax, 20DBh ; define black block
	mov es:[bx], ax
	jmp DoneClearBall
	
FixMiddleLine:
	add bx, BALL_POSy
	mov al, '|' ; define white line
	mov ah, 0Fh
	mov es:[bx], ax
	
DoneClearBall:
	ret
ClearBall ENDP


; this function check if the ball hit paddle1, if it did it return the ball to thr right and up\down (depends where it hit)
CheckCollisonWithPaddle1 PROC uses ax bx 
	mov ax, PLAYER1_POSx
	add ax, 2d
	mov bx, BALL_POSx
	cmp ax, bx
	jne DONE_COLLISON_PADDLE1
	
	; check if the ball hit middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER1_POSy
	
	cmp ax, bx
	jne NO_COLLISON_WITH_MIDDLE
	
	; this is the case where the ball hit the middle of the screen, it returns the ball left with same velocity
	inc centerHitsPlayer1Units
	cmp centerHitsPlayer1Units, 10
	jne SkipCenterHitsPlayer1TensIncrement
	
	mov centerHitsPlayer1Units, 0
	inc centerHitsPlayer1Tens
	
SkipCenterHitsPlayer1TensIncrement:

	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 0d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; change the ball's direction in x
	mov BALL_COLOR, 0Bh
	
	jmp DONE_COLLISON_PADDLE1
	
NO_COLLISON_WITH_MIDDLE:
	; check if the ball hit one below the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER1_POSy
	add bx, 160d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_PLUS_ONE1
	
	; this is the case where the ball hit one below the middle of the screen, it returns the ball left with same velocity in x and more velocity in y
	call IncCornerCounterPlayer1
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; change the ball's direction in x
	mov BALL_COLOR, 0Ch

NO_COLLISON_WITH_MIDDLE_PLUS_ONE1:
	; check if the ball hit two below the middle of the paddle
	
	mov ax, BALL_POSy
	mov bx, PLAYER1_POSy
	add bx, 320d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_PLUS_TWO1
	
	; this is the case where the ball hit two below the middle of the screen, it returns the ball right with more velocity in both scales
	call IncCornerCounterPlayer1
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; change the ball's direction in x
	mov BALL_COLOR, 0Ch
	
	
NO_COLLISON_WITH_MIDDLE_PLUS_TWO1:
	; check if the ball hit one above the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER1_POSy
	sub bx, 160d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_MINUS_ONE1
	
	; this is the case where the ball hit one above the middle of the screen, it returns the ball left with same velocity in x and more velocity in y
	call IncCornerCounterPlayer1
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; change the ball's direction in x
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 1h ; and also n y
	mov BALL_COLOR, 0Ch


NO_COLLISON_WITH_MIDDLE_MINUS_ONE1:
	; check if the ball hit two above the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER1_POSy
	sub bx, 320d
	
	cmp ax, bx
	
	jne DONE_COLLISON_PADDLE1
	
	; this is the case where the ball hit two above the middle of the screen, it returns the ball right with more velocity in both scales
	call IncCornerCounterPlayer1
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; change the ball's direction in x
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 1h ; and also n y
	mov BALL_COLOR, 0Ch


DONE_COLLISON_PADDLE1:
	ret
CheckCollisonWithPaddle1 ENDP


; this function check if the ball hit paddle2, if it did it return the ball to the left and up\down (depends where it hit)
CheckCollisonWithPaddle2 PROC uses ax bx
	mov ax, PLAYER2_POSx
	mov bx, BALL_POSx
	cmp ax, bx
	jne DONE_COLLISON_PADDLE2
	
	; check if the ball hit middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER2_POSy
	
	cmp ax, bx
	jne NO_COLLISON_WITH_MIDDLE2
	
	; this is the case where the ball hit the middle of the screen, it returns the ball left with same velocity
	inc centerHitsPlayer2Units
	cmp centerHitsPlayer2Units, 10
	jne SkipCenterHitsPlayer2TensIncrement
	
	mov centerHitsPlayer2Units, 0
	inc centerHitsPlayer2Tens
	
SkipCenterHitsPlayer2TensIncrement:
	
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 0d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; change the ball's direction in x
	mov BALL_COLOR, 0Bh
	
	jmp DONE_COLLISON_PADDLE2
	
NO_COLLISON_WITH_MIDDLE2:
	; check if the ball hit one below the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER2_POSy
	add bx, 160d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_PLUS_ONE2
	
	; this is the case where the ball hit one below the middle of the screen, it returns the ball left with same velocity in x and more velocity in y
	call IncCornerCounterPlayer2
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; change the ball's direction in x
	mov BALL_COLOR, 0Ch


NO_COLLISON_WITH_MIDDLE_PLUS_ONE2:
	; check if the ball hit two below the middle of the paddle
	
	mov ax, BALL_POSy
	mov bx, PLAYER2_POSy
	add bx, 320d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_PLUS_TWO2
	
	; this is the case where the ball hit two below the middle of the screen, it returns the ball left with more velocity in both scales
	call IncCornerCounterPlayer2
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; change the ball's direction in x
	mov BALL_COLOR, 0Ch
	
	
NO_COLLISON_WITH_MIDDLE_PLUS_TWO2:
	; check if the ball hit one above the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER2_POSy
	sub bx, 160d
	
	cmp ax, bx
	
	jne NO_COLLISON_WITH_MIDDLE_MINUS_ONE2
	
	; this is the case where the ball hit one above the middle of the screen, it returns the ball left with same velocity in x and more velocity in y
	call IncCornerCounterPlayer2
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; change the ball's direction in x
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 1h ; and also n y
	mov BALL_COLOR, 0Ch


NO_COLLISON_WITH_MIDDLE_MINUS_ONE2:
	; check if the ball hit two above the middle of the paddle
	mov ax, BALL_POSy
	mov bx, PLAYER2_POSy
	sub bx, 320d
	
	cmp ax, bx
	
	jne DONE_COLLISON_PADDLE2
	
	; this is the case where the ball hit two above the middle of the screen, it returns the ball left with more velocity in both scales
	call IncCornerCounterPlayer2
	mov ds:[BALL_VEL_X], 2d
	mov ds:[BALL_VEL_y], 160d
	mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; change the ball's direction in x
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 1h ; and also n y
	mov BALL_COLOR, 0Ch


DONE_COLLISON_PADDLE2:
	ret
CheckCollisonWithPaddle2 ENDP


; this function check if the ball hit the upper limit of the board, if it did it will return down
CheckCollisonWithTheUpperLimit PROC uses ax bx
	mov ax, 00d ; the upper limit
	mov bx, BALL_POSy
	cmp ax, bx ; check if the ball hit
	jne DONE_CHECK_UPPER_LIMIT ; if not jump
	
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 0d ; if it did change the ball direction in y scale

DONE_CHECK_UPPER_LIMIT:
	ret
CheckCollisonWithTheUpperLimit ENDP


; this function check if the ball hit the lower limit of the board, if it did it will return down
CheckCollisonWithTheLowerLimit PROC uses ax bx
	mov ax, 4000d ; the lower limit
	mov bx, BALL_POSy
	cmp ax, bx ; check if the ball hit
	jne DONE_CHECK_LOWER_LIMIT ; jump if not
	
	mov ds:[BALL_DIRECTION_INDICATOR_Y], 1d ; change the ball direction in y scale

DONE_CHECK_LOWER_LIMIT:
	ret
CheckCollisonWithTheLowerLimit ENDP


; this function checks collision with the left portal gate and navigate it
CheckCollisionWithLeftPortalGate PROC uses ax bx cx dx
	mov al, ds:[PORTAL_COOLDOWN_FLAG]
    cmp al, 1 ; Check if portal cooldown is active
    je DONE_CHECK_LEFT_PORTAL ; If cooldown is active, skip portal check

	mov ax, 42d ; Left portal x-coordinate (constant for all y-values)
	mov dx, BALL_POSx ; Load ball's x-coordinate
	cmp ax, dx ; Compare ball's x-coordinate with left portal's x-coordinate
	jne DONE_CHECK_LEFT_PORTAL ; If x-coordinate doesn't match, exit

	; If x-coordinate matches, check y-coordinate
	mov bx, BALL_POSy ; Load ball's y-coordinate
	mov cx, 3 ; Length of portal (3 pixels in y)
	
rightPortalLoop:
	cmp bx, 640d ; Compare ball's y-coordinate with the first portal y-position
	je TELEPORT_RIGHT_PORTAL

	cmp bx, 800d ; Compare with the second y-position
	je TELEPORT_RIGHT_PORTAL

	cmp bx, 960d ; Compare with the third y-position
	je TELEPORT_RIGHT_PORTAL

	; If no match, exit
	jmp DONE_CHECK_LEFT_PORTAL

TELEPORT_RIGHT_PORTAL:
	mov al, BALL_DIRECTION_INDICATOR_X
	cmp al, 1 ; 0=right, 1=left
	je BallMovingLeft
	
	call IncPortalCounterPlayer1 ; o.w moving right, so increament
	jmp ContinueTeleport
	
BallMovingLeft:
	call IncPortalCounterPlayer2
	
ContinueTeleport:
	; Ball is at the left portal, teleport it to the right portal
	; Teleport to the right portal based on current y
	
	mov ax, ds:[BALL_POSy] ; keep the current y pos of the ball
	add ax, 1760d ; y distance from left portal to right portal
	mov ds:[BALL_POSy], ax
	
	mov ds:[BALL_POSx], 118d
	
	mov ds:[PORTAL_COOLDOWN_FLAG], 1 ; Set portal cooldown flag

DONE_CHECK_LEFT_PORTAL:
	ret
CheckCollisionWithLeftPortalGate ENDP


; this function checks collision with the right portal gate and navigate it 
CheckCollisionWithRightPortalGate PROC uses ax bx cx dx
	mov al, ds:[PORTAL_COOLDOWN_FLAG]
    cmp al, 1 ; Check if portal cooldown is active
    je DONE_CHECK_LEFT_PORTAL ; If cooldown is active, skip portal check

	mov ax, 118d ; Right portal x-coordinate (constant for all y-values)
	mov dx, BALL_POSx ; Load ball's x-coordinate
	cmp ax, dx ; Compare ball's x-coordinate with right portal's x-coordinate
	jne DONE_CHECK_RIGHT_PORTAL ; If x-coordinate doesn't match, exit

	; If x-coordinate matches, check y-coordinate
	mov bx, BALL_POSy ; Load ball's y-coordinate
	mov cx, 3 ; Length of portal (3 pixels in y)
	
leftPortalLoop:
	cmp bx, 2400d ; Compare ball's y-coordinate with the first portal y-position
	je TELEPORT_LEFT_PORTAL

	cmp bx, 2560d ; Compare with the second y-position
	je TELEPORT_LEFT_PORTAL

	cmp bx, 2720d ; Compare with the third y-position
	je TELEPORT_LEFT_PORTAL

	; If no match, exit
	jmp DONE_CHECK_RIGHT_PORTAL

TELEPORT_LEFT_PORTAL:
	mov al, BALL_DIRECTION_INDICATOR_X
	cmp al, 0 ; 0=right, 1=left
	je BallMovingRight 
	
	call IncPortalCounterPlayer2 ; o.w moving left, so increament
	jmp ContinueTeleport
	
BallMovingRight:
	call IncPortalCounterPlayer1
	
ContinueToTeleport:
	; Ball is at the right portal, teleport it to the left portal
	; Teleport to the left portal based on current y
	
	mov ax, ds:[BALL_POSy] ; keep the current y pos of the ball
	sub ax, 1760d ; y distance between portals
	mov ds:[BALL_POSy], ax
	
	mov ds:[BALL_POSx], 42d
	
	mov ds:[PORTAL_COOLDOWN_FLAG], 1 ; Set portal cooldown flag

DONE_CHECK_RIGHT_PORTAL:
	ret
CheckCollisionWithRightPortalGate ENDP


; this function handles the scoring logic
HandleScoring PROC uses ax bx
	; Check if Player 2 scored
    mov ax, PLAYER1_POSx
    cmp ds:[BALL_POSx], ax
    jl Player2Scored ; Ball is to the left of Player 1's paddle
	
	; Check if Player 1 scored
    mov ax, PLAYER2_POSx
    cmp ds:[BALL_POSx], ax
    jg Player1Scored ; Ball is to the right of Player 2's paddle
	
	jmp NoGoal ; No goal was scored
	
Player1Scored:
    inc ds:[PLAYER1_SCORE]
	mov ax, [totalPoints]
	mov bx, [purpleBallPoints]
	cmp ax, bx
	jne NotPurple1
	
	inc ds:[PLAYER1_SCORE]

NotPurple1:
	
	inc ds:[totalPoints]
	call PrintScore ; update the score on the screen
    call ResetBall ; Reset the ball to the center
    
	; Set the ball's direction and velocity towards Player 2
    mov ds:[BALL_VEL_X], 2d ; Set the ball velocity in the X direction (positive, moving right)
    mov ds:[BALL_VEL_Y], 0d ; No vertical movement, straight line
    mov ds:[BALL_DIRECTION_INDICATOR_X], 0h ; Ball moves right
    mov ds:[BALL_DIRECTION_INDICATOR_Y], 0h ; No vertical movement
	
    jmp CheckGameEnd

Player2Scored:
    inc ds:[PLAYER2_SCORE]
	mov ax, [totalPoints]
	mov bx, [purpleBallPoints]
	cmp ax, bx
	jne NotPurple2
	
	inc ds:[PLAYER2_SCORE]

NotPurple2:
	inc ds:[totalPoints]
    call PrintScore ; update the score on the screen
	call ResetBall ; Reset the ball to the center
    
	; Set the ball's direction and velocity towards Player 1
    mov ds:[BALL_VEL_X], 2d ; Set the ball velocity in the X direction (positive, moving left)
    mov ds:[BALL_VEL_Y], 0d ; No vertical movement, straight line
    mov ds:[BALL_DIRECTION_INDICATOR_X], 1h ; Ball moves left
    mov ds:[BALL_DIRECTION_INDICATOR_Y], 0h ; No vertical movement
	
    jmp CheckGameEnd

CheckGameEnd:
    mov al, 5 ; Check if any player reached 5 points
    cmp ds:[PLAYER1_SCORE], al
    je EndGame
    cmp ds:[PLAYER2_SCORE], al
    je CallEndGame
    jmp NoGoal

CallEndGame:
	call EndGame
	ret

NoGoal:
    ret
HandleScoring ENDP


; this function resets the ball position to the center after scoring a goal
ResetBall PROC
    mov ds:[BALL_POSx], 4Eh
	mov ds:[BALL_POSy], 0780h
    ret
ResetBall ENDP


; this funciton prints/updates the players score on the screen
PrintScore PROC uses ax bx si
    ; Print Player 1's Score
    mov al, ds:[PLAYER1_SCORE] ; Load Player 1's score
    add al, 30h ; Convert score to ASCII ('0' to '9')
    mov ah, 0Fh ; Set the attribute for the character (bright white on black)
    mov bx, PLAYER1_SCORE_POS ; Screen position for Player 1's score
    mov es:[bx], ax ; Print Player 1's score

    ; Print Player 2's Score
    mov al, ds:[PLAYER2_SCORE] ; Load Player 2's score
    add al, 30h ; Convert score to ASCII
    mov ah, 0Fh ; Set the attribute for the character (bright white on black)
    mov bx, PLAYER2_SCORE_POS ; Screen position for Player 2's score
    mov es:[bx], ax ; Print Player 2's score

    ret
PrintScore ENDP


; this function handles the EndGame prints and logic
EndGame PROC uses ax bx cx si 
	; Print "GAME OVER" on the screen
    mov cx, 9 ; Length of "GAME OVER"
    mov bx, 1030d ; Starting position in the middle of the screen
    mov si, offset GameOverMsg ; Offset to the "GAME OVER" string

PrintGameOver:
    lodsb ; Load next character from the string
    mov ah, 0Fh ; Set the attribute for the character (bright white on black)
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
	dec cx
    jnz PrintGameOver
	
	; Print "Player 1 won" or "Player 2 won" below "GAME OVER"
    cmp ds:[PLAYER1_SCORE], 5
    je Player1Won

    cmp ds:[PLAYER2_SCORE], 5
    je Player2Won
	
Player1Won:
    mov cx, 16 ; Length of "Blue Player Won!"
    mov bx, 1184d ; Position under "GAME OVER"
    mov si, offset Player1WonMsg ; Offset to the "Player 1 won" string
	mov ah, 01h ; blue on black
    jmp PrintWinner

Player2Won:
    mov cx, 15 ; Length of "Red Player Won!"
    mov bx, 1184d ; Position under "GAME OVER"
    mov si, offset Player2WonMsg ; Offset to the "Player 2 won" string
	mov ah, 04h ; red on black

PrintWinner:
    lodsb ; Load next character from the string
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
    dec cx
    jnz PrintWinner
	
	call PrintStats

	; Halt the game or loop indefinitely
    jmp $
EndGame ENDP


; this function handles increaments the corner hits of player1
IncCornerCounterPlayer1 PROC
	inc cornerHitsPlayer1Units
	cmp cornerHitsPlayer1Units, 10
	jne DONE_INC_CORNER_PLAYER1	
	
	mov cornerHitsPlayer1Units, 0
	inc cornerHitsPlayer1Tens
	
DONE_INC_CORNER_PLAYER1:
	ret
IncCornerCounterPlayer1 ENDP


; this function handles increaments the corner hits of player2
IncCornerCounterPlayer2 PROC
	inc cornerHitsPlayer2Units
	cmp cornerHitsPlayer2Units, 10
	jne DONE_INC_CORNER_PLAYER2
	
	mov cornerHitsPlayer2Units, 0
	inc cornerHitsPlayer2Tens
	
DONE_INC_CORNER_PLAYER2:
	ret
IncCornerCounterPlayer2 ENDP


; this function handles increaments the portal passes of player1
IncPortalCounterPlayer1 PROC
	inc portalPassPlayer1Units
	cmp portalPassPlayer1Units, 10
	jne DONE_INC_PORTAL_PLAYER1	
	
	mov portalPassPlayer1Units, 0
	inc portalPassPlayer1Tens
	
DONE_INC_PORTAL_PLAYER1:
	ret
IncPortalCounterPlayer1 ENDP


; this function handles increaments the portal passes of player2
IncPortalCounterPlayer2 PROC
	inc portalPassPlayer2Units
	cmp portalPassPlayer2Units, 10
	jne DONE_INC_PORTAL_PLAYER2
	
	mov portalPassPlayer2Units, 0
	inc portalPassPlayer2Tens
	
DONE_INC_PORTAL_PLAYER2:
	ret
IncPortalCounterPlayer2 ENDP


; this function prints game statistics to the screen at the end of the game
PrintStats PROC uses ax bx cx si
; Stats title:
	mov cx, 15 ; Length of "Game Statistics"
	mov bx, 1504d
	mov si, offset GameStatisticsTitle
	mov ah, 7Eh ; brown on white
PrintStatsTitle:
	lodsb ; Load next character from the string
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
    dec cx
	jnz PrintStatsTitle

; Print Frame for game stats
	mov cx, 34
	mov bx, 1324d
	mov al, '-'
	mov ah, 0Fh ; white on black
PrintStatsUpperAndLowerFrame:
	mov es:[bx], ax ; print upper
	add bx, 800d
	mov es:[bx], ax ; print lower
	sub bx, 800d
	add bx, 2d ; next print
	dec cx
	jnz PrintStatsUpperAndLowerFrame
	
	mov cx, 6
	mov bx, 1322d
	mov al, '|'
	mov ah, 0Fh ; white on black
PrintStatsLeftAndRightFrame:
	mov es:[bx], ax ; print left
	add bx, 70d
	mov es:[bx], ax ; print right
	sub bx, 70d
	add bx, 160d ; next print
	dec cx
	jnz PrintStatsLeftAndRightFrame

; Corner Hits:
	mov cx, 12 ; Length of "Corner Hits:"
	mov bx, 1646d
	mov si, offset CornerHitsMsg
	mov ah, 0Eh ; brown on black
PrintCornerHitsStat:
	lodsb ; Load next character from the string
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
    dec cx
	jnz PrintCornerHitsStat

	mov al, cornerHitsPlayer1Units
	add al, '0' ; number to ASCII
	mov ah, 01h ; blue on black
	mov bx, 1674d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp cornerHitsPlayer1Tens, 0
	je AFTER_TENS_CORNER_PL1
	mov al, cornerHitsPlayer1Tens
	add al, '0' ; number to ASCII	
	mov es:[bx], ax

AFTER_TENS_CORNER_PL1:

	mov al, cornerHitsPlayer2Units
	add al, '0' ; number to ASCII
	mov ah, 04h ; red on black
	add bx, 12d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp cornerHitsPlayer2Tens, 0
	je AFTER_TENS_CORNER_PL2
	mov al, cornerHitsPlayer2Tens
	add al, '0' ; number to ASCII
	mov es:[bx], ax

AFTER_TENS_CORNER_PL2:	

; Center Hits:
	mov cx, 12 ; Length of "Center Hits:"
	mov bx, 1806d
	mov si, offset CenterHitsMsg
	mov ah, 0Eh ; brown on black
PrintCenterHitsStat:
	lodsb ; Load next character from the string
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
    dec cx
	jnz PrintCenterHitsStat

	mov al, centerHitsPlayer1Units
	add al, '0' ; number to ASCII
	mov ah, 01h ; blue on black
	mov bx, 1834d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp centerHitsPlayer1Tens, 0
	je AFTER_TENS_CENTER_PL1
	mov al, centerHitsPlayer1Tens
	add al, '0' ; number to ASCII
	mov es:[bx], ax

AFTER_TENS_CENTER_PL1:
	
	mov al, centerHitsPlayer2Units
	add al, '0' ; number to ASCII
	mov ah, 04h ; red on black
	add bx, 12d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp centerHitsPlayer2Tens, 0
	je AFTER_TENS_CENTER_PL2
	mov al, centerHitsPlayer2Tens
	add al, '0' ; number to ASCII
	mov es:[bx], ax

AFTER_TENS_CENTER_PL2:

; Portal pass:
	mov cx, 12 ; Length of "Portal Pass:"
	mov bx, 1966d
	mov si, offset PortalPassMsg
	mov ah, 0Eh ; brown on black
PrintPortalPassStat:
	lodsb ; Load next character from the string
    mov es:[bx], ax ; Print character at current screen position
    add bx, 2 ; Move to the next character position on the screen
    dec cx
	jnz PrintPortalPassStat

	mov al, portalPassPlayer1Units
	add al, '0' ; number to ASCII
	mov ah, 01h ; blue on black
	mov bx, 1994d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp portalPassPlayer1Tens, 0
	je AFTER_TENS_PORTAL_PL1	
	mov al, portalPassPlayer1Tens
	add al, '0' ; number to ASCII
	mov es:[bx], ax

AFTER_TENS_PORTAL_PL1:

	mov al, portalPassPlayer2Units
	add al, '0' ; number to ASCII
	mov ah, 04h ; red on black
	add bx, 12d
	mov es:[bx], ax
	
	sub bx, 2d
	cmp portalPassPlayer2Tens, 0
	je AFTER_TENS_PORTAL_PL2
	mov al, portalPassPlayer2Tens
	add al, '0' ; number to ASCII
	mov es:[bx], ax

AFTER_TENS_PORTAL_PL2:

	ret
PrintStats ENDP


START:
	mov ax, @data
	mov ds, ax ; load the ds
	mov ax, 0b800h 
	mov es, ax ; place the screen to es
			
	call printGameWindow ; print the black window for the game
	
	call PrintScore ; Print 0-0
	
	call StartTime
	
	in al, 21h ; this 3 lines are for stop the keyboard interupts
	or al, 02h
	out 21h, al

PollKeyboard:
	call PrintPlayer1
	call PrintPlayer2
	
	in al, 64h ; this 3 lines check if a key was pressed or released
	test al, 01
	jz PollKeyboard
	
	in al, 60h ; take the value that was pressed
		
	call keyboardHandler ; call the handler to handle with the key that been pressed
	
	jmp PollKeyboard ; go back
	
	call StopTime ; call the stop time function
	mov ah, 4ch ; return to os
	int 21h

end START
	
	