.file "src/game/game.s"

.global gameInit
.global gameLoop

.section .game.data
### ***** GENERAL DATA ***** ###
# the number of the current scene
sceneNumber:		.byte	0
# a random number
randomNumber:		.byte	0
# exiting the program
outWordExit1:		.word 	0x0604
outWordExit2:		.word 	0x2000

### ***** MAIN MENU DATA ***** ###
isPrintedMainMenu:		.byte	0
TextMainMenu:			.asciz	""
						.asciz	"                                   MAIN MENU:"
						.asciz	""
						.ascii	"  PREVIOUS GAME SCORE:               " 
previousScorePlayer1:	.byte	48
						.ascii	" - "
previousScorePlayer2:	.Byte	48
						.asciz	""
						.asciz	""
						.asciz	"  RULES:   A ball will be spawned in the center of the screen with a random"
						.asciz	"           direction. Each player has to try to keep the ball from going past"
						.asciz	"           their paddle. If a ball is let through, the scoring player gets"
						.asciz	"           one point. first to 8 points wins. good luck and have fun!"
						.asciz	""
						.asciz	"  CONTROLS:  W/S               = up/down   (player 1)"
						.asciz	"             upArrow/downArrow = up/down   (player 2)"
						.asciz	""
						.asciz	"             to start the game: press 'enter'"
						.asciz	""
						.asciz	"             to pause the game: press 'p'"
						.asciz	""
						.asciz	"             to go to the main menu: press 'm'"
						.asciz	""
						.asciz	"             to exit the program: press 'esc'"
						.asciz	""
						.asciz	""
						.asciz	"  made by: Niwan van den Berch van Heemstede"
						.asciz	"  creation date: 12 October 2024"
						.asciz	""				

### ***** GAME DATA ***** ###
# p was pressed
pWasPressed:		.byte	0
# game is paused
isGamePaused:		.byte	0
# player input
player1Input:		.byte	0
player2Input:		.byte	0
# player score
player1Score:		.byte	0
player2Score:		.byte	0
# paddle location
paddle1Location:	.byte	0
paddle2Location:	.byte	0
# player paddle moved
player1Moved:		.byte	0
player2Moved:		.byte	0
# last ball location
lastBallX:			.byte	0
lastBallY:			.byte	0
# ball location
ballX:				.byte	0
ballY:				.byte	0
# ball next location
ballNextX:			.byte	0
ballNextY:			.byte	0
# ball precise location
ballPreciseX:		.quad	0
ballPreciseY:		.quad	0
# ball next precise location
ballNextPreciseX:	.quad	0
ballNextPreciseY:	.quad	0
# ball angle
ballAngle:			.byte	0
# ball hit location to angle
ballHitToAngle:		.byte	0,2,4,6,5,3,1
# distance multiplier for coresponding angle
multiplierX:		.quad	 447,447, 707,707, 894,894,1000,1000,-447,-447,-707,-707,-894,-894,-1000,-1000
multiplierY:		.quad	-894,894,-707,707,-447,447,0,   0,   -894, 894,-707, 707,-447, 447, 0,    0
# ball speed
ballSpeed:			.quad	0
# ball speed increase per bounce
ballSpeedInc:		.byte	0

.section .game.text

gameInit:
	enter	$0, $0

	# disable the cursor
	call	disableCursor

	# reset key flags
	call	resetFlags

	# set start scene to main menu
	movq	$0, %rax
	movb	%al, isPrintedMainMenu
	movb	%al, sceneNumber

	leave
	ret

gameLoop:
	enter	$0, $0

	# body of the program ***************************************

	### increase random number
	movb	randomNumber, %al
	incb	%al
	andb	$0x0F, %al
	movb	%al, randomNumber

	### handle scenes
	cmpb	$0, sceneNumber
	jne		1f
	# does one cycle of the main menu scene
	call	sceneMainMenu
	jmp		2f
	1:

	cmpb	$1, sceneNumber
	jne		1f
	# does one cycle of the game scene
	call	sceneGame
	jmp		2f
	1:
	2:
	
	# ***********************************************************
	
	leave
	ret

