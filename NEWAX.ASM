	.386
	CODE SEGMENT PARA PUBLIC USE16 'CODE'
	ASSUME	CS:CODE,DS:CODE,ES:CODE,SS:CODE
	ORG 	100h

	include CONST.INC
	include STRUCT.INC

start_code:
	jmp	install
new_int_10:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_BANK
	jne	test_vga_open_video_mode
	pushf
	call 	cs: dword ptr [old_int_10_off]
	or	bl,bl
	jne	no_fix_4f05_vram
	push	dx
	cmp	cs: byte ptr [shift_mode_size],3h
	jne	no_planar_align_5
	shl	dx,2h
no_planar_align_5:
	cmp	dx,cs: word ptr [vesa_memory]
	pop	dx
	jae	no_fix_4f05_vram
	mov	ax,VESA_ID
no_fix_4f05_vram:
	iret
test_vga_open_video_mode:
	cmp	ah,VGA_FUNC_SET_MODE
	jne	continue_int_10_0
	pushf
	call 	cs: dword ptr [old_int_10_off]
	pusha
	push	ds
	push	ZERO_SEGMENT
	pop	ds
	cmp	ds: byte ptr [OFFSET_VGA_VIDEO_MODE],MAX_VGA_VIDEO_MODE
	pop	ds
	ja	vesa_mode_on
	and	cs: byte ptr [status_flag_0],NOT NEWAX_FLAG_VESA_MODE
vesa_mode_on:
	call	Reset_Nvidia_Start_Address
	popa
	iret
continue_int_10_0:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	jne	continue_int_10_1
	cmp	bx,'MP'
	jne	continue_int_10_1
	push	cs
	pop	es
	mov	ax,VESA_ID
	iret
continue_int_10_1:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_RETURN_VBE
	jne	continue_int_10_2
	test	cs: byte ptr [status_flag_0],NEWAX_FLAG_VBEPM
	jne	go_int_10
	mov	ax,(VESA_FAIL SHL 8h) + VESA_ID
	iret	
continue_int_10_2:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_OPEN_VIDEO_MODE
	jne	continue_int_10_3
	mov	cs: word ptr [vesa_mode],bx
	pushf
	call 	cs: dword ptr [old_int_10_off]
	cmp	ax,VESA_ID
	jne	fail_open_vesa_mode
	pusha
	push	ds
	push	es
	push	cs
	pop	ds
	push	cs
	pop	es
	and	ds: byte ptr [status_flag_0],NOT NEWAX_FLAG_VESA_MODE
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_VIDEO_MODE_INFO
	mov	cx,ds: word ptr [vesa_mode]
	and	cx,MAX_VESA_MODE
	mov	di,OFFSET vesa_buffer_func_1
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	fail_vesa_info
	mov	ax,ds: word ptr [di].ModeInfoBlock.BytesPerScanLine
	mov	ds: word ptr [byte_per_scanline],ax
	mov	ax,3h
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PLANAR
	je	ok_vesa_mode
	dec	ax
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PACKED
	je	ok_vesa_mode
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_DIRECT_COLOR
	jne	fail_vesa_info
	mov	ah,1h
	cmp	ds: byte ptr [di].ModeInfoBlock.BitsPerPixel,VESA_32BPP
	jne	ok_vesa_mode	
	inc	ah
ok_vesa_mode:
	mov	ds: word ptr [shift_mode_size],ax
	or	ds: byte ptr [status_flag_0],NEWAX_FLAG_VESA_MODE
	mov	ds: word ptr [start_x],VESA_INIT_START_ADDRESS_X
	mov	ds: word ptr [start_y],VESA_INIT_START_ADDRESS_Y
fail_vesa_info:
	call	Reset_Nvidia_Start_Address
	pop	es
	pop	ds
	popa
fail_open_vesa_mode:
	iret
continue_int_10_3:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_SCANLINE
	jne	continue_int_10_4
	pushf
	call 	cs: dword ptr [old_int_10_off]
	cmp	ax,VESA_ID
	jne	no_set_scanline
	test	cs: byte ptr [status_flag_0],NEWAX_FLAG_VESA_MODE
	je	no_set_scanline
	or	bx,bx
	je	no_set_scanline
	mov	cs: word ptr [byte_per_scanline],bx
	push	cx
	push	eax
	push	ebx
	push	edx
	push	cs: word ptr [vesa_memory]
	push	0h
	pop	eax
	xor	edx,edx
	movzx	ebx,bx
	cmp	cs: byte ptr [shift_mode_size],3h
	jne	no_planar_align
	shl	ebx,3h
