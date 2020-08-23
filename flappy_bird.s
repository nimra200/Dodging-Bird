.data
	# colors
	backgroundColors: .word 0xabc5ed, 0x8acedb, 0x3666ad, 0x264573
	offset: .word -4 # a counter to move through backgroundColors 
	bird: .word 0xebd834
	pipe: .word 0x0eb02c
	red: .word 0xf70000
	
	# bird location
	tailY1: .word 4
	tailY2: .word 5
	tailY3: .word 6
	tailX: .word 5
	bodyY: .word 5
	bodyX1: .word 6
	bodyX2: .word 7
	bodyX3: .word 8
	wingY1: .word 4
	wingY2: .word 6
	wingX: .word 7
	
	# pipe location
	X1: .word 27
	X2: .word 31
	topHeight: .word 0 # the height of the top pipe 
	
	score: .word 0
	mode : .word 1 # 1 if it's daytime, 0 if it's night
	
.text

main: 

li $s3, 0 # $s3 is 1 if the game is over 
li $s2, 0 # $s2 holds the y displacement for the bird 


whileGameNotOver: 

	# prepare registers for drawing pipes
	lw $s0, X1
	lw $s1, X2

	# generate random height for top pipe 
	li $v0, 42 
	li $a1, 16
	syscall 
	add $a0, $a0, 1 # the random int generated is between [1, 17] exclusive 
	# set the new value of topHeight 
	la $t0, topHeight # load address
	move $t1, $a0 # set the new value of topHeight 
	sw $t1, 0($t0) # save the new value 
	
	# switch through background colors based on whether it's day or night mode
	lw $t1, mode
 	lw $t2, offset
 	ifDay: 
 		bne $t1, 1, elseNight
 		# we need to increase the offset to switch through the day colors unless it is the end of the day
 		ifDayEnd:
 			bne $t2, 12, elseIncrease
 			sw $zero, mode # turn to night mode
 			j elseNight 
 			
 		elseIncrease:
 			addi $t2, $t2, 4 
 			sw $t2, offset # update the current color 
 			jal whilePipesOnScreen
 
	
 	elseNight:
 	# we need to decrease offset to switch through night colors unless it is end of the night 
 		ifNightEnd: 
 			bne $t2, 0, elseDecrease 
 			li $t3, 1
 			sw $t3, mode # turn to day mode  
 			j ifDayEnd
 		elseDecrease: 
 			addi $t2, $t2, -4
 			sw $t2, offset # update the current color 
	
	whilePipesOnScreen:
		beq $s3, 1, Exit
		ble $s0, 0, whileGameNotOver # check if pipes have moved off the screen 
		
		jal drawBackground 
 		
 		lw $t1, 0xffff0000 # $t1 is 0 iff no key was pressed 
		lw $t2, 0xffff0004 # check which key was pressed
		lw $t0, tailY3
		add $t0, $t0, $s2 # check the y coordinate of the bird 
		
		ifKeyPressed:  
			beq $t1, 0, else 
			bne $t2, 102, else # 'f' is 102 in ASCII 
			# move the bird up 
			# if ''f'' is pressed and bird is not at risk of flying off the top of screen 
			ble $t0, 8, displayBirdAndPipes
			addi $s2, $s2, -2
			j displayBirdAndPipes 
		else: 
			 # here bird is not at risk of flying off the bottom of the screen 
			bge $t0, 30, displayBirdAndPipes 
			addi $s2, $s2, 2 # let the bird fall down by 1 unit 
		