# *******************************************************************************
# * Subroutine: void disableCursor()											*
# * variables: no parameters and no return										*
# * description: disables the cursor											*
# *******************************************************************************
disableCursor:
	enter	$0, $0
	pushf	# push the flags onto the stack
	pushq 	%rax
	pushq 	%rdx

	movw 	$0x03D4, %dx 
	movb 	$0x0A, %al 		# low cursor shape register
	out 	%al, %dx

	incw 	%dx
	movb 	$0x20, %al 		# bits 6-7 unused, bit 5 disables the cursor, bits 0-4 control the cursor shape
	out 	%al, %dx

	popq 	%rdx
	popq 	%rax
	popf	# retrieve the flags from the stack
	leave
	ret

# *******************************************************************************
# * Subroutine: void sceneMainMenu()											*
# * variables: no parameters and no return										*
# * description: does a single main menu cycle									*
# *******************************************************************************
sceneMainMenu:
	enter	$0, $0

	# check if main menu is printed, if not, print it
	movb	isPrintedMainMenu, %al
	cmpb	$1, %al
	je		1f
	call 	printMainMenuText
	1:
	
	# check if escape is pressed
	movq	$0, %rax
	movq	$0x01, %rdi
	call	ps2_getFlag
	cmpq	$1, %rax
	jne		1f

	# shutdown QEMU by outputting 0x2000 in the I/O port 0x604
	movw 	$0x2000, %ax
	movw 	$0x604, %dx
	outw 	%ax, %dx
	1:

	# check if enter is pressed
	movq	$0, %rax
	movq	$0x1C, %rdi
	call	ps2_getFlag
	cmpq	$1, %rax
	jne		1f

	movb	$0, isPrintedMainMenu
	movb	$1, sceneNumber
	call	resetGame
	1:

	leave
	ret

# *******************************************************************************
# * Subroutine: void printMainMenuText()										*
# * variables: no parameters and no return										*
# * description: prints the main menu text										*
# *******************************************************************************
printMainMenuText:
	enter	$0, $0
	
	call	clearScreen

	# ***** loop over and print all the text for the main menu *****

	# get the correct line address
	movq	$TextMainMenu, %r10

	# loops
	movq	$0, %r8		# i = 0
	1:
	cmpq	$25, %r8	# i < 25
	jge		2f			# end loop if not

	movq	$0, %r9		# j = 0
	3:
	cmpq	$80, %r9	# j < 80
	jge		4f			# end loop if not

	# current character
	movb	(%r10), %r11b

	# get next character
	incq	%r10

	# check if the current character is termination char
	cmpb	$0, %r11b
	je 		4f

	# print space char at (x,y) = (j,i)
	movb	%r11b, %dl
	movq	%r9 , %rdi
	movq	%r8, %rsi
	movb	$0x0f, %cl
	call	putChar

	incq	%r9			# j++
	jmp		3b			# loop
	4:

	incq	%r8			# i++
	jmp		1b			# loop

	2: # ***********************************************************

	# set is printed to true
	movb	$1, %al
	movb	%al, isPrintedMainMenu

	leave
	ret

# *******************************************************************************
# * Subroutine: void sceneGame()												*
# * variables: no parameters and no return										*
# * description: does a single game cycle										*
# *******************************************************************************
sceneGame:
	enter	$0, $0
	
	# handle pausing and going to the menu
	call	otherInputHandler
	movb	isGamePaused, %al
	cmpb	$1, %al
	je		9f

	### get inputs
	call	getPlayerInput

	### move paddles
	call	movePaddles

	### physics/calculation
	# check collisions
	call	ballCollision
	
	# actually set the next ball location
	call	getNextBallLocation
	call	setBallLocation

	### draw screen
	call	drawScreen
	
	# reset input
	movq 	$1, %rax
	movb	%al, player1Input
	movb	%al, player2Input

	9:
	leave
	ret