no_planar_align:
	div	ebx
	mov	edx,0FFFFh
	cmp	eax,edx
	ja	too_lines
	xchg	ax,dx
too_lines:
	mov	cx,dx
	pop	edx
	pop	ebx
	pop	eax
	mov	dx,cx
	pop	cx
	mov	ax,VESA_ID
no_set_scanline:
	iret
continue_int_10_4:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_START_ADDRESS
	jne	continue_int_10_5
	test	cs: byte ptr [status_flag_0],NEWAX_FLAG_VESA_MODE
	je	go_int_10
	or	bh,bh
	jne	go_int_10
	cmp	bl,VESA_GET_START_ADDRESS
	jne	test_set_address
	mov	cx,cs: word ptr [start_x]
	mov	dx,cs: word ptr [start_y]
	mov	ax,VESA_ID
	iret
test_set_address:
	pusha
	mov	si,cx
	mov	di,dx
	call	Get_CRTC_Port
	add	dl,INPUT_STATUS_REGISTER_DIFF
	cmp	bl,VESA_SET_START_ADDRESS
	je	set_start_address
	cmp	bl,VESA_SET_START_ADDRESS_RETRACE
	je	vretrace_off
	popa
	jmp	go_int_10
vretrace_off:
	in	al,dx
	test	al,VGA_RETRACE
	jne	vretrace_off
vretrace_on:
	in	al,dx
	test	al,VGA_RETRACE
	je	vretrace_on
set_start_address:
	sub	dx,INPUT_STATUS_REGISTER_DIFF
	push	dx
	mov	cx,cs: word ptr [shift_mode_size]
	mov	ax,cs: word ptr [byte_per_scanline]
	cmp	cl,3h
	je	vesa_planar_mode_1
	shr	ax,cl
vesa_planar_mode_1:
	mul	di
	mov	bx,si
	xchg	cl,ch
	shl	bx,cl
	xchg	cl,ch
	shr	bx,cl
	add	ax,bx
	adc	dx,ZERO
	mov	bx,si
	sub	cl,ch
	mov	bh,1h
	shl	bh,cl
	dec	bh
	and	bl,bh
	sub	cl,3h
	neg	cl
	shl	bl,cl
	and	bl,7h
	xchg	ax,cx
	mov	si,dx
	pop	dx
	mov	al,VGA_LOW_START_ADDRESS
	out	dx,al
	inc	dx
	mov	al,cl
	out	dx,al
	dec	dx
	mov	al,VGA_HIGH_START_ADDRESS
	out	dx,al
	inc	dx
	mov	al,ch
	out	dx,al
	dec	dx
	mov	cx,si
	call	Set_Nvidia_Extended_Start_Address
	add	dx,INPUT_STATUS_REGISTER_DIFF
	in	al,dx
	push	dx
	mov	al,VGA_HORIZONTAL_PEL_PANNING
	mov	dx,VGA_ATTRIBUTE_PORT
	out	dx,al
	mov	al,bl
	out	dx,al
	pop	dx
	in	al,dx
	mov	dx,VGA_ATTRIBUTE_PORT
	mov	al,VGA_PAS_BIT
	out	dx,al
	popa
	mov	cs: word ptr [start_x],cx
	mov	cs: word ptr [start_y],dx
	mov	ax,VESA_ID
	iret
continue_int_10_5:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_VIDEO_MODE_INFO
	jne	continue_int_10_6
	pushf
	call 	cs: dword ptr [old_int_10_off]
	cmp	ax,VESA_ID
	jne	fail_info_vesa_mode
	test	cs: byte ptr [status_flag_0],NEWAX_FLAG_ONE_PAGE
	je	set_page_number
	mov	es: byte ptr [di].ModeInfoBlock.LinNumberOfImagePages,ZERO
	mov	es: byte ptr [di].ModeInfoBlock.NumberOfImagePages,ZERO
	mov	es: byte ptr [di].ModeInfoBlock.BnkNumberOfImagePages,ZERO
	jmp	fail_info_vesa_mode