displayBirdAndPipes: 
		
		# prepare to draw top pipe 
		move $a0, $s0 # left x coord
		move $a1, $s1 # right x coord 
		li $a2, 5 # vertical displacement 
		lw $a3, topHeight # move the randomly generated height to $a3 
		jal drawPipe
		
		# prepare registers for drawing bottom pipe
		move $a0, $s0
		move $a1, $s1
		
		# calculate the bottom pipe's displacement 
		lw $a2, topHeight 
		addi $a2, $a2, 13 # bottom pipe's displacement = topHeight + 7 + 5
		
		# calc the bottom pipe's height 
		li $a3, 31 
		subi $a3, $a3, 8
		lw $t0, topHeight 
		sub $a3, $a3, $t0 # bottom pipe's height = 31 - 7 - top pipe's height 
		
		jal drawPipe # bottom pipe
		 
		# shift the pipes left depending on difficulty 
		lw $t0, score 
		EasyDifficulty: 
			bge $t0, 2, MediumDifficulty 
			add $s0, $s0, -2
			add $s1, $s1, -2
			j displayBird 
		
		MediumDifficulty: 
			bge $t0, 5, HardDifficulty 
			add $s0, $s0, -4
			add $s1, $s1, -4
			j displayBird
		
		HardDifficulty: 
			add $s0, $s0, -8
			add $s1, $s1, -8
			
		displayBird: 
			jal drawBird 
			move $s3, $v0 # update the game state
			jal updateScore
		
		SLEEP: 
		li $v0, 32 # sleep
		li $a0,  310 # time in milliseconds to sleep 
		syscall
		
		j whilePipesOnScreen
	Exit:
	   jal drawBackground 
	   jal drawBye 
	   # exit gracefully 
	   li $v0, 10 
	   syscall 
	
	######### 
	# Check if a point has been earned (i.e the bird has successfully crossed through pipes)
	# and update the score to reflect that. 
	#########
	updateScore: 
		ifPointEarned: 
			lw $t2, tailX
			ble $t2, $s1, completeUpdate
			# increment score by 1 if bird's x coord is greater than the pipe's x coord 
			la $t0, score 
			lw $t1, score 
			addi $t1, $t1, 1 
			sw $t1, 0($t0) 
		completeUpdate: 
		# return back to original function call
		jr $ra 
	
	drawBackground: 

		# save $ra in the stack 
		add $sp, $sp, -4 
		sw $ra, 0($sp) 
		
		addi $t2, $gp, 0 # a counter keeping track of the current pixel's address
		add $t3, $gp, 4096 # the address of the bottom right pixel 
		drawWhile: 
			 
			bgt $t2, $t3, displayScore # exit and move on if our counter has reached the address of the last pixel on screen
			add $a0, $t2, $zero 
			lw $t4, offset
			lw $a1, backgroundColors($t4)
			jal paint
			addi $t2, $t2, 4 # increment counter 
			
			j drawWhile

			displayScore:
			lw $a0, score 
			jal displayNumericalScore
	
	displayScoreWord: 
			# draw 's' 
			
			li $a0, 0
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			li $a0, 0
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 #horizontal line 
			jal paintLine 
			
			li $a0, 0
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2 
			li $a3, 1 # vertical line 
			jal paintLine
			
			li $a0, 1
			li $a1, 3
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2 
			li $a3, 1 # vertical line 
			jal paintLine
			
			li $a0, 0
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			li $a0, 0
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			# draw 'c'
			li $a0, 3
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 0 # horizontal line 
			jal paintLine
			
			li $a0, 3
			li $a1, 1
			jal adjustCoordinates 
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 1 # vertical line 
			jal paintLine
			
			li $a0, 4
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 1
			li $a3, 0 # horizontal line 
			jal paintLine
			
			# paint 'o' 
			li $a0, 6
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 0 # horizontal line 
			jal paintLine
			
			li $a0, 6
			li $a1, 1
			jal adjustCoordinates 
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 1 # vertical line 
			jal paintLine
			
			li $a0, 6
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 0 # horizontal line 
			jal paintLine
			
			li $a0, 7
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 4
			li $a3, 1 # vertical line 
			jal paintLine
			
			# paint 'r'
			li $a0, 9
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			li $a0, 9
			li $a1, 0
			jal adjustCoordinates 
			move $a0, $v0
			move $a1, $v1 
			li $a2, 5
			li $a3, 1 # vertical 
			jal paintLine
			
			# paint 'e' 
			li $a0, 12
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine 
			
			li $a0, 12
			li $a1, 1 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 1 # vertical 
			jal paintLine 
			
			li $a0, 13
			li $a1, 2 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 1
			li $a3, 0 # horizontal 
			jal paintLine 
			
			li $a0, 13
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 1
			li $a3, 0 
			jal paintLine
			
			# paint " : "
			li $a0, 15
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			lw $a3, bird 
			jal paintCoord
			
			li $a0, 15
			li $a1, 3
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			lw $a3, bird
			jal paintCoord
				
			
	exitBackgroundLoop:
		lw $ra, ($sp)
		add $sp, $sp, 4 
		jr $ra 
	
	displayNumericalScore: 
	##### Display the current score on the screen. 
	##### Arguements: $a0: the current score 

		addi $sp, $sp, -8 
		sw $ra, 0($sp) 
		bge $a0, 10, doubleDigitScore
		li $a1, 18
		jal drawNum 
		j exitDisplay
			
		doubleDigitScore: 
 
			li $t0, 10 
			div $a0, $t0
			mflo $a0 
			mfhi $t1

			# save the remainder on the stack 
			sw $t1, 4($sp)
			
			li $a1, 18
			jal drawNum 
			
			# load remainder from stack 
			lw $a0, 4($sp)
			li $a1, 22
			jal drawNum 
		
		
			
		exitDisplay:
			lw $ra, 0($sp)
			addi $sp, $sp, 8 
			jr $ra  
	
					     	
	drawPipe: 
	###### BE CAREFUL! The vertical displacement and height of the bottom pipe needs to be
 	###### carefully calculated.. may end up with an error in painting if vertical d of pipe is
 	###### too much. The height of the bottom should increase as top decreases.
	##### & the displacement of bottom pipe is topPipeHeight + 7!!!! 
	
	# Draw a green pipe on the top or bottom of screen. 
	# arguments: $a0: left x coord, $a1: the right x coord, $a2: vertical displacement, 
	# $a3: height 
	
	addi $sp, $sp, -4 # store $ra in stack 
	sw $ra, 0($sp) 
	
	move $t2, $a0 # move the left x coord to $t2
	move $t3, $a1 # move the right x coord to $t3
	move $t6, $a2 # move vertical displacement to $t6 
	mul $t2, $t2, 4
	mul $t6, $t6, 128
	sub $t7, $a1, $a0 # $t7 is the pipe width  
	li $t0, 0 # counter i 
	
	whileLoopForHeight: # predicate: i <= height
		
		bgt $t0, $a3, exitHeightLoop 
		li $t1, 0 # counter j 
		whileLoopForWidth: # predicate: j <= width 

			bgt $t1, $t7, exitWhileLoopForWidth
			mul $t4, $t1, 4 # $t4 = j * 4 
			add $t4, $t4, $t2  # our new x coord is 4x + 4j  
			mul $t5, $t0, 128 # $t5 = i * 128 
			add $t5, $t5, $t6 # new y coord is 128i + displacement(128) 
			
			add $a0, $t4, $zero 
			add $a1, $t5, $zero 
			lw $a2, pipe
			jal paintCoord 
			
			# increment j 
			addi $t1, $t1, 1 
			j whileLoopForWidth
			
		exitWhileLoopForWidth:
			# increment i 
			addi $t0, $t0, 1 
			j whileLoopForHeight
			
		exitHeightLoop:
			lw $ra, 0($sp)
			addi $sp, $sp, 4  
			jr $ra 
	
	
	##########################
	# Given (x,y) coordinate and a color, paint the given area. 
	# Arguments: $a0: the x coordinate, $a1: the y coordinate, $a2: the color
	# Return Values: None
	##########################
	paintCoord: 
		add  $a0, $a1, $a0 # add x and y coordinates
		add $a0, $a0, $gp # add base address to get the location of the pixel that needs to be painted
		move $a1, $a2 # move the color to $a1 so that we can pass the color argument to paint function
		
		addi $sp, $sp, -4 # allocate 4 bytes in the stack by moving the pointer
		sw $ra, 0($sp) # save the address of the original function call in the stack
		
		jal paint 
		 
		lw $ra, 0($sp)  
		addi $sp, $sp, 4 # deallocate space in stack
		
		jr $ra
		
	##########################
	# Given an address and a color, paint the pixel at the address 
	# Arguments: $a0: the address, $a1: the color of the paint
	# Return Values: None 
	#########################
	paint: 
		sw $a1, ($a0) 
		jr $ra	
	
	##########################
	# Draw a yellow bird on the screen. X coords are multiples of 4 & y coords are multiples of 128 
	# This function uses $s2: + values move bird up, - for moving down, 0 for no vertical movement
	# Return value: $v0: 1 if bird has hit an object. 
	##########################
	  
	 drawBird:
	 	addi $sp, $sp, -4 # store $ra in stack 
		sw $ra, 0($sp) 
	 	

	 	lw $a2, bird
	 	# paint the tail 
	 	lw $a1, tailY1 
	 	add $a1, $a1, $s2 # add vertical displacement 
	 	lw $a0, tailX
	 	jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
	 	jal paintCoord 	
	 	
	 	lw $a1, tailY2 
	 	add $a1, $a1, $s2 # add vertical displacement 
	 	lw $a0, tailX
	 	jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
		jal paintCoord
		
		lw $a0, tailX
	 	lw $a1, tailY3
	 	add $a1, $a1, $s2 # add vertical displacement 
	 	jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
	 	jal paintCoord
	 	
		# paint the body 
		lw $a0, bodyX1
		lw $a1, bodyY
		add $a1, $a1, $s2 # add vertical displacement 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		jal checkCrash
		jal paintCoord
		
		lw $a0, bodyX2
		lw $a1, bodyY
		add $a1, $a1, $s2 # add vertical displacement 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
		jal paintCoord
		
		lw $a0, bodyX3
		lw $a1, bodyY
		add $a1, $a1, $s2 # add vertical displacement 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
		jal paintCoord
		
		#paint wings
		
		lw $a1, wingY1
		add $a1, $a1, $s2 # add vertical displacement 
		lw $a0, wingX
	 	jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
		jal paintCoord
		
		lw $a0, wingX
		lw $a1, wingY2
		add $a1, $a1, $s2 # add vertical displacement 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1
		jal checkCrash
		jal paintCoord
 	
 		
 	ExitBird: 
 		
 		lw $ra, 0($sp)
		addi $sp, $sp, 4  
		jr $ra 
	
	
	checkCrash: # check if the bird crashed with a pipe  
	# Arguments: $a0: the x coord. $a1: the y coord.
	# Return value: $v0: 1 if there was a crash with a pipe, 0 otherwise. 
		
		add $t0, $a1, $a0 
		add $t0, $t0, $gp 
		lw $t1, ($t0) 
		lw $t2, pipe
		ifCrash: 
			bne $t1, $t2, noCrash 
			li $v0, 1 
			j ExitBird 
		noCrash:
			li $v0, 0 
			jr $ra 
			
	adjustCoordinates: 		
	############# Alter the given coordinates so that they can map onto the bit map display.
	# All x coordinates have to multiplied by 4 and y coordinates by 128. 
	# Arguments: $a0: x coord, $a1: y coord 
	# Return values: $v0: the new x coord, $v1: the new y coord 
	############	
		move $v0, $a0 
		move $v1, $a1 
		mul $v0, $v0, 4 
		mul $v1, $v1, 128 
		jr $ra 
	
	
	#########
	# Draw a vertical or horizontal line in red.
	# arguments: $a0 : the starting x coord, $a1: the starting y coord, $a2: length of line, $a3: 1 for drawing vertical, 0 for horizontal
	#########
	paintLine: 
		# save $ra in the stack 
		add $sp, $sp, -4 
		sw $ra, 0($sp) 
		
		li $t0, 0 # the counter 
		move $t1, $a2 # the length of the line 
		move $t2, $a0 # x 
		move $t3, $a1 # y 
		lw $a2, red # paint lines in red
		
		while: # draw a line that's $t1 units long 
			beq $t0, $t1, finish 
			
			updateCounter:
				# paint the coordinates first 
				move $a0, $t2
				move $a1, $t3
				jal paintCoord
				# update counter 
				add $t0, $t0, 1	
			ifVertical:
				beq $a3, 0, elseHorizontal 
				addi $t3, $t3, 128 
				j exitIf
			elseHorizontal: 
				addi $t2, $t2, 4 
				
			exitIf:
				j while 
		finish: 
			lw $ra, 0($sp) 
			add $sp, $sp, 4
			jr $ra 
				
	drawNum: ##### Arguments: $a0: the current score, $a1: the x coordinate where number will be displayed
	
	addi $sp, $sp, -4 
	sw $ra, 0($sp) 
			ifScoreZero:
				bne $a0, 0, ifScoreOne
				jal drawZero 
				j exitFunction
			ifScoreOne: 
				bne $a0, 1, ifScoreTwo 
				jal drawOne
				j exitFunction
			ifScoreTwo: 
				bne $a0, 2, ifScoreThree
				jal drawTwo
				j exitFunction
			ifScoreThree:
				bne $a0, 3, ifScoreFour
				jal drawThree
				j exitFunction
			ifScoreFour:
				bne $a0, 4, ifScoreFive
				jal drawFour
				j exitFunction
			ifScoreFive:
				bne $a0, 5, ifScoreSix
				jal drawFive
				j exitFunction
			ifScoreSix: 
				bne $a0, 6, ifScoreSeven 
				jal drawSix
				j exitFunction
			ifScoreSeven:
				bne $a0, 7, ifScoreEight
				jal drawSeven
				j exitFunction
			ifScoreEight: 
				bne $a0, 8, ifScoreNine
				jal drawEight
				j exitFunction
			ifScoreNine:
				jal drawNine 
	exitFunction:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra 
	
	drawZero: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 1 # vertical  
			jal paintLine
			
			lw $a0, 0($sp)
			addi $a0, $a0, 1 # shift segment to the right by 1
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 1
			li $a3, 0 # horizontal  
			jal paintLine
			
			lw $a0, 0($sp)
			addi $a0, $a0, 1 # shift segment to the right by 1
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 1
			li $a3, 0 # horizontal  
			jal paintLine
			
			lw $a0, 0($sp)
			addi $a0, $a0, 2 # shift segment to the right by 2
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 1 # vertical
			jal paintLine
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8 # update stack pointer and return function 
			jr $ra 
		
		drawOne: # argument $a1: the x coordinate of number. 
			
			addi $sp, $sp, -4 
			sw $ra, 0($sp)
			
			move $a0, $a1 
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 1 # vertical
			jal paintLine
			
			lw $ra, 0($sp)
			addi $sp, $sp, 4
			jr $ra 
			
		drawTwo:  # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8 
			sw $a1, 0($sp)
			sw $ra, 4($sp) 
			
			move $a0, $a1
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine 
			
			lw $a0, 0($sp) # load the old x coord 
			addi $a0, $a0, 2 # shift segment to the right by 2 
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 1 # vertical 
			jal paintLine 
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 #horizontal 
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 1 # vertical 
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 # horizontal
			jal paintLine
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8 # change stack pointer and return 
			jr $ra
			
		drawThree: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 0 # horizontal
			jal paintLine
			
			# draw 1 
			lw $a1, 0($sp) # load the old x coord 
			addi $a1, $a1, 3
			jal drawOne 			
			 
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 #horizontal 
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 4
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 # horizontal
			jal paintLine
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8 # move stack pointer and return function 
			jr $ra
			
		drawFour: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1 
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 1 # vertical
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 2
			li $a3, 1 # vertical
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 #horizontal 
			jal paintLine
			
			lw $a0, 0($sp) # load the old x coord 
			addi $a0, $a0, 2 # shift this segment by 2 units to the right 
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 4
			li $a3, 1 #vertical
			jal paintLine
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8 # move stack pointer and return function 
			jr $ra
			
		drawFive: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8
			sw $a1, 0($sp)
			sw $ra, 4($sp)
	
			move $a0, $a1
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			# load old x coord from stack
			lw $a0, 0($sp) 
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 #horizontal line 
			jal paintLine 
			
			# load old x coord from stack
			lw $a0, 0($sp) 
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2 
			li $a3, 1 # vertical line 
			jal paintLine
			
			# load old x coord from stack
			lw $a0, 0($sp) 
			addi $a0, $a0, 1 # move segment to the right by 1 unit 
			li $a1, 3
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2 
			li $a3, 1 # vertical line 
			jal paintLine
			
			# load old x coord from stack
			lw $a0, 0($sp) 
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			# load old x coord from stack
			lw $a0, 0($sp) 
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			# update stack pointer and return function 
			lw $ra, 4($sp)
			addi $sp, $sp, 8
			jr $ra 
			
		drawSix: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8 
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1
			li $a1, 0
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 4
			li $a3, 1 # vertical line 
			jal paintLine
			
			# load old x coordinate from stack 
			lw $a0, 0($sp)
			li $a1, 2
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 3
			li $a3, 0 #horizontal line 
			jal paintLine 
			
			# load old x coordinate from stack 
			lw $a0, 0($sp)
			addi $a0, $a0, 2 # move segment 2 units to right 
			
			li $a1, 3
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2 
			li $a3, 1 # vertical line 
			jal paintLine
			
			# load old x coordinate from stack 
			lw $a0, 0($sp)
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 3
			li $a3, 0 # horizontal 
			jal paintLine
			
			# load old x coordinate from stack 
			lw $a0, 0($sp)
			li $a1, 4 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 2
			li $a3, 0 # horizontal 
			jal paintLine
			
			# update stack pointer and return function 
			lw $ra, 4($sp)
			addi $sp, $sp, 8
			jr $ra 
			
		drawSeven: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8 
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1 
			#li $a0, 17
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 3
			li $a3, 0 # horizontal 
			jal paintLine
			
			# draw 1 
			lw $a1, 0($sp) # load $a1 from the stack 
			addi $sp, $sp, 4
			
			addi $a1, $a1, 3 # shift number 1 by three units to right 
			jal drawOne 
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8
			jr $ra 
			
		drawEight: # argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8 
			sw $a1, 0($sp)
			sw $ra, 4($sp)
			
			move $a0, $a1
			li $a1, 1
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1
			li $a2, 3
			li $a3, 1 # vertical
			jal paintLine
			
			# draw a three
			# obtain x coordinate from stack 
			lw $a1, 0($sp)
			jal drawThree
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8
			jr $ra 
			
		drawNine: 
		#  argument $a1: the x coordinate of number. 
			# save $a1 in stack 
			addi $sp, $sp, -8
			sw $ra, 4($sp)
			sw $a1, 0($sp)
			
			move $a0, $a1
			li $a1, 0 
			jal adjustCoordinates
			move $a0, $v0
			move $a1, $v1 
			li $a2, 3
			li $a3, 0 # horizontal
			jal paintLine
			# draw four 
			# obtain x coordinate from stack 
			lw $a1, 0($sp)
			addi $sp, $sp, 4
			jal drawFour
			
			lw $ra, 4($sp)
			addi $sp, $sp, 8
			jr $ra