# *******************************************************************************
# * Subroutine: void resetRound()												*
# * variables: no parameters and no return										*
# * description: resets the round												*
# *******************************************************************************
resetRound:
	enter	$0, $0
	
	# ********** reset round **********

	# reset player inputs
	movb 	$1, %al
	movb	%al, player1Input
	movb	%al, player2Input
	
	# set paddle locations
	movb 	$10, %al
	movb	%al, paddle1Location
	movb	%al, paddle2Location

	# set ball speed
	movq 	$250, %rax
	movq	%rax, ballSpeed
	
	# set ball speed increase
	movb 	$20, %al
	movb	%al, ballSpeedInc

	# set start ball angle
	movb 	randomNumber, %al
	movb 	%al, %ah
	andb	$6, %ah			# and 0000 0110 and ah to check for line angle
	cmpb	$6, %ah
	jne		1f
	andb	$13, %al		# and 0000 1101 to make it not a line angle (4,5,12,13)
	1:
	movb	%al, ballAngle
	
	# set ball location
	movb	$20, ballX
	movb	$12, ballY

	# set correct precise location
	movq	ballX, %rax
	shlq	$20, %rax
	movq	%rax, ballPreciseX
	movq	ballY, %rax
	shlq	$20, %rax
	movq	%rax, ballPreciseY

	# set next ball location
	call 	getNextBallLocation

	# reset screen
	call	clearScreen
	call	drawScreen
	
	# *********************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void resetGame()												*
# * variables: no parameters and no return										*
# * description: resets the game												*
# *******************************************************************************
resetGame:
	enter	$0, $0
	
	# ********** reset round **********
	
	# reset player scores
	movb 	$0, %al
	movb	%al, player1Score
	movb	%al, player2Score

	# game is paused = false
	movb	$0, isGamePaused

	# reset round
	call	resetRound
	
	# *********************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void otherInputHandler()										*
# * variables: no parameters and no return										*
# * description: handles pausing and going to the menu							*
# *******************************************************************************
otherInputHandler:
	enter	$0, $0

	# check if escape is pressed
	movq	$0, %rax
	movq	$0x01, %rdi
	call	ps2_getFlag
	cmpq	$1, %rax
	jne		1f

	# shutdown QEMU by outputting 0x2000 in the I/O port 0x604
	movw 	$0x2000, %ax
	movw 	$0x604, %dx
	outw 	%ax, %dx
	1:
	
	# check if 'm' is pressed
	movq	$0, %rax
	movq	$0x32, %rdi
	call	ps2_getFlag
	cmpq	$1, %rax
	jne		1f

	# set previous player scores
	movb	player1Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer1
	movb	player2Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer2
	# go to main menu
	movb	$0, sceneNumber
	1:
	
	# check if 'p' is pressed
	movq	$0, %rax
	movq	$0x19, %rdi
	call	ps2_getFlag
	cmpq	$1, %rax
	jne		1f
	
	# check if p was pressed
	cmpb	$1, pWasPressed
	je		2f

	movb	$1, pWasPressed
	# flip pause state
	movb	isGamePaused, %al
	xorb	$1, %al				# flip last bit
	movb	%al, isGamePaused

	jmp		2f
	1:	# else
	movb	$0, pWasPressed
	2:

	leave
	ret

# *******************************************************************************
# * Subroutine: void getPlayerInput()											*
# * variables: no parameters and no return										*
# * description: sets the player 1 and 2 input variable to 0 for down, 1 for	*
# *				 nothing, 2 for up 												*
# *******************************************************************************
getPlayerInput:
	enter	$0, $0

	## if key down = w
	movq	$17, %rdi
	call	ps2_getFlag
	cmpq	$0, %rax
	je		5f

	movzbq	player1Input, %rax
	incq	%rax
	movb	%al, player1Input
	5:

	## if key down = s
	movq	$31, %rdi
	call	ps2_getFlag
	cmpq	$0, %rax
	je		5f

	movzbq	player1Input, %rax
	decq	%rax
	movb	%al, player1Input
	5:

	## if key down = uparrow
	movq	$72, %rdi
	call	ps2_getFlag
	cmpq	$0, %rax
	je		5f

	movzbq	player2Input, %rax
	incq	%rax
	movb	%al, player2Input
	5:

	## if key down = downarrow
	movq	$80, %rdi
	call	ps2_getFlag
	cmpq	$0, %rax
	je		5f
	
	movzbq	player2Input, %rax
	decq	%rax
	movb	%al, player2Input
	5:
	
	leave
	ret

