/*
This file is part of gamelib-x64.

Copyright (C) 2014 Otto Visser

gamelib-x64 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gamelib-x64 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gamelib-x64. If not, see <http://www.gnu.org/licenses/>.
*/

.include "src/kernel/00_boot_vars.s"

.file "src/kernel/ps2.s"

.section .kernel.data
testNumString:		.asciz "Number is : %u\n"
ps2_init_str:		.asciz "* Initializing PS/2 subsystem...\n"
ps2_init_done_str:	.asciz "* Initializing PS/2 subsystem: done\n"
ps2_status_str:		.asciz "ps/2 status: %x\n"
keyboard_in_str:	.asciz "Keyboard in: %x\n"

PS2_COMMAND	= 0x64
PS2_DATA	= 0x60

read_bytes:	.quad 0	# our "buffer"
code_set1:	.byte 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0
			.byte 0, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0
			.byte 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '\`'
			.byte 0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0
			.byte '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			.byte '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0', '.'
			.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
keyflags:	.quad 0, 0, -1, -1 # one bit for all keys 	 

.section .kernel

init_ps2:
	enter	$0, $0

	mov		$ps2_init_str, %r8
	#call	printf

	# steps analogue to http://wiki.osdev.org/%228042%22_PS/2_Controller
	# step 1: TODO: make sure USB goes first and disables USB legacy; after that we check there's ps/2 or not
	# step 2: TODO check that with ACPI (bit 1, offset 109 in FADT should be on)
	# step 3: disable devices
	mov		$0xAD, %rax
	out		%al, $PS2_COMMAND
	mov		$0xA7, %rax
	out		%al, $PS2_COMMAND

	# step 4: flush the buffer
	in		$PS2_DATA, %al		# ignore content

	# step 5: set controller configuration byte
	mov		$0x20, %rax
	out		%al, $PS2_COMMAND

	in		$PS2_DATA, %al

	mov		$0, %rax			# 0 in all bits for Controller Configuration Byte
	out		%al, $PS2_DATA
	mov		$0x60, %rax
	out		%al, $PS2_COMMAND
	
	# step 6: perform self test
	mov		$0xAA, %rax
	out		%al, $PS2_COMMAND
# TODO check response: 0x55

	# step 7: one or two channels? (see step 5)

# step 8: perform interface test

# step 9: enable devices
	mov		$0xAE, %rax
	out		%al, $PS2_COMMAND
	mov		$0xA8, %rax
	out		%al, $PS2_COMMAND

# step 10: reset devices

	mov		$ps2_init_done_str, %r8
	#call	printf

	leave
	ret

print_ps2_status:
	enter	$0, $0
	push	%rax

	mov		$0, %rax
	in		$PS2_COMMAND, %al
	push	%rax
	mov		$ps2_status_str, %r8
	#call	printf

	leave
	ret

ps2_bottom_half:
	enter	$0, $0
	pushq	%rax
	pushq	%r8
	pushq	%r9
	pushq	%r10
	pushq	%r11

	mov		$0, %rax
	in		$PS2_DATA, %al

	movq	%rax, %r8

	mov		$keyflags, %r9
	shr		$3, %r8	
	addq	%r8, %r9			# r9 is now the address of the correct byte
	
	mov		%rax, %r8
	and		$7, %r8			# right 3 bits of the code in r8 to decide which flag to set

	movq	$1, %r10
	3:
	cmpq	$0, %r8		# r8 == 0
	je		4f			# end loop if

	shl		%r10

	decq	%r8			# r8--
	jmp		3b			# loop
	4:

	orb 	%r10b, (%r9)
	
	# check if the code is release 
	cmpq	$128, %rax
	jl		8f				# if, set flag, else clear flag

	# take the last 128 bits in flags, flip them, and put them in the first 128 bytes
	movq	$keyflags, %r9
	movq	16(%r9), %r10
	movq	24(%r9), %r11

	xorq	$-1, %r10
	xorq	$-1, %r11

	movq	%r10, (%r9)
	movq	%r11, 8(%r9)

	jmp		9f

	8:
	# take the first 128 bits in flags, flip them, and put them in the last 128 bytes
	movq	$keyflags, %r9
	movq	(%r9), %r10
	movq	8(%r9), %r11

	xorq	$-1, %r10
	xorq	$-1, %r11

	movq	%r10, 16(%r9)
	movq	%r11, 24(%r9)

	# ********************************************************
9:

	popq	%r11
	popq	%r10
	popq	%r9
	popq	%r8
	popq	%rax
	leave
	ret

ps2_translate_scancode:
	enter	$0, $0
	push	%rax

	mov		$code_set1, %rax
	mov		(%rax, %r8, 1), %al
	and		$0xFF, %rax
	mov		%rax, %r8

	pop		%rax
	leave
	ret

# *******************************************************************************
# * Subroutine: boolean ps2_getFlag(int scancode)								*
# * variables: scancode in %rdi, return in %rax									*
# * description: returns if the flag of a scancode is set						*
# *******************************************************************************
ps2_getFlag:
	enter	$0, $0

	cmp		$256, %rdi
	jge		8f
	cmp		$0, %rdi
	jl		8f

	mov		%rdi, %r8	
	mov		$keyflags, %r9
	shr		$3, %r8	
	addq	%r8, %r9			# r9 is now the address of the correct byte
	movzbq	(%r9), %r9			# r9 is now the correct byte of flags

	movq	%rdi, %r8
	andq	$7, %r8			# right 3 bits of the code in r8 to decide which flag to check

	movq	$1, %r10
	3:
	cmpq	$0, %r8		# r8 == 0
	je		4f			# end loop if

	shl		%r10

	decq	%r8			# r8--
	jmp		3b			# loop
	4:

	and		%r10, %r9

	cmp		$0, %r9
	je		8f
	movq	$1, %rax
	jmp		9f
8:
	movq 	$0, %rax
9:
	leave
	ret

# *******************************************************************************
# * Subroutine: boolean ps2_getkey(int scancode)								*
# * variables: scancode in %rdi, return in %rax									*
# * description: returns if the flag of a scancode is set						*
# *******************************************************************************
ps2_getkey:
	enter	$0, $0

	call	ps2_getFlag

	leave
	ret

# *******************************************************************************
# * Subroutine: void resetFlags()												*
# * variables: none																*
# * description: resets all the key flags										*
# *******************************************************************************
resetFlags:
	enter	$0, $0
	pushq	%r9

	movq	$keyflags, %r9
	movq	$0, (%r9)
	movq	$0, 8(%r9)
	movq	$-1, 16(%r9)
	movq	$-1, 24(%r9)
	
	popq	%r9
	leave
	ret