drawBye: # draw an exit screen that says ''bye!''
		
		# save $ra in the stack 
		add $sp, $sp, -4 
		sw $ra, 0($sp) 
		
		# paint "b" 
		li $a0, 10 # the starting x coordinate 
		li $a1, 10 # the starting y coordinate 
		jal adjustCoordinates 
		move $a0 , $v0
		move $a1, $v1 
		li $a2, 5 # the length of the line 
		li $a3, 1 # paint a vertical line 
		jal paintLine
		
		li $a0, 10 # the starting x coordinate 
		li $a1, 15 # the starting y coordinate 
		jal adjustCoordinates 
		move $a0 , $v0
		move $a1, $v1 
		li $a2, 3 # the length of the line 
		li $a3, 0 # paint a horizontal line 
		jal paintLine
		
		
		li $a0, 10 # the starting x coordinate 
		li $a1, 12 # the starting y coordinate 
		jal adjustCoordinates 
		move $a0 , $v0
		move $a1, $v1 
		li $a2, 3 # the length of the line 
		li $a3, 0 # paint a horizontal line 
		jal paintLine
		
		li $a0, 12 # the starting x coordinate 
		li $a1, 12 # the starting y coordinate 
		jal adjustCoordinates 
		move $a0 , $v0
		move $a1, $v1 
		li $a2, 3 # the length of the line 
		li $a3, 1 # paint a vertical line 
		jal paintLine
		
		# paint ''y''
	
		li $a0, 14 # x
		li $a1, 12 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 1 # vertical 
		jal paintLine 
		
		li $a0, 14 # x
		li $a1, 14 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 0 # horizontal
		jal paintLine 
		
		li $a0, 16 # x
		li $a1, 12 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 5 # length of line 
		li $a3, 1 # vertical 
		jal paintLine 
		
		li $a0, 14 # x
		li $a1, 16 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 0 # horizontal 
		jal paintLine 
		
		# paint ''e''
		li $a0, 18 # x
		li $a1, 10 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 5 # length of line 
		li $a3, 1 # vertical 
		jal paintLine 
		
		li $a0, 19 # x
		li $a1, 10 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 2 # length of line 
		li $a3, 0 # horizontal 
		jal paintLine
				
		li $a0, 18 # x
		li $a1, 12 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 0 # horizontal 
		jal paintLine 
		
		li $a0, 18 # x
		li $a1, 14 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 0 # horizontal 
		jal paintLine 
		
		# paint "!" 
		li $a0, 22 # x
		li $a1, 11 # y 
		jal adjustCoordinates
		move $a0, $v0 
		move $a1, $v1 
		li $a2, 3 # length of line 
		li $a3, 1 # vertical 
		jal paintLine 
		
		li $a0, 22 # x
		li $a1, 15 #y 
		jal adjustCoordinates 
		move $a0, $v0 
		move $a1, $v1 
		jal paintCoord
		
		# move stack pointer to jump back to the original functional call 
		lw $ra, 0($sp)
		add $sp, $sp, 4 
		jr $ra 