# *******************************************************************************
# * Subroutine: void movePaddles()												*
# * variables: use: player1Input, player2Input;							 		*
# * 		   change: paddle1Location, paddle2Location							*
# * description: update paddle locations based on player inputs					*
# *******************************************************************************
movePaddles:
	enter	$0, $0

	# ********** player 1 **********
	# get and check input
	movb	player1Input, %al
	cmpb	$2, %al	# velocity is 1
	je		1f
	cmpb	$0, %al	# velocity is -1
	je		3f
	jmp		2f			# else
	1: # case player velocity is 1
	movb	paddle1Location, %r8b

	cmpb	$1, %r8b
	jle		2f			# dont move paddle up if it is at the top
	
	# move the paddle up one
	decb	%r8b
	movb	%r8b, paddle1Location
	# set player paddle moved
	movb 	$0, %al
	movb	%al, player1Moved

	jmp		4f			# end
	3: # case player velocity is -1
	movb	paddle1Location, %r8b

	cmpb	$21, %r8b
	jge		2f			# dont move paddle up if it is at the bottom
	
	# move the paddle down one
	incb	%r8b
	movb	%r8b, paddle1Location
	# set player paddle moved
	movb 	$2, %al
	movb	%al, player1Moved

	jmp		4f			# end
	2: # else
	# set player paddle not moved
	movb 	$1, %al
	movb	%al, player1Moved
	
	4: # ***************************
	
	# ********** player 2 **********
	# get and check input
	movb	player2Input, %al
	cmpb	$2, %al		# velocity is 1
	je		1f
	cmpb	$0, %al		# velocity is -1
	je		3f
	jmp		2f			# else
	1: # case player velocity is 1
	movb	paddle2Location, %r8b

	cmpb	$1, %r8b
	jle		2f			# dont move paddle up if it is at the top
	
	# move the paddle up one
	decb	%r8b
	movb	%r8b, paddle2Location
	# set player paddle moved
	movb 	$0, %al
	movb	%al, player2Moved

	jmp		4f			# end
	3: # case player velocity is -1
	movb	paddle2Location, %r8b

	cmpb	$21, %r8b
	jge		2f			# dont move paddle up if it is at the bottom
	
	# move the paddle down one
	incb	%r8b
	movb	%r8b, paddle2Location
	# set player paddle moved
	movb 	$2, %al
	movb	%al, player2Moved

	jmp		4f			# end
	2: # else
	# set player paddle not moved
	movb 	$1, %al
	movb	%al, player2Moved
	
	4: # ***************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void getNextBallLocation()										*
# * variables: no parameters and no return										*
# * description: gets the next ball location based on speed angle and curr loc	*
# *******************************************************************************
getNextBallLocation:
	enter	$0, $0

	# ********** get next x **********
	# get correct multiplier
	movq	$multiplierX, %r8
	movzbq	ballAngle, %r9
	movq	(%r8, %r9, 8), %r8

	# ball speed * multiplier
	movq	ballSpeed, %rax
	imulq	%r8

	# update location
	addq	ballPreciseX, %rax
	movq	%rax, ballNextPreciseX
	shrq	$20, %rax			# devide by 2^20
	movb	%al, ballNextX
	# ********************************
	
	# ********** get next y **********
	# get correct multiplier
	movq	$multiplierY, %r8
	movzbq	ballAngle, %r9
	movq	(%r8, %r9, 8), %r8

	# ball speed * multiplier
	movq	ballSpeed, %rax
	imulq	%r8

	# update location
	addq	ballPreciseY, %rax
	movq	%rax, ballNextPreciseY
	shrq	$20, %rax			# devide by 2^20
	movb	%al, ballNextY
	# ********************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void setBallLocation()											*
# * variables: no parameters and no return										*
# * description: sets the next ball location									*
# *******************************************************************************
setBallLocation:
	enter	$0, $0
	
	# set last X
	movb	ballX, %r8b
	movb	%r8b, lastBallX
	
	# set last Y
	movb	ballY, %r8b
	movb	%r8b, lastBallY

	# set next X
	movq	ballNextPreciseX, %r8
	movq	%r8, ballPreciseX
	movb	ballNextX, %r8b
	movb	%r8b, ballX
	
	# set next Y
	movq	ballNextPreciseY, %r8
	movq	%r8, ballPreciseY
	movb	ballNextY, %r8b
	movb	%r8b, ballY

	leave
	ret