set_page_number:
	pushad
	mov	ax,es: word ptr [di].ModeInfoBlock.BytesPerScanLine
	cmp	es: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PLANAR
	jne	no_planar_correction
	shl	ax,2h
no_planar_correction:
	mul	es: word ptr [di].ModeInfoBlock.YResolution
	push	dx
	push	ax
	pop	esi
	movzx	eax,cs: word ptr [vesa_memory]
	shl	eax,10h
	xor	edx,edx
	div	esi
	cmp	eax,MAX_PAGE_AVAILABLE
	jbe	valid_pages
	mov	al,MAX_PAGE_AVAILABLE
valid_pages:
	dec	ax
	mov	es: byte ptr [di].ModeInfoBlock.LinNumberOfImagePages,al
	mov	es: byte ptr [di].ModeInfoBlock.NumberOfImagePages,al
	mov	es: byte ptr [di].ModeInfoBlock.BnkNumberOfImagePages,al
fail_vesa_get_video_mode:
	popad
fail_info_vesa_mode:
	iret
continue_int_10_6:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_INFO
	jne	go_int_10
	test	cs: byte ptr [status_flag_0],NEWAX_FLAG_VESA2
	je	go_int_10
	pushf
	call 	cs: dword ptr [old_int_10_off]
	cmp	ax,VESA_ID
	jne	fail_vesa_get_info
	mov	es: word ptr [di].VbeInfoBlock.VbeVersion,VESA_2
fail_vesa_get_info:
	iret
go_int_10:
	jmp 	cs: dword ptr [old_int_10_off]
Reset_Nvidia_Start_Address:
	call	Get_CRTC_Port
	xor	cx,cx
	call	Set_Nvidia_Extended_Start_Address
	ret
Set_Nvidia_Extended_Start_Address:
	mov	al,NVIDIA_CRTC_UNLOCK_REG
	out	dx,al
	inc	dx
	mov	al,NVIDIA_CRTC_UNLOCK_VALUE
	out	dx,al
	dec	dx
	mov	al,NVIDIA_LOW_START_ADDRESS
	out	dx,al
	inc	dx
	mov	al,cl
	out	dx,al
	dec	dx
	mov	al,NVIDIA_HIGH_START_ADDRESS
	out	dx,al
	inc	dx
	mov	al,ch
	and	al,NVIDIA_MASK_HIGH_ADDRESS
	out	dx,al
	dec	dx
	ret
Get_CRTC_Port:
	mov	dx,VIDEO_READ_MISCELLANEOUS_REG
	in	al,dx
	and	al,CRTC_ADDRESS
	shl	al,CRTC_ADDRESS_SHIFT
	mov	dx,CRTC_MONO
	add	dl,al
	ret
old_int_10_off:
	DW	?
old_int_10_seg:
	DW	?
new_int_10_off:
	DW	?
new_int_10_seg:
	DW	?
status_flag_0:
	DB	0h
start_x:
	DW	?
start_y:
	DW	?
vesa_mode:
	DW	?
byte_per_scanline:
	DW	?
shift_mode_size:
	DW	?
vesa_memory:
	DW	?
vesa_buffer_func_1:
	ModeInfoBlock <>
install:
	mov	si,OFFSET void_buffer
	call	Get_Args
	lodsb
	or	al,al
	je	go_install
	mov	ds: word ptr [dos_message],OFFSET dos_message_04
	cmp	al,NEWAX_ONE_ARGS
	jne	exit_to_dos_clear
	mov	si,ds: word ptr [si]
	lodsw
	cmp	ds: byte ptr [si],NEWAX_STRING_TERMINATOR
	jne	exit_to_dos_clear
	cmp	ax,'1/'
	jne	test_vesa2
	mov	ds: word ptr [dos_message],OFFSET dos_message_05
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	xor	es: byte ptr [status_flag_0],NEWAX_FLAG_ONE_PAGE
	mov	ds: word ptr [dos_message],OFFSET dos_message_15
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_ONE_PAGE
	jne	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_16
	jmp	exit_to_dos_clear
test_vesa2:
	cmp	ax,'2/'
	jne	test_vbepm
	mov	ds: word ptr [dos_message],OFFSET dos_message_05
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	xor	es: byte ptr [status_flag_0],NEWAX_FLAG_VESA2
	mov	ds: word ptr [dos_message],OFFSET dos_message_11
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_VESA2
	jne	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_12
	jmp	exit_to_dos_clear
test_vbepm:
	and	ah,NEWAX_UPPER_CASE
	cmp	ax,'F/'
	je	go_install
	cmp	ax,'S/'
	jne	test_vbe_pmi
	mov	ds: word ptr [dos_message],OFFSET dos_message_05
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	mov	dx,OFFSET dos_message_00
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_17
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_20
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_VESA2
	jne	status_0
	mov	dx,OFFSET dos_message_21
status_0:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_18
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_20
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_VBEPM
	jne	status_1
	mov	dx,OFFSET dos_message_21
status_1:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_19
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_20
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_ONE_PAGE
	jne	status_2
	mov	dx,OFFSET dos_message_21
status_2:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	jmp	end_newax
test_vbe_pmi:
	cmp	ax,'P/'
	jne	test_uninstall
	mov	ds: word ptr [dos_message],OFFSET dos_message_05
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	xor	es: byte ptr [status_flag_0],NEWAX_FLAG_VBEPM
	mov	ds: word ptr [dos_message],OFFSET dos_message_13
	test	es: byte ptr [status_flag_0],NEWAX_FLAG_VBEPM
	jne	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_14
	jmp	exit_to_dos_clear
test_uninstall:
	cmp	ax,'U/'
	jne	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_05
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_06
	push	ZERO_SEGMENT
	pop	fs
	mov	eax,fs: dword ptr [VIDEO_INTERRUPT * SIZEOF DWORD]
	cmp	eax,es: dword ptr [new_int_10_off]
	jne	exit_to_dos_clear
	lds	dx,es: dword ptr [old_int_10_off]
	mov	ax,(DOS_FUNC_SET_INTERRUPT_VECTOR SHL 8h) + VIDEO_INTERRUPT
	int	DOS_INTERRUPT
	push	cs
	pop	ds
	push	es
	mov	es,es: word ptr [DOS_OFFSET_pspEnvironment]
	mov	ah,DOS_FUNC_FREE_MEMORY
	int	DOS_INTERRUPT
	pop	es
	jc	exit_to_dos_clear
	mov	ah,DOS_FUNC_FREE_MEMORY
	int	DOS_INTERRUPT
	jc	exit_to_dos_clear
	mov	ds: word ptr [dos_message],OFFSET dos_message_07
	jmp	exit_to_dos_clear
go_install:
	mov	ds: word ptr [dos_message],OFFSET dos_message_10
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_INFO
	mov	di,OFFSET vesa_buffer_func_0
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos_clear
	mov	ax,ds: word ptr [di].VbeInfoBlock.TotalMemory
	mov	ds: word ptr [vesa_memory],ax
	mov	ds: word ptr [dos_message],OFFSET dos_message_08
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	je	exit_to_dos_clear
	cmp	ds: byte ptr [void_buffer],1h
	je	force_install
	mov	ds: word ptr [dos_message],OFFSET dos_message_01
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_OPEN_VIDEO_MODE
	mov	bx,VESA_VIDEO_MODE_640X480X8
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos
	mov	ds: word ptr [dos_message],OFFSET dos_message_02
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_SCANLINE
	mov	bl,VESA_GET_SCANLINE
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_to_dos
	mov	ds: word ptr [dos_message],OFFSET dos_message_03
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_START_ADDRESS
	mov	bx,VESA_SET_START_ADDRESS
	mov	cx,VESA_TEST_HORIZONTAL_START
	mov	dx,VESA_TEST_VERTICAL_START
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	je	exit_to_dos
	mov	ax,(VGA_FUNC_SET_MODE SHL 8h) + VGA_VIDEO_MODE_80x25XTEXT
	int	VIDEO_INTERRUPT
force_install:
	push	ZERO_SEGMENT
	pop	fs
	push	fs: dword ptr [VIDEO_INTERRUPT * SIZEOF DWORD]
	pop	ds: dword ptr [old_int_10_off]
	mov	dx,OFFSET new_int_10
	mov	ds: word ptr [new_int_10_off],dx
	mov	ds: word ptr [new_int_10_seg],ds
	mov	ax,(DOS_FUNC_SET_INTERRUPT_VECTOR SHL 8h) + VIDEO_INTERRUPT
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_00
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_09
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov 	dx,OFFSET install + ALIGN_PARA
	int	TSR_INTERRUPT