# *******************************************************************************
# * Subroutine: void ballCollision()											*
# * variables: no parameters and no return										*
# * description: handles the ball collisions									*
# *******************************************************************************
ballCollision:
	enter	$0, $0

	# check left/right off screen
	call	ballOffScreen
	
	# get next ball location for collision checks
	call	getNextBallLocation
	# check ceiling/floor collision
	call	ballUpDownCollision

	# get next ball location for collision checks
	call	getNextBallLocation
	# check paddle collision
	call	ballPaddleCollision

	# get next ball location for collision checks
	call	getNextBallLocation
	# check ceiling/floor collision
	call	ballUpDownCollision
	
	leave
	ret

# *******************************************************************************
# * Subroutine: void ballOffScreen()											*
# * variables: no parameters and no return										*
# * description: handles the ball going off screen								*
# *******************************************************************************
ballOffScreen:
	enter	$0, $0
	
	# ***** check left/right off screen *****
	# left off screen
	movb	ballNextX, %r8b
	cmpb	$1, %r8b			# skip if not negative
	jge		1f
	# ball is off the left side of the screen

	# increase player 2 score
	movb	player2Score, %r8b
	incb	%r8b
	movb	%r8b, player2Score
	# check if game reset or round reset
	cmpb	$8, %r8b
	jge		2f

	# reset round
	call	resetRound
	jmp 1f
	2:
	# set previous player scores
	movb	player1Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer1
	movb	player2Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer2
	# go to main menu
	movb	$0, sceneNumber
	1:

	# right off screen
	movb	ballNextX, %r8b
	cmpb	$40, %r8b
	jle		1f
	# ball is off the right side of the screen

	# increase player 1 score
	movb	player1Score, %r8b
	incb	%r8b
	movb	%r8b, player1Score
	# check if game reset or round reset
	cmpb	$8, %r8b
	jge		2f

	# reset round
	call	resetRound
	jmp 1f
	2:
	# set previous player scores
	movb	player1Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer1
	movb	player2Score, %al
	addb	$48, %al			# to ascii
	movb	%al, previousScorePlayer2
	# go to main menu
	movb	$0, sceneNumber
	1:
	
	# ***************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void ballPaddleCollision()										*
# * variables: no parameters and no return										*
# * description: handles the ball collisions with the paddles					*
# *******************************************************************************
ballPaddleCollision:
	enter	$0, $0

	# ******** check paddle collision *********
	movq	$0, %r8
	# left paddle (angle = 0XXX)
	movb	ballNextX, %r8b
	cmpb	$3, %r8b
	jne		1f

	# ball is going to be in the paddle column
	movb	ballNextY, %r8b
	movb	paddle1Location, %r9b
	subb	%r9b, %r8b			# (r8 = ballNextY - paddle1Location)
	
	# jump if ball is above or below the paddle
	cmpb	$0, %r8b
	jl		1f
	cmpb	$5, %r8b
	jge		1f

	# ball is going to hit the paddle
	# add a bit of the movement to the ball
	addb	player1Moved, %r8b

	# 1 out of 4 chance
	movb	randomNumber, %al
	andb	$3, %al
	cmpb	$0, %al
	jne		2f

	# check if not already at the bottom
	cmpb	$0, %r8b
	je		2f

	decb	%r8b
	2:	
	# 1 out of 4 chance
	cmpb	$3, %al
	jne		2f

	# check if not already at the top
	cmpb	$6, %r8b
	je		2f

	incb	%r8b
	2:	

	# add speed to the ball
	movq	ballSpeed, %r9
	movzbq	ballSpeedInc, %r10
	addq	%r10, %r9
	movq	%r9, ballSpeed
	
	# convert to the correct angle
	movq	$ballHitToAngle, %r9
	movb	(%r9, %r8, 1), %r8b

	movb	%r8b, ballAngle
	1:

	# right paddle (angle = 1XXX)
	movb	ballNextX, %r8b
	cmpb	$38, %r8b
	jne		1f

	# ball is going to be in the paddle column
	movb	ballNextY, %r8b
	movb	paddle2Location, %r9b
	subb	%r9b, %r8b			# (r8 = ballNextY - paddle1Location)
	
	# jump if ball is above or below the paddle
	cmpb	$0, %r8b
	jl		1f
	cmpb	$5, %r8b
	jge		1f

	# ball is going to hit the paddle
	# add a bit of the movement to the ball
	addb	player2Moved, %r8b

	# 1 out of 4 chance
	movb	randomNumber, %al
	andb	$3, %al
	cmpb	$0, %al
	jne		2f

	# check if not already at the bottom
	cmpb	$0, %r8b
	je		2f

	decb	%r8b
	2:	
	# 1 out of 4 chance
	cmpb	$3, %al
	jne		2f

	# check if not already at the top
	cmpb	$6, %r8b
	je		2f

	incb	%r8b
	2:	

	# add speed to the ball
	movq	ballSpeed, %r9
	movzbq	ballSpeedInc, %r10
	addq	%r10, %r9
	movq	%r9, ballSpeed
	
	# convert to the correct angle
	movq	$ballHitToAngle, %r9
	movb	(%r9, %r8, 1), %r8b

	movb	%r8b, ballAngle
	addb	$8, ballAngle		# angle to the left
	1:

	# *****************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void ballUpDownCollision()										*