exit_to_dos:
	mov	ax,(VGA_FUNC_SET_MODE SHL 8h) + VGA_VIDEO_MODE_80x25XTEXT
	int	VIDEO_INTERRUPT
exit_to_dos_clear:
	mov	dx,OFFSET dos_message_00
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,ds: word ptr [dos_message]
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
end_newax:
	mov	ax,(DOS_FUNC_END_PROGRAM SHL 8h) + DOS_ReturnValue
	int	DOS_INTERRUPT

;#############################################################################

;	DS:SI = Pointer to the memory area for storing pointers to
;                command-line arguments (where the first byte represents
;                the argument count)

	Get_Args:

;#############################################################################

	pusha
	xor	bx,bx
	push	si
	inc	si
	mov	di,OFFSET_INIT_ARGS
	movzx	cx,ds: byte ptr [di-1h]
	or	cl,cl
	je	exit_get_args
	mov	al,' '
another_arg:
	repe	scasb
	je	exit_get_args
	inc	bx
	mov	ds: word ptr [si],di
	dec	ds: word ptr [si]
	inc	si
	inc	si
	repne	scasb
	jne	set_final_string
	mov	ds: byte ptr [di-1h],ch
	jmp	another_arg
set_final_string:
	mov	ds: byte ptr [di],ch
exit_get_args:
	pop	si
	mov	ds: byte ptr [si],bl
	popa
	ret

dos_message_00:
	DB	'Nvidia kEpler/maxWell/pAscal fiX - NEWAX ',NEWAX_VER,' - NVIDIA mode',0Dh,0Ah,'$'
dos_message_01:
	DB	'Unable to open VESA video mode 640x480x8',0Dh,0Ah,'$'
dos_message_02:
	DB	'VESA function 4F06h (Set/Get scanline) not supported',0Dh,0Ah,'$'
dos_message_03:
	DB	'VESA function 4F07h (Set/Get start address) supported - NEWAX not loaded',0Dh,0Ah,'$'
dos_message_04:
	DB	'Use: NEWAX.COM (install TSR)',0Dh,0Ah
	DB	'     NEWAX.COM /U (Uninstall from memory)',0Dh,0Ah
	DB	'     NEWAX.COM /2 (Toggle VESA 2.0/3.0)',0Dh,0Ah
	DB	'     NEWAX.COM /P (Toggle VBE/PMI)',0Dh,0Ah
	DB	'     NEWAX.COM /1 (Toggle one page mode)',0Dh,0Ah
	DB	'     NEWAX.COM /F (Force installation)',0Dh,0Ah
	DB	'     NEWAX.COM /S (View status flags)',0Dh,0Ah,'$'
dos_message_05:
	DB	'NEWAX not installed',0Dh,0Ah,'$'
dos_message_06:
	DB	'Can''t uninstall NEWAX',0Dh,0Ah,'$'
dos_message_07:
	DB	'NEWAX uninstalled',0Dh,0Ah,'$'
dos_message_08:
	DB	'NEWAX already installed',0Dh,0Ah,'$'
dos_message_09:
	DB	'NEWAX installed',0Dh,0Ah,'$'
dos_message_10:
	DB	'VESA not found',0Dh,0Ah,'$'
dos_message_11:
	DB	'VESA 2.0: Enabled',0Dh,0Ah,'$'
dos_message_12:
	DB	'VESA 3.0: Enabled',0Dh,0Ah,'$'
dos_message_13:
	DB	'VBE/PMI: Enabled',0Dh,0Ah,'$'
dos_message_14:
	DB	'VBE/PMI: Disabled',0Dh,0Ah,'$'
dos_message_15:
	DB	'One page mode: Enabled',0Dh,0Ah,'$'
dos_message_16:
	DB	'One page mode: Disabled',0Dh,0Ah,'$'
dos_message_17:
	DB	'VESA 2.0:$'
dos_message_18:
	DB	'VBE/PMI:$'
dos_message_19:
	DB	'One page:$'
dos_message_20:
	DB	' Enabled',0Dh,0Ah,'$'
dos_message_21:
	DB	' Disabled',0Dh,0Ah,'$'
vesa_buffer_func_0:
	VbeInfoBlock <>
dos_message:
	DW	?
void_buffer:

	CODE ENDS
	END	start_code