# * variables: no parameters and no return										*
# * description: handles the ball collisions with the floor and ceiling			*
# *******************************************************************************
ballUpDownCollision:
	enter	$0, $0

	# ***** check ceiling/floor collision *****
	# ceiling (inc angle)
	movb	ballNextY, %r8b
	cmpb	$1, %r8b
	jge		1f
	# ball is going into the ceilling
	# change the angle to down
	movb	ballAngle, %r8b
	incb	%r8b
	movb	%r8b, ballAngle
	1:

	# floor (dec angle)
	movb	ballNextY, %r8b
	cmpb	$25, %r8b
	jle		1f
	# ball is going into the floor
	# change the angle to up
	movb	ballAngle, %r8b
	decb	%r8b
	movb	%r8b, ballAngle
	1:

	# *****************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void drawScreen()												*
# * variables: no parameters and no return										*
# * description: draws the correct current frame								*
# *******************************************************************************
drawScreen:
	enter	$0, $0

	### remove ball
	call	removeBall

	### remove paddle
	call	removePaddles
	
	### draw middle line
	call	drawMiddleLine

	### draw score
	call	drawScore

	### draw paddles
	call	drawPaddles

	### draw ball
	call	drawBall

	leave
	ret

# *******************************************************************************
# * Subroutine: void clearScreen()												*
# * variables: no parameters and no return										*
# * description: clears the screen by setting every character to a black space	*
# *******************************************************************************
clearScreen:
	enter	$0, $0

	# ***** print char over entire screen *****
	movq	$0, %r8		# i = 0
	1:
	cmpq	$25, %r8	# i < 25
	jge		2f			# end loop if not

	movq	$0, %r9		# j = 0
	3:
	cmpq	$80, %r9	# j < 80
	jge		4f			# end loop if not

	# print space char at (x,y) = (j,i)
	movb	$32, %dl
	movq	%r9 , %rdi
	movq	%r8, %rsi
	movb	$0x0f, %cl
	call	putChar

	incq	%r9			# j++
	jmp		3b			# loop
	4:

	incq	%r8			# i++
	jmp		1b			# loop
	2: # *************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void drawMiddleLine()											*
# * variables: no parameters and no return										*
# * description: draws a middle line											*
# *******************************************************************************
drawMiddleLine:
	# prologue **************************************************

	# safe old base pointer
	pushq	%rbp
	# safe callee safed registers
	pushq	%r12		
	# set new base pointer at stack pointer
	movq	%rsp , %rbp

	# body of the subroutine ***********************************

	# ***** print over middle line *****
	movq	$0, %r12	# i = 0
	1:
	cmpq	$25, %r12	# i < 25
	jge		2f			# end loop if not

	# print dark grey space char at (x,y) = (39,i)
	movb	$32, %dl
	movq	$39 , %rdi
	movq	%r12, %rsi
	movb	$0x8f, %cl
	call	putChar
	
	# print dark grey space char at (x,y) = (40,i)
	movb	$32, %dl
	movq	$40 , %rdi
	movq	%r12, %rsi
	movb	$0x8f, %cl
	call	putChar

	addq	$2, %r12	# i += 2 (to skip every other pixel)
	jmp		1b			# loop
	2: # *************************************

	# epilogue **************************************************
	# clear local variables on stack
	movq	%rbp, %rsp
	# retrieve callee safed registers 
	popq	%r12
	# retrieve the old base pointer
	popq	%rbp 
	# return
	ret

# *******************************************************************************
# * Subroutine: void drawScore()												*
# * variables: player1Score and player2Score as params and no return			*
# * description: draws the player scores										*
# *******************************************************************************
drawScore:
	# prologue **************************************************

	# safe old base pointer
	pushq	%rbp
	# safe callee safed registers
	pushq	%r12		
	# set new base pointer at stack pointer
	movq	%rsp , %rbp

	# body of the subroutine ***********************************

	# ***** print ball *****

	# print left score
	movb	player1Score, %r12b
	addb	$48, %r12b				# number to ASCII
	# print light gray score char at (x,y) = (37,1)
	movb	%r12b, %dl
	movq	$36, %rdi
	movq	$1, %rsi
	movb	$0x07, %cl
	call	putChar
	
	# print right score
	movb	player2Score, %r12b
	addb	$48, %r12b				# number to ASCII
	# print light gray score char at (x,y) = (43,1)
	movb	%r12b, %dl
	movq	$43, %rdi
	movq	$1, %rsi
	movb	$0x07, %cl
	call	putChar

	# *************************************

	# epilogue **************************************************
	# clear local variables on stack
	movq	%rbp, %rsp
	# retrieve callee safed registers 
	popq	%r12
	# retrieve the old base pointer
	popq	%rbp 
	# return
	ret

# *******************************************************************************
# * Subroutine: void drawPaddles()												*
# * variables: paddle1Location and paddle2Location as params and no return		*
# * description: draws the player paddles										*
# *******************************************************************************
drawPaddles:
	enter	$0, $0

	# ***** print paddle 1 *****
	movb	$0, %r8b	# i = 0
	1:
	cmpb	$5, %r8b	# i < 5
	jge		2f			# end loop if not

	movb	paddle1Location, %r9b
	decb	%r9b
	addb	%r8b, %r9b
	# print white space char at (x,y) = (3,i + paddle1Location)
	movb	$32, %dl
	movq	$5, %rdi
	movzbq	%r9b, %rsi
	movb	$0xFF, %cl
	call	putChar

	incb	%r8b		# i++
	jmp		1b			# loop
	2: # *************************************

	# ***** print paddle 2 *****
	movb	$0, %r8b	# i = 0
	1:
	cmpb	$5, %r8b	# i < 5
	jge		2f			# end loop if not

	movb	paddle2Location, %r9b
	decb	%r9b
	addb	%r8b, %r9b
	# print white space char at (x,y) = (3,i + paddle2Location)
	movb	$32, %dl
	movq	$74, %rdi
	movzbq	%r9b, %rsi
	movb	$0xFF, %cl
	call	putChar

	incb	%r8b		# i++
	jmp		1b			# loop
	2: # *************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void drawBall()													*
# * variables: ballX and ballY as params and no return							*
# * description: draws the ball													*
# *******************************************************************************
drawBall:
	enter	$0, $0

	# ***** print ball *****
	# shift coordinates by -1
	movb	ballX, %r8b
	decb	%r8b
	movb	ballY, %r9b
	decb	%r9b

	# check if on screen
	cmpb	$0, %r8b
	jl		1f
	cmpb	$0, %r9b
	jl		1f
	cmpb	$40, %r8b
	jge		1f
	cmpb	$25, %r9b
	jge		1f

	# print left half of ball
	shlb	%r8b			# ballx * 2
	# print neon red space char at (x,y) = ((ballx * 2), ballY)
	movb	$32, %dl
	movzbq	%r8b, %rdi
	movzbq	%r9b, %rsi
	movb	$0xCF, %cl
	call	putChar
	
	# print right half of ball
	incb	%r8b			# (ballx * 2) + 1
	# print neon red space char at (x,y) = (((ballx * 2) + 1), ballY)
	movb	$32, %dl
	movzbq	%r8b, %rdi
	movzbq	%r9b, %rsi
	movb	$0xCF, %cl
	call	putChar
	1:

	leave
	ret

# *******************************************************************************
# * Subroutine: void removePaddles()											*
# * variables: paddle1Location and paddle2Location as params and no return		*
# * description: removes the player paddles										*
# *******************************************************************************
removePaddles:
	enter	$0, $0

	# ***** print paddle 1 *****
	movb	$0, %r8b	# i = 0
	1:
	cmpb	$25, %r8b	# i < 25
	jge		2f			# end loop if not

	# print black space char at (x,y) = (3,i + paddle1Location)
	movb	$32, %dl
	movq	$5, %rdi
	movzbq	%r8b, %rsi
	movb	$0x0F, %cl
	call	putChar

	incb	%r8b		# i++
	jmp		1b			# loop
	2: # *************************************

	# ***** print paddle 2 *****
	movb	$0, %r8b	# i = 0
	1:
	cmpb	$25, %r8b	# i < 25
	jge		2f			# end loop if not

	# print black space char at (x,y) = (3,i + paddle2Location)
	movb	$32, %dl
	movq	$74, %rdi
	movzbq	%r8b, %rsi
	movb	$0x0F, %cl
	call	putChar

	incb	%r8b		# i++
	jmp		1b			# loop
	2: # *************************************

	leave
	ret

# *******************************************************************************
# * Subroutine: void removeBall()												*
# * variables: ballX and ballY as params and no return							*
# * description: removes the ball												*
# *******************************************************************************
removeBall:
	enter	$0, $0

	# ***** print ball *****
	# shift coordinates by -1
	movb	lastBallX, %r8b
	decb	%r8b
	movb	lastBallY, %r9b
	decb	%r9b

	# check if on screen
	cmpb	$0, %r8b
	jl		1f
	cmpb	$0, %r9b
	jl		1f
	cmpb	$40, %r8b
	jge		1f
	cmpb	$25, %r9b
	jge		1f

	# print left half of ball
	shlb	%r8b			# ballx * 2
	# print black space char at (x,y) = ((ballx * 2), ballY)
	movb	$32, %dl
	movzbq	%r8b, %rdi
	movzbq	%r9b, %rsi
	movb	$0x0F, %cl
	call	putChar
	
	# print right half of ball
	incb	%r8b			# (ballx * 2) + 1
	# print black space char at (x,y) = (((ballx * 2) + 1), ballY)
	movb	$32, %dl
	movzbq	%r8b, %rdi
	movzbq	%r9b, %rsi
	movb	$0x0F, %cl
	call	putChar
	1:

	leave
	ret

# ***** test for input flags *****
inputFlagsTest:
	enter $0, $0

	# INPUT FLAG TEST
	movq	$255, %rdi
	3:
	cmpq	$0, %rdi	# rdi < 0
	jl		4f			# end loop if

	call	ps2_getFlag

	pushq	%rdi

	movq	$0, %r12	# i = 0
	6:
	cmpq	$25, %r12	# i < 25
	jge		9f			# end loop if not

	movq 	$0, %r15	# k = 0
	movq	$0, %r13	# j = 0
	7:
	cmpq	$68, %r13	# j < 68
	jge		8f			# end loop if not

	cmp		$0, %rdi
	jne		1f

	# flag is clear
	cmpq	$0, %rax
	jne		2f

	# print space char at (x,y) = (j,i)
	movb	$32, %dl
	movq	%r13 , %rdi
	movq	%r12, %rsi
	movb	$0x1f, %cl
	call	putChar

	jmp		9f

	2:
	# print space char at (x,y) = (j,i)
	movb	$32, %dl
	movq	%r13 , %rdi
	movq	%r12, %rsi
	movb	$0x2f, %cl
	call	putChar

	jmp		9f

	1:
	decq	%rdi
	incq	%r13		# j++
	incq	%r13		# j++
	# check if this is the 8th column
	cmpq	$7, %r15
	jl	 	1f

	movq 	$0, %r15	# k = 0
	incq	%r13
	jmp		7b
	1:
	incq	%r15		# k++
	jmp		7b			# loop
	8:
	incq	%r12		# i++
	incq	%r12		# i++
	jmp		6b			# loop
	9:

	popq	%rdi
	decq	%rdi		# r8--
	jmp		3b			# loop
	4:

	leave
	ret

