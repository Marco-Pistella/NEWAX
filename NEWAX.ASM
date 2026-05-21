	.386
	CODE SEGMENT PARA PUBLIC USE16 'CODE'
	ASSUME CS:CODE,DS:CODE,ES:CODE,SS:CODE
	ORG 100h

	include CONST.INC
	include STRUCT.INC

start_code:
	jmp	install
new_int_10:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_BANK
	jne	test_vga_open_video_mode
	pushf
	call 	cs: dword ptr [old_int_10_off]
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_FLAG_VESA_MODE_TSR
	je	no_fix_4f05_vram
	or	bl,bl
	jne	no_fix_4f05_vram
	push	dx
	cmp	cs: byte ptr [shift_mode_size],NEWAX_PLANAR_MODE
	jne	no_planar_align_5
	shl	dx,VGA_PLANER_PLANE_SHIFT
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
	push	BIOS_INTERRUPT_SEGMENT
	pop	ds
	cmp	ds: byte ptr [BIOS_OFFSET_VGA_VIDEO_MODE],VGA_MAX_VIDEO_MODE
	ja	vesa_mode_on
	and	cs: byte ptr [status_flag_0_tsr],NOT NEWAX_FLAG_VESA_MODE_TSR
vesa_mode_on:
	call	Reset_Nvidia_Start_Address
	pop	ds
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
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_VBEPMI_FLAG_TSR
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
	and	ds: byte ptr [status_flag_0_tsr],NOT NEWAX_FLAG_VESA_MODE_TSR
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_VIDEO_MODE_INFO
	mov	cx,ds: word ptr [vesa_mode]
	and	cx,VESA_MAX_MODE
	mov	di,OFFSET vesa_buffer_func_1
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	end_open_vesa
	mov	al,ds: byte ptr [di].ModeInfoBlock.WinAAttributes
	and	al,VESA_WINDOW_READIBLE OR VESA_WINDOW_WRITEABLE
	cmp	al,VESA_WINDOW_READIBLE OR VESA_WINDOW_WRITEABLE
	jne	end_open_vesa
	cmp	ds: word ptr [di].ModeInfoBlock.WinSize,VESA_WINDOWS_DEFAULT_SIZE
	jne	end_open_vesa
	cmp	ds: word ptr [di].ModeInfoBlock.WinGranularity,VESA_WINDOWS_DEFAULT_GRANULARITY
	jne	end_open_vesa
	mov	ax,ds: word ptr [di].ModeInfoBlock.BytesPerScanLine
	mov	ds: word ptr [byte_per_scanline],ax
	mov	ax,ds: word ptr [di].ModeInfoBlock.XResolution
	mov	ds: word ptr [x_res],ax
	mov	ax,ds: word ptr [di].ModeInfoBlock.YResolution
	mov	ds: word ptr [y_res],ax
	mov	ax,NEWAX_PLANAR_MODE
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PLANAR
	je	ok_vesa_mode
	dec	ax
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PACKED
	je	ok_vesa_mode
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_DIRECT_COLOR
	jne	end_open_vesa
	inc	ah
	cmp	ds: byte ptr [di].ModeInfoBlock.BitsPerPixel,VESA_32BPP
	jne	ok_vesa_mode	
	inc	ah
ok_vesa_mode:
	mov	ds: word ptr [shift_mode_size],ax
	or	ds: byte ptr [status_flag_0_tsr],NEWAX_FLAG_VESA_MODE_TSR
	mov	ds: word ptr [start_x],VESA_INIT_START_ADDRESS_X
	mov	ds: word ptr [start_y],VESA_INIT_START_ADDRESS_Y
	test	ds: byte ptr [vesa_mode + SIZEOF BYTE],VESA_OPEN_CLEAR_FLAG
	jne	end_open_vesa
	test	ds: byte ptr [vesa_mode + SIZEOF BYTE],VESA_OPEN_LINEAR_FLAG
	je	no_linear_mode_1
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_OPEN_VIDEO_MODE
	mov	bx,ds: word ptr [vesa_mode]
	and	bh,NOT VESA_OPEN_LINEAR_FLAG
	pushf
	call 	cs: dword ptr [old_int_10_off]
no_linear_mode_1:
	mov	si,ds: word ptr [vesa_memory]
	cmp	ds: byte ptr [di].ModeInfoBlock.MemoryModel,VESA_PLANAR
	jne	clear_vram
	shr	si,VGA_PLANER_PLANE_SHIFT
clear_vram:
	push	eax
	xor	bp,bp
	mov	es,ds: word ptr [di].ModeInfoBlock.WinASegment
	xor	di,di
loop_clear_vram:
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_BANK
	xor	bx,bx
	mov	dx,bp
	int	VIDEO_INTERRUPT
	xor	eax,eax
	mov	cx,HW_SEGMENT_SIZE / SIZEOF DWORD
	rep	stosd
	inc	bp
	cmp	bp,si
	jb	loop_clear_vram
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_BANK
	xor	bx,bx
	xor	dx,dx
	int	VIDEO_INTERRUPT
	pop	eax
	test	ds: byte ptr [vesa_mode + SIZEOF BYTE],VESA_OPEN_LINEAR_FLAG
	je	end_open_vesa
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_OPEN_VIDEO_MODE
	mov	bx,ds: word ptr [vesa_mode]
	pushf
	call 	cs: dword ptr [old_int_10_off]
end_open_vesa:
	call	Reset_Nvidia_Start_Address
	pop	es
	pop	ds
	popa
fail_open_vesa_mode:
	iret
continue_int_10_3:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_SCANLINE
	jne	continue_int_10_4
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_FLAG_VESA_MODE_TSR
	je	go_int_10
	pushad
	push	ds
	push	cs
	pop	ds
	cmp	bl,VESA_SET_SCANLINE_LEN_PIXEL
	jne	scanline_1
entry_for_pixel:
	cmp	cx,ds: word ptr [x_res]
	jb	fail_scanline
	and	cx,0FFF8h
	mov	si,cx
	mov	ax,ds: word ptr [shift_mode_size]
	shr	cx,1h
	cmp	ah,2h
	je	set_offset
	shr	cx,1h
	cmp	ah,1h
	je	set_offset
	shr	cx,1h
	cmp	ax,2h
	je	set_offset
	shr	cx,1h
set_offset:
	movzx	ebx,cx
	shl	ebx,3h
	cmp	ebx,VESA_MAX_HORIZONTAL_BYTE
	ja	fail_scanline
	movzx	eax,ds: word ptr [vesa_memory]
	shl	eax,10h
	xor	edx,edx
	div	ebx
	movzx	edx,ds: word ptr [y_res]
	cmp	eax,edx
	jb	fail_scanline
	xchg	eax,ebp
	call	Set_Nvidia_Complete_Offset
	cmp	ds: byte ptr [shift_mode_size],3h
	jne	no_planar_scanline
	shr	ebx,2h
	mov	si,bx
	shl	si,3h
no_planar_scanline:
	cmp	ebp,VESA_MAX_VERTICAL_PIXEL
	jbe	valid_vertical_pixel
	mov	ebp,VESA_MAX_VERTICAL_PIXEL
valid_vertical_pixel:
	mov	ds: word ptr [byte_per_scanline],bx
	mov	ds: word ptr [pixel_per_scanline],si
	mov	ds: word ptr [max_scanline],bp
enter_get_scanline:
	pop	ds
	popad
	mov	bx,cs: word ptr [byte_per_scanline]
	mov	cx,cs: word ptr [pixel_per_scanline]
	mov	dx,cs: word ptr [max_scanline]
	mov	ax,VESA_ID
	iret
scanline_1:
	cmp	bl,VESA_GET_SCANLINE_LEN
	jne	scanline_2
	movzx	ebx,ds: word ptr [byte_per_scanline]
	mov	cx,bx
	mov	ax,ds: word ptr [shift_mode_size]
	cmp	ax,3h
	jne	no_planar_get
	shl	cx,3h
	jmp	exit_get_scanline
no_planar_get:
	cmp	ax,2h
	je	exit_get_scanline
	shr	cx,1h
	cmp	ah,1h
	je	exit_get_scanline
	shr	cx,1h
exit_get_scanline:
	movzx	eax,ds: word ptr [vesa_memory]
	shl	eax,10h
	xor	edx,edx
	div	ebx
	cmp	eax,VESA_MAX_VERTICAL_PIXEL
	jbe	valid_vertical_pixel_get
	mov	eax,VESA_MAX_VERTICAL_PIXEL
valid_vertical_pixel_get:
	mov	ds: word ptr [pixel_per_scanline],cx
	mov	ds: word ptr [max_scanline],ax
	jmp	enter_get_scanline
scanline_2:
	cmp	bl,VESA_SET_SCANLINE_LEN_BYTE
	jne	scanline_3
	movzx	ecx,cx
	mov	ax,ds: word ptr [shift_mode_size]
	cmp	ax,3h
	jne	set_pixel_1
	shl	ecx,3h
	cmp	ecx,VESA_MAX_HORIZONTAL_BYTE
	ja	fail_scanline
	jmp	entry_for_pixel
set_pixel_1:
	cmp	ax,2h
	je	entry_for_pixel
	shr	cx,1h
	cmp	ah,1h
	je	entry_for_pixel
	shr	cx,1h
	jmp	entry_for_pixel
scanline_3:
	cmp	bl,VESA_GET_MAX_SCANLINE_LEN
	jne	continue_int_10
	movzx	eax,ds: word ptr [vesa_memory]
	shl	eax,10h
	xor	edx,edx
	movzx	ebx,ds: word ptr [y_res]
	div	ebx
	cmp	eax,VESA_MAX_HORIZONTAL_BYTE
	jb	valid_max_scanline
	mov	eax,VESA_MAX_HORIZONTAL_BYTE
valid_max_scanline:
	xchg	eax,ebx
	mov	ax,ds: word ptr [shift_mode_size]
	cmp	ax,3h
	jne	get_max_pixel_1
	and	ebx,0FFFFFFF0h
	mov	ecx,ebx
	shl	ecx,3h
	cmp	ecx,VESA_MAX_HORIZONTAL_BYTE
	jbe	calc_ver_max
	mov	ecx,0FFF0h
	mov	ebx,0FFFh
	jmp	calc_ver_max	
get_max_pixel_1:
	and	ebx,0FFFFFFF8h
	mov	ecx,ebx
	cmp	ax,2h
	je	calc_ver_max
	mov	ecx,ebx
	shr	ecx,1h
	cmp	ah,1h
	je	calc_ver_max
	shr	ecx,1h
calc_ver_max:
	movzx	edx,ds: word ptr [x_res]
	cmp	ecx,edx
	jb	fail_scanline
	movzx	eax,ds: word ptr [vesa_memory]
	shl	eax,10h
	xor	edx,edx
	div	ebx
	cmp	eax,VESA_MAX_VERTICAL_PIXEL
	jbe	valid_max_vertical
	mov	eax,VESA_MAX_VERTICAL_PIXEL
valid_max_vertical:
	mov	ds: word ptr [byte_per_scanline],bx
	mov	ds: word ptr [pixel_per_scanline],cx
	mov	ds: word ptr [max_scanline],ax
	jmp	enter_get_scanline
continue_int_10:
	pop	ds
	popad
	jmp	go_int_10
fail_scanline:
	pop	ds
	popad
	mov	ax,(VESA_FAIL SHL 8h) + VESA_ID
	iret
continue_int_10_4:
	cmp	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_START_ADDRESS
	jne	continue_int_10_5
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_FLAG_VESA_MODE_TSR
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
	add	dl,VGA_INPUT_STATUS_REGISTER_DIFF
	cmp	bl,VESA_SET_START_ADDRESS
	je	set_start_address
	cmp	bl,VESA_SET_START_ADDRESS_RETRACE
	je	check_vretrace_status
	popa
	jmp	go_int_10
check_vretrace_status:
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_VSYNC_OFF_FLAG_TSR
	jne	set_start_address
vretrace_off:
	in	al,dx
	test	al,VGA_RETRACE
	jne	vretrace_off
vretrace_on:
	in	al,dx
	test	al,VGA_RETRACE
	je	vretrace_on
set_start_address:
	sub	dx,VGA_INPUT_STATUS_REGISTER_DIFF
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
	add	dx,VGA_INPUT_STATUS_REGISTER_DIFF
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
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_ONE_PAGE_FLAG_TSR
	je	set_page_number
	mov	es: byte ptr [di].ModeInfoBlock.LinNumberOfImagePages,VESA_ONE_PAGE_AVAILABLE
	mov	es: byte ptr [di].ModeInfoBlock.NumberOfImagePages,VESA_ONE_PAGE_AVAILABLE
	mov	es: byte ptr [di].ModeInfoBlock.BnkNumberOfImagePages,VESA_ONE_PAGE_AVAILABLE
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
	or	eax,eax
	je	no_page_available
	cmp	eax,VESA_MAX_PAGE_AVAILABLE
	jbe	valid_pages
	mov	al,VESA_MAX_PAGE_AVAILABLE
valid_pages:
	dec	ax
no_page_available:
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
	pushf
	call 	cs: dword ptr [old_int_10_off]
	cmp	ax,VESA_ID
	jne	exit_vesa_get_info
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_FORCE_VESA_MEMORY_TSR
	je	test_vesa_2_mode
	push	cs: word ptr [vesa_memory]
	pop	es: word ptr [di].VbeInfoBlock.TotalMemory
test_vesa_2_mode:
	test	cs: byte ptr [status_flag_0_tsr],NEWAX_VESA2_FLAG_TSR
	je	exit_vesa_get_info
	mov	es: word ptr [di].VbeInfoBlock.VbeVersion,VESA_2
exit_vesa_get_info:
	iret
go_int_10:
	jmp 	cs: dword ptr [old_int_10_off]

;#INPUT#######################################################################
;
;	CX = Offset registers
;
;#OUTPUT######################################################################
;
;	NONE
;
;#COMMENT#####################################################################
;
;	Set Nvidia complete offset registers
;
;#############################################################################

Set_Nvidia_Complete_Offset	proc	near

	call	Get_CRTC_Port
	call	Unlock_Nvidia_Extended_Registers
	mov	al,VGA_CRTC_OFFSET
	out	dx,al
	inc	dx
	mov	al,cl
	out	dx,al
	dec	dx
	mov	al,NVIDIA_EXTENDED_OFFSET
	out	dx,al
	inc	dx
	mov	al,ch
	out	dx,al
	dec	dx
	ret
	                  	
Set_Nvidia_Complete_Offset	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	NONE
;
;#COMMENT#####################################################################
;
;	Reset Nvidia extended start address
;
;#############################################################################

Reset_Nvidia_Start_Address	proc	near

	call	Get_CRTC_Port
	xor	cx,cx
	call	Set_Nvidia_Extended_Start_Address
	ret

Reset_Nvidia_Start_Address	endp

;#INPUT#######################################################################
;
;	DX = CRTC port
;
;#OUTPUT######################################################################
;
;	NONE
;
;#COMMENT#####################################################################
;
;	Unlock Nvidia extended registers
;
;#############################################################################

Unlock_Nvidia_Extended_Registers	proc	near

	mov	al,NVIDIA_CRTC_UNLOCK_REG
	out	dx,al
	inc	dx
	mov	al,NVIDIA_CRTC_UNLOCK_VALUE
	out	dx,al
	dec	dx
	ret

Unlock_Nvidia_Extended_Registers	endp

;#INPUT#######################################################################
;
;	CX = Nvidia Extended start address
;	DX = CRTC port
;
;#OUTPUT######################################################################
;
;	NONE
;
;#COMMENT#####################################################################
;
;	Set Nvidia extended start address
;
;#############################################################################

Set_Nvidia_Extended_Start_Address	proc	near

	call	Unlock_Nvidia_Extended_Registers
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

Set_Nvidia_Extended_Start_Address	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	DX = CRTC port
;
;#COMMENT#####################################################################
;
;	Return CRTC port
;
;#############################################################################

Get_CRTC_Port	proc	near

	mov	dx,VGA_READ_MISCELLANEOUS_REG
	in	al,dx
	and	al,VGA_CRTC_ADDRESS
	shl	al,VGA_CRTC_ADDRESS_SHIFT
	mov	dx,VGA_CRTC_MONO
	add	dl,al
	ret

Get_CRTC_Port	endp

old_int_10_off:
	DW	?
old_int_10_seg:
	DW	?
new_int_10_off:
	DW	?
new_int_10_seg:
	DW	?
start_x:
	DW	?
start_y:
	DW	?
shift_mode_size:
	DW	?
vesa_memory:
	DW	?
vesa_mode:
	DW	?
byte_per_scanline:
	DW	?
pixel_per_scanline:
	DW	?
max_scanline:
	DW	?
x_res:
	DW	?
y_res:
	DW	?
status_flag_0_tsr:
	DB	0h
vesa_buffer_func_1:
	ModeInfoBlock <>
install:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_00
	int	DOS_INTERRUPT
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_01
	mov	ax,(DOS_FUNC_GET_VERSION_NUMBER SHL 8h) + DOS_VerOrOEMFlag
	int	DOS_INTERRUPT
	cmp	al,DOS_VERSION_MIN
	jb	exit_with_print
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_02
	mov	cx,HW_END_SEGMENT
	rep	lods	es: byte ptr [si]
	jcxz	pass_386_mode
exit_with_print:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,ds: word ptr [dos_message_pointer]
	int	DOS_INTERRUPT
exit_newax:
	mov	ax,(DOS_FUNC_END_PROGRAM SHL 8h) + DOS_ReturnValue
	int	DOS_INTERRUPT
pass_386_mode:
	mov	al,HW_TEST_SHIFT_VAL
	mov	cl,HW_TEST_SHIFT
	shl	al,cl
	or	al,al
	je	exit_with_print
	push	sp
	pop	ax
	cmp	ax,sp
	jne	exit_with_print
	pushf
	pop	ax
	or	ah,HW_FLAG_ID
	push	ax
	popf
	pushf
	pop	ax
	test	ah,HW_FLAG_ID
	je	exit_with_print
	mov	si,OFFSET void_buffer
	call	Get_Args
	lodsb
	or	al,al
	je	go_install
	cmp	al,NEWAX_ONE_ARGS
	jne	next_args
	or	ds: byte ptr [status_flag_0],NEWAX_SINGLE_ARG_FLAG
next_args:
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_05
	lodsw
	xchg	ax,di
	mov	ax,ds: word ptr [di]
	cmp	ax,'M/'
	je	set_mem_vesa
	cmp	ax,'m/'
	jne	test_next_arg_0
set_mem_vesa:
	cmp	ds: byte ptr [di + SIZEOF WORD],':'
	jne	exit_with_print
	mov	bx,SIZEOF WORD + SIZEOF BYTE
	xor	edx,edx
loop_asci2dec:
	movzx	eax,ds: byte ptr [bx + di]
	or	al,al
	je	end_loop_asci2dec
	cmp	al,'0'
	jb	exit_with_print
	cmp	al,'9'
	ja	exit_with_print
	sub	al,'0'
	imul	edx,TEN_DIGIT
	add	edx,eax
	inc	bx
	cmp	bl,7h + SIZEOF WORD + SIZEOF BYTE
	je	exit_with_print
	jmp	loop_asci2dec
end_loop_asci2dec:
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_35
	shr	edx,6h
	cmp	dx,VESA_MIN_MEM
	jb	exit_with_print
	cmp	dx,VESA_MAX_MEM
	ja	exit_with_print
	mov	ds: word ptr [vesa_memory],dx
	or	ds: byte ptr [status_flag_1],NEWAX_FORCE_VESA_MEMORY
	jmp	dec_next_args
test_next_arg_0:
	cmp	ds: byte ptr [di + SIZEOF WORD],NEWAX_STRING_TERMINATOR
	jne	exit_with_print
	cmp	ax,'1/'
	jne	test_next_arg_1
	test	ds: byte ptr [status_flag_0],NEWAX_ONE_PAGE_FLAG
	jne	exit_with_print
	or	ds: byte ptr [status_flag_0],NEWAX_ONE_PAGE_FLAG
	jmp	dec_next_args
test_next_arg_1:
	cmp	ax,'2/'
	jne	test_next_arg_2
	test	ds: byte ptr [status_flag_0],NEWAX_VESA2_FLAG
	jne	exit_with_print
	or	ds: byte ptr [status_flag_0],NEWAX_VESA2_FLAG
	jmp	dec_next_args
test_next_arg_2:
	and	ah,NEWAX_UPPER_CASE
	cmp	ax,'V/'
	jne	test_vbepmi_arg
	test	ds: byte ptr [status_flag_1],NEWAX_VSYNC_OFF_FLAG
	jne	exit_with_print
	or	ds: byte ptr [status_flag_1],NEWAX_VSYNC_OFF_FLAG
	jmp	dec_next_args
test_vbepmi_arg:

	cmp	ax,'P/'
	jne	test_next_arg_3
	test	ds: byte ptr [status_flag_0],NEWAX_VBEPMI_FLAG
	jne	exit_with_print
	or	ds: byte ptr [status_flag_0],NEWAX_VBEPMI_FLAG
	jmp	dec_next_args
test_next_arg_3:
	cmp	ax,'U/'
	jne	test_next_arg_4
	test	ds: byte ptr [status_flag_0],NEWAX_SINGLE_ARG_FLAG
	je	exit_with_print
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_06
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	exit_with_print
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_13
	push	BIOS_INTERRUPT_SEGMENT
	pop	fs
	mov	eax,fs: dword ptr [VIDEO_INTERRUPT * SIZEOF DWORD]
	cmp	eax,es: dword ptr [new_int_10_off]
	jne	exit_with_print
	lds	dx,es: dword ptr [old_int_10_off]
	mov	ax,(DOS_FUNC_SET_INTERRUPT_VECTOR SHL 8h) + VIDEO_INTERRUPT
	int	DOS_INTERRUPT
	push	cs
	pop	ds
	mov	ah,DOS_FUNC_FREE_MEMORY
	int	DOS_INTERRUPT
	jc	exit_with_print
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_14
	jmp	exit_with_print
test_next_arg_4:
	cmp	ax,'S/'
	jne	test_next_arg_5
	test	ds: byte ptr [status_flag_0],NEWAX_SINGLE_ARG_FLAG
	je	exit_with_print
	call	Check_VESA_Override_Function
	call	Found_NVIDIA_Card
	jnc	continue_status_1
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	exit_with_print
entry_force_1:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_36
	int	DOS_INTERRUPT
	jmp	entry_for_force_switch
continue_status_1:
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	continue_status_2
	test	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED_PRIMARY
	je	entry_force_1
continue_status_2:
	mov	ax,ds: word ptr [pci_version]
	shr	ax,HW_16BIT_HIGH
	mov	cx,1h
	mov	si,OFFSET dos_message_15 + 0Dh
	call	Write_Integer_Number16
	mov	ax,ds: word ptr [pci_version]
	shr	ax,(HW_16BIT_HIGH SHR 1h)
	and	ax,(1h SHL (HW_16BIT_HIGH SHR 1h)) - 1h
	mov	si,OFFSET dos_message_15 + 0Fh
	call	Write_Integer_Number16
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_15
	int	DOS_INTERRUPT
	movzx	ax,ds: byte ptr [pci_spec]
	mov	si,OFFSET dos_message_16 + 15h
	mov	cx,3h
	call	Write_Integer_Number16
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_16
	int	DOS_INTERRUPT
	movzx	ax,ds: byte ptr [pci_buses]
	mov	si,OFFSET dos_message_17 + 0Dh
	mov	cx,3h
	call	Write_Integer_Number16
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_17
	int	DOS_INTERRUPT
entry_for_force_switch:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_18
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_20
	test	ds: byte ptr [status_flag_0],NEWAX_VESA_SCANLINE
	jne	no_scan_line
	mov	dx,OFFSET dos_message_21
no_scan_line:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_19
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_20
	test	ds: byte ptr [status_flag_0],NEWAX_VESA_START_ADDRESS
	jne	no_start_address
	mov	dx,OFFSET dos_message_21
no_start_address:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	continue_status_3
	test	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED_PRIMARY
	je	entry_force_2
continue_status_3:
	call	Write_Nvidia_Detect
	je	exit_newax
	call	Detect_Supported_Nvidia
	mov	si,OFFSET dos_message_26 + 10h
	mov	ax,ds: word ptr [nvidia_device_id]
	mov	cx,4h
	call	Write_Hex_Number	
	mov	si,OFFSET dos_message_26 + 1Fh
	mov	al,ds: byte ptr [nvidia_revision]
	mov	cx,2h
	call	Write_Hex_Number
	mov	si,OFFSET dos_message_26 + 31h
	mov	ax,ds: word ptr [nvidia_subsys_id]
	mov	cx,4h
	call	Write_Hex_Number	
	mov	si,OFFSET dos_message_26 + 36h
	mov	ax,ds: word ptr [nvidia_subsys_id + 2h]
	mov	cx,4h
	call	Write_Hex_Number	
	mov	dx,OFFSET dos_message_26
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	si,OFFSET dos_message_28 + 0Eh
	movzx	ax,ds: byte ptr [bus_number]
	mov	cx,3h
	call	Write_Integer_Number16
	mov	si,OFFSET dos_message_28 + 1Bh
	movzx	ax,ds: byte ptr [devfun_number]
	shr	al,3h
	mov	cx,2h
	call	Write_Integer_Number16
	mov	si,OFFSET dos_message_28 + 28h
	movzx	ax,ds: byte ptr [devfun_number]
	and	al,7h
	mov	cx,1h
	call	Write_Integer_Number16
	mov	dx,OFFSET dos_message_28
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
entry_force_2:
	mov	dx,OFFSET dos_message_29
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	call	Check_NEWAX_Install
	mov	dx,OFFSET dos_message_31
	cmp	ax,VESA_ID
	jne	newax_not_installed
	mov	dx,OFFSET dos_message_30
newax_not_installed:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	cmp	dx,OFFSET dos_message_31
	je	exit_newax
	mov	al,1h
	mov	si,OFFSET flag_dos_message
next_status_flag:
	mov	dx,ds: word ptr [si]
	test	es: byte ptr [status_flag_0_tsr],al
	jne	no_flag_status
	mov	dx,ds: word ptr [si + SIZEOF WORD]
no_flag_status:
	push	ax
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	pop	ax
	add	si,SIZEOF DWORD
	add	al,al
	cmp	al,NEWAX_LAST_FLAG
	jne	next_status_flag
	mov	dx,OFFSET dos_message_37
	test	es: byte ptr [status_flag_0_tsr],NEWAX_VSYNC_OFF_FLAG_TSR
	jne	vsync_forced_to_off_1
	mov	dx,OFFSET dos_message_38
vsync_forced_to_off_1:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
test_status_vesa_memory:
	test	es: byte ptr [status_flag_0_tsr],NEWAX_FORCE_VESA_MEMORY_TSR
	je	exit_newax
	mov	si,OFFSET dos_message_34 + 1Ch
	movzx	eax,es: word ptr [vesa_memory]
	shl	eax,6h
	mov	cx,6h
	call	Write_Integer_Number32
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_34
	int	DOS_INTERRUPT
	jmp	exit_newax
test_next_arg_5:
	cmp	ax,'F/'
	jne	exit_with_print
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_04
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	je	exit_with_print
	or	ds: byte ptr [status_flag_1],NEWAX_FORCE_INSTALL
dec_next_args:
	dec	ds: byte ptr [void_buffer]
	jne	next_args
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	go_install
	test	ds: byte ptr [status_flag_1],NEWAX_FORCE_VESA_MEMORY
	je	no_force_vesa_memory
	mov	ax,ds: word ptr [vesa_memory]
	mov	es: word ptr [vesa_memory],ax
	or	es: byte ptr [status_flag_0_tsr],NEWAX_FORCE_VESA_MEMORY_TSR
	mov	si,OFFSET dos_message_34 + 1Ch
	movzx	eax,es: word ptr [vesa_memory]
	shl	eax,6h
	mov	cx,6h
	call	Write_Integer_Number32
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_34
	int	DOS_INTERRUPT
no_force_vesa_memory:
	call	Write_NEWAX_Status_Flag
	jmp	exit_newax
go_install:
	test	ds: byte ptr [status_flag_1],NEWAX_FORCE_INSTALL
	jne	force_newax_install
	call	Found_NVIDIA_Card
	jc	exit_with_print
	call	Detect_Supported_Nvidia
	jc	exit_newax
	call	Write_Nvidia_Detect
	je	exit_newax
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_04
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	je	exit_with_print
force_newax_install:
	call	Check_VESA_Override_Function
	test	ds: byte ptr [status_flag_1],NEWAX_FORCE_VESA_MEMORY
	jne	force_vesa_memory
	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_32
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_GET_INFO
	mov	di,OFFSET vesa_buffer_func_0
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	exit_with_print
	mov	ax,ds: word ptr [di].VbeInfoBlock.TotalMemory
	mov	ds: word ptr [vesa_memory],ax
	jmp	no_force_vesa_memory_tsr
force_vesa_memory:
	mov	si,OFFSET dos_message_34 + 1Ch
	movzx	eax,ds: word ptr [vesa_memory]
	shl	eax,6h
	mov	cx,6h
	call	Write_Integer_Number32
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_34
	int	DOS_INTERRUPT
	or	ds: byte ptr [status_flag_0_tsr],NEWAX_FORCE_VESA_MEMORY_TSR
no_force_vesa_memory_tsr:
	call	Write_NEWAX_Status_Flag
	push	BIOS_INTERRUPT_SEGMENT
	pop	fs
	push	fs: dword ptr [VIDEO_INTERRUPT * SIZEOF DWORD]
	pop	ds: dword ptr [old_int_10_off]
	mov	dx,OFFSET new_int_10
	mov	ds: word ptr [new_int_10_off],dx
	mov	ds: word ptr [new_int_10_seg],ds
	mov	ax,(DOS_FUNC_SET_INTERRUPT_VECTOR SHL 8h) + VIDEO_INTERRUPT
	int	DOS_INTERRUPT
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_33
	int	DOS_INTERRUPT
	mov	es,ds: word ptr [DOS_OFFSET_pspEnvironment]
	mov	ah,DOS_FUNC_FREE_MEMORY
	int	DOS_INTERRUPT
	mov	ds: word ptr [DOS_OFFSET_pspEnvironment],DOS_NO_ENVIRONMENT
	mov 	dx,OFFSET install
	int	DOS_TSR_INTERRUPT

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	NONE
;
;#COMMENT#####################################################################
;
;	Write NEWAX status flags
;
;#############################################################################

	Write_NEWAX_Status_Flag	proc	near

	mov	al,1h
	mov	si,OFFSET flag_dos_message
next_set_flag:
	test	ds: byte ptr [status_flag_0],al
	je	no_set_flag
	xor	es: byte ptr [status_flag_0_tsr],al
	mov	dx,ds: word ptr [si]
	test	es: byte ptr [status_flag_0_tsr],al
	jne	no_flag_set
	mov	dx,ds: word ptr [si + SIZEOF WORD]
no_flag_set:
	push	ax
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	pop	ax
no_set_flag:
	add	si,SIZEOF DWORD
	add	al,al
	cmp	al,NEWAX_LAST_FLAG
	jne	next_set_flag
	test	ds: byte ptr [status_flag_1],NEWAX_VSYNC_OFF_FLAG
	je	no_force_vsync
	xor	es: byte ptr [status_flag_0_tsr],NEWAX_VSYNC_OFF_FLAG_TSR
	mov	dx,OFFSET dos_message_37
	test	es: byte ptr [status_flag_0_tsr],NEWAX_VSYNC_OFF_FLAG_TSR
	jne	vsync_forced_to_off
	mov	dx,OFFSET dos_message_38
vsync_forced_to_off:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
no_force_vsync:
	ret

	Write_NEWAX_Status_Flag	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	C(0) = Supported
;	Z(1) = Not supported
;
;#COMMENT#####################################################################
;
;	Detect Nvidia supported card
;
;#############################################################################

	Detect_Supported_Nvidia	proc	near


	call	Get_CRTC_Port
	mov	al,NVIDIA_CRTC_UNLOCK_REG
	out	dx,al
	inc	dx
	in	al,dx
	xchg	ax,bx
	dec	dx
	mov	al,NVIDIA_CRTC_UNLOCK_REG
	out	dx,al
	mov	al,NVIDIA_CRTC_LOCK_VALUE
	inc	dx
	out	dx,al
	dec	dx
	mov	al,NVIDIA_EXTENDED_OFFSET
	out	dx,al
	inc	dx
	in	al,dx
	mov	ah,al
	dec	dx
	mov	al,NVIDIA_EXTENDED_OFFSET
	out	dx,al
	inc	dx
	mov	al,ah
	xor	al,0FFh
	out	dx,al
	dec	dx
	mov	al,NVIDIA_EXTENDED_OFFSET
	out	dx,al
	inc	dx
	in	al,dx
	cmp	al,ah
	jne	no_nvidia_supported
	clc
	ret
no_nvidia_supported:
	mov	al,NVIDIA_EXTENDED_OFFSET
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	dec	dx
	mov	al,NVIDIA_CRTC_UNLOCK_REG
	out	dx,al
	inc	dx
	xchg	ax,bx
	out	dx,al
	mov	dx,OFFSET dos_message_39
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	stc
	ret
	
        Detect_Supported_Nvidia	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	Z(0) = Not detected
;	Z(1) = Detected
;
;#COMMENT#####################################################################
;
;	Write message for detected Nvidia card
;
;#############################################################################

	Write_Nvidia_Detect	proc	near
	
	mov	dx,OFFSET dos_message_22
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	mov	dx,OFFSET dos_message_24
	test	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED OR NEWAX_NVIDIA_DETECTED_PRIMARY
	je	write_nvidia_detect
	mov	dx,OFFSET dos_message_23
	test	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED_PRIMARY
	jne	write_nvidia_detect
	mov	dx,OFFSET dos_message_25
write_nvidia_detect:
	mov	ah,DOS_FUNC_DISPLAY_STRING
	int	DOS_INTERRUPT
	test	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED_PRIMARY
	ret

	Write_Nvidia_Detect	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	DS: BYTE [status_flag_0] = VESA function status
;
;#COMMENT#####################################################################
;
;	Check VESA function 4F07h and 4f06h
;
;#############################################################################

	Check_VESA_Override_Function	proc	near

	pusha
	call	Check_NEWAX_Install
	cmp	ax,VESA_ID
	jne	direct_vesa_check
	mov	al,es: byte ptr [status_flag_0_tsr]
	and	al,NEWAX_VESA_SCANLINE_TSR OR NEWAX_VESA_START_ADDRESS_TSR
	or	ds: byte ptr [status_flag_0],al
	mov	ax,cs
	mov	es,ax
	popa
	ret
direct_vesa_check:
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_OPEN_VIDEO_MODE
	mov	bx,VESA_VIDEO_MODE_640X480X8
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	jne	fail_direct_check
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_SCANLINE
	mov	bl,VESA_GET_SCANLINE
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	je	valid_func_scanline
	or	ds: byte ptr [status_flag_0],NEWAX_VESA_SCANLINE
valid_func_scanline:
	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_SET_GET_START_ADDRESS
	mov	bx,VESA_SET_START_ADDRESS
	mov	cx,VESA_TEST_HORIZONTAL_START
	mov	dx,VESA_TEST_VERTICAL_START
	int	VIDEO_INTERRUPT
	cmp	ax,VESA_ID
	je	fail_direct_check
	or	ds: byte ptr [status_flag_0],NEWAX_VESA_START_ADDRESS
fail_direct_check:
	mov	ax,(VGA_FUNC_SET_MODE SHL 8h) + VGA_VIDEO_MODE_80x25XTEXT
	int	VIDEO_INTERRUPT
	mov	ah,DOS_FUNC_DISPLAY_STRING
	mov	dx,OFFSET dos_message_00
	int	DOS_INTERRUPT
	mov	al,ds: byte ptr [status_flag_0]
	and	al,NEWAX_VESA_SCANLINE OR NEWAX_VESA_START_ADDRESS
	or	ds: byte ptr [status_flag_0_tsr],al
	popa
	ret

	Check_VESA_Override_Function	endp

;#INPUT#######################################################################
;
;	DS:SI = Offset for integer number
;	EAX = Integer number
;	CX = Integer digits
;
;#OUTPUT######################################################################
;
;	DS:SI = Written integer number:
;
;#COMMENT#####################################################################
;
;	Write integer 32 bit number at offset DS:SI
;
;#############################################################################

	Write_Integer_Number32	proc	near

	pushad
next_integer_digit_32:
	xor	edx,edx
	mov	ebx,TEN_DIGIT
	div	ebx
	add	dl,'0'
	mov	ds: byte ptr [si],dl
	dec	si
	loop	next_integer_digit_32
	popad
	ret

	Write_Integer_Number32	endp


;#INPUT#######################################################################
;
;	DS:SI = Offset for integer number
;	AX = Integer number
;	CX = Integer digits
;
;#OUTPUT######################################################################
;
;	DS:SI = Written integer number:
;
;#COMMENT#####################################################################
;
;	Write integer 16 bit number at offset DS:SI
;
;#############################################################################

	Write_Integer_Number16	proc	near

	pusha
next_integer_digit_16:
	xor	dx,dx
	mov	bx,TEN_DIGIT
	div	bx
	add	dl,'0'
	mov	ds: byte ptr [si],dl
	dec	si
	loop	next_integer_digit_16
	popa
	ret

	Write_Integer_Number16	endp

;#INPUT#######################################################################
;
;	DS:SI = Offset for hexadecimal number
;	AX = Hexadecimal number
;	CX = Hexadecimal digits
;
;#OUTPUT######################################################################
;
;	DS:SI = Written hexadecimal number:
;
;#COMMENT#####################################################################
;
;	Write hexadecimal number at offset DS:SI
;
;#############################################################################

	Write_Hex_Number	proc	near

	pusha
next_hex_digit:
	mov	dl,al
	shr	ax,4h
	and	dl,0Fh
	add	dl,'0'
	cmp	dl,'9'
	jbe	num_hex
	add	dl,7h
num_hex:
	mov	ds: byte ptr [si],dl
	dec	si
	loop	next_hex_digit
	popa
	ret

	Write_Hex_Number	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	CARRY(0) = Nvidia card found
;	CARRY(1) = Nvidia card not found
;		DS: WORD [dos_message_pointer] = Error message
;
;#COMMENT#####################################################################
;
;	Found primary Nvidia graphic card
;
;#############################################################################

	Found_NVIDIA_Card	proc	near

	mov	ds: word ptr [dos_message_pointer],OFFSET dos_message_03
	mov	ax,PCI_FUNC_INSTALLATION_CHECK
	xor	edi,edi
	int	1Ah
	jc	no_pci_bus
	or	ah,ah
	jne	no_pci_bus
	cmp	edx,' ICP'
	jne	no_pci_bus
	mov	ds: byte ptr [pci_spec],al
	mov	ds: word ptr [pci_version],bx
	mov	ds: byte ptr [pci_bus],cl
	inc	cx
	mov	ds: byte ptr [pci_buses],cl
read_pci_device:
	xor	di,di
	call	Read_PCI_Data_Dword
	jc	next_pci_device
	or	ah,ah
	jne	next_pci_device
	cmp	cx,PCI_NO_DEVICE
	je	next_pci_device
	or	cx,cx
	je	next_pci_device
	cmp	cx,NVIDIA_PCI_ID
	jne	end_pci_probe
	shr	ecx,HW_32BIT_HIGH
	mov	ds: word ptr [nvidia_device_id],cx
	mov	di,PCI_HEADER_REGISTER
	call	Read_PCI_Data_Dword
	shr	ecx,HW_32BIT_HIGH
	mov	dl,cl
	test	cl,PCI_HEADER_LAYOUT
	jne	end_pci_probe
	mov	di,PCI_SUBSYSTEM_ID_REGISTER
	call	Read_PCI_Data_Dword
	mov	ds: dword ptr [nvidia_subsys_id],ecx
	mov	di,PCI_CLASS_CODE_REGISTER
	call	Read_PCI_Data_Dword
	mov	ds: byte ptr [nvidia_revision],cl
	shr	ecx,HW_16BIT_HIGH
	cmp	cl,PCI_VGA_INTERFACE
	jne	end_pci_probe
	shr	ecx,HW_16BIT_HIGH
	cmp	cl,PCI_VGA_SUB_CLASS
	jne	end_pci_probe
	shr	ecx,HW_16BIT_HIGH
	cmp	cl,PCI_VGA_BASE_CLASS
	jne	end_pci_probe
	or	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED
	mov	dx,VGA_PEL_MASK_REG
	in	al,dx
	mov	bh,al
	mov	al,VGA_PEL_MASK_ID1
	out	dx,al
	mov	di,PCI_COMMAND_REGISTER
	call	Read_PCI_Data_Dword
	mov	esi,ecx
	and	ecx,NOT (PCI_COMMAND_IO_SPACE_FLAG OR PCI_COMMAND_MEMORY_SPACE_FLAG)
	movzx	eax,ds: byte ptr [bus_number]
	shl	eax,HW_32BIT_HIGH
	mov	al,ds: byte ptr [devfun_number]
	shl	ax,HW_16BIT_HIGH
	add	ax,di
	or	eax,PCI_ENABLE
	mov	dx,PCI_REG_START
	out	dx,eax
	xchg	eax,ebp
	mov	dl,(PCI_REG_START AND HW_BYTE_MASK) + SIZEOF DWORD
	xchg	eax,ecx
	cli
	out	dx,eax
	push	dx
	mov	dx,VGA_PEL_MASK_REG
	mov	al,VGA_PEL_MASK_ID2
	out	dx,al
	in	al,dx
	mov	bl,al
	pop	dx
	xchg	eax,ebp
	mov	dl,(PCI_REG_START AND HW_BYTE_MASK)
	out	dx,eax
	mov	dl,(PCI_REG_START AND HW_BYTE_MASK) + SIZEOF DWORD
	xchg	eax,esi
	out	dx,eax
	sti
	mov	dx,VGA_PEL_MASK_REG
	mov	al,bh
	out	dx,al
	cmp	bl,VGA_PEL_MASK_ID2
	jne	ok_nvidia_card
end_pci_probe:
	test	ds: byte ptr [devfun_number],PCI_MAX_MULTIFUNCTION
	jne	next_pci_device
	test	dl,PCI_MULTIFUNCTION_FLAG
	je	next_dev_pci
	inc	ds: byte ptr [devfun_number]
	jmp	read_pci_device
next_pci_device:
	test	ds: byte ptr [devfun_number],PCI_MAX_MULTIFUNCTION
	je	next_dev_pci
	add	ds: byte ptr [devfun_number],PCI_NEXT_MULTIFUNCTION
	je	entry_pci_dev
	jmp	read_pci_device
next_dev_pci:
	add	ds:byte ptr [devfun_number],PCI_NEXT_DEVICE
	jne	read_pci_device
entry_pci_dev:
	inc	ds: byte ptr [bus_number]
	mov	al,ds: byte ptr [bus_number]
	cmp	al,ds: byte ptr [pci_bus]
	jbe	read_pci_device
	clc
	ret
ok_nvidia_card:
	or	ds: byte ptr [status_flag_0],NEWAX_NVIDIA_DETECTED_PRIMARY
  	clc
	ret
no_pci_bus:
	stc
	ret

	Found_NVIDIA_Card	endp

;#INPUT#######################################################################
;
;	NONE
;
;#OUTPUT######################################################################
;
;	AX = VESA_ID -> Installation checked
;		ES = TSR segment
;	AX != VESA_ID -> Installation not checked
;
;#COMMENT#####################################################################
;
;	Check NEWAX installation
;
;#############################################################################

	Check_NEWAX_Install	proc	near

	mov	ax,(VESA_ID SHL 8h) + VESA_FUNC_MPID_FUNC
	mov	bx,'MP'
	int	VIDEO_INTERRUPT
	ret

	Check_NEWAX_Install	endp

;#INPUT#######################################################################
;
;	DS:SI = Pointer to the memory area for storing pointers to args
;
;#OUTPUT######################################################################
;
;	DS: BYTE [SI] = Number of args = n_args
;	DS: WORD [SI + 1h + <0 ... n_args - 1h>] = Pointer to args
;
;#COMMENT#####################################################################
;
;	Read command line args
;
;#############################################################################

	Get_Args	proc	near

	pusha
	xor	bx,bx
	push	si
	inc	si
	mov	di,DOS_OFFSET_INIT_ARGS
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

	Get_Args	endp

;#INPUT#######################################################################
;
;	DI = PCI register
;	DS: BYTE [bus_number] = PCI bus number
;	DS: BYTE [devfun_number] = PCI device/function number
;
;#OUTPUT######################################################################
;
;	CARRY(0) = Ok
;		AH = 0x00
;		ECX = Data read
;	CARRY(1) = Error
;		AH = Error
;
;#COMMENT#####################################################################
;
;	Read PCI addressing space dword register
;
;#############################################################################

	Read_PCI_Data_Dword	proc	near

	push	ebx
	push	edx
	push	esi
	push	edi
	push	ebp	
	mov	ax,PCI_FUNC_READ_CONFIGURATION_DWORD
	mov	bh,ds: byte ptr [bus_number]
	mov	bl,ds: byte ptr [devfun_number]
	int	PCI_INTERRUPT
	pushf
	or	di,di
	jne	valid_pci_read_bios
	mov	al,ds: byte ptr [devfun_number]
	and	al,PCI_MAX_MULTIFUNCTION
	or	al,al
	je	valid_pci_read_bios
	cmp	ecx,PCI_NO_DEVICE_LONG
	jne	valid_pci_read_bios
	movzx	eax,ds: byte ptr [bus_number]
	shl	eax,HW_32BIT_HIGH
	mov	al,ds: byte ptr [devfun_number]
	shl	ax,HW_16BIT_HIGH
	add	ax,di
	or	eax,PCI_ENABLE
	mov	dx,PCI_REG_START
	out	dx,eax
	mov	dl,(PCI_REG_START AND HW_BYTE_MASK) + SIZEOF DWORD
	in	eax,dx
	xchg	eax,ecx
	xor	ah,ah
	popf
	clc
	jmp	entry_exit_pci
valid_pci_read_bios:
	popf
entry_exit_pci:
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ebx
	ret

	Read_PCI_Data_Dword	endp

dos_message_00:
	DB	'Nvidia kEpler/maxWell/pAscal fiX - NEWAX ',NEWAX_VER,' - NVIDIA mode',0Dh,0Ah,'$'
dos_message_01:
	DB	'Invalid DOS version (5.0 or above)',0Dh,0Ah,'$'
dos_message_02:
	DB	'Failed to detect 80386 or above processor',0Dh,0Ah,'$'
dos_message_03:
	DB	'Fail to detect PCI BIOS',0Dh,0Ah,'$'
dos_message_04:
	DB	'NEWAX already installed',0Dh,0Ah,'$'
dos_message_05:
	DB	'Use: NEWAX.COM [/2] [/P] [/1] [/F] [/V] [/M:mmmmmm] - Install TSR',0Dh,0Ah
	DB	'     NEWAX.COM /U  - Uninstall from memory',0Dh,0Ah
	DB	'     NEWAX.COM /S  - View status',0Dh,0Ah
	DB	'               [/2] = Toggle VESA 2.0/3.0',0Dh,0Ah
	DB	'               [/P] = Toggle VBE/PMI',0Dh,0Ah
	DB	'               [/1] = Toggle one page mode',0Dh,0Ah
	DB	'               [/V] = Toggle force VSync off',0Dh,0Ah
	DB	'               [/F] = Force NEWAX installation',0Dh,0Ah
	DB	'               [/M:mmmmmm] = Set VESA memory to mmmmmm KiB',0Dh,0Ah,'$'
dos_message_06:
	DB	'NEWAX not installed',0Dh,0Ah,'$'
dos_message_07:
	DB	'One page mode: Enabled',0Dh,0Ah,'$'
dos_message_08:
	DB	'One page mode: Disabled',0Dh,0Ah,'$'
dos_message_09:
	DB	'VESA 2.0: Enabled',0Dh,0Ah,'$'
dos_message_10:
	DB	'VESA 2.0: Disabled',0Dh,0Ah,'$'
dos_message_11:
	DB	'VBE/PMI: Enabled',0Dh,0Ah,'$'
dos_message_12:
	DB	'VBE/PMI: Disabled',0Dh,0Ah,'$'
dos_message_13:
	DB	'Can''t uninstall NEWAX',0Dh,0Ah,'$'
dos_message_14:
	DB	'NEWAX uninstalled',0Dh,0Ah,'$'
dos_message_15:
	DB	'PCI version: X.X',0Dh,0Ah,'$'
dos_message_16:
	DB	'PCI specification: XXX',0Dh,0Ah,'$'
dos_message_17:
	DB	'PCI buses: XXX',0Dh,0Ah,'$'
dos_message_18:
	DB	'Original Logical Scanline Length (4F06h): $'
dos_message_19:
	DB	'Original Display Start Address/Panning (4F07h): $'
dos_message_20:
	DB	'Fail',0Dh,0Ah,'$'
dos_message_21:
	DB	'Supported',0Dh,0Ah,'$'
dos_message_22:
	DB	'Nvidia graphic card: $'
dos_message_23:
	DB	'Detected',0Dh,0Ah,'$'
dos_message_24:
	DB	'Not detected',0Dh,0Ah,'$'
dos_message_25:
	DB	'Detected but no primary',0Dh,0Ah,'$'
dos_message_26:
	DB	'PCI_ID: 10DE_XXXX - Revision: XX - SUBSYS_ID: XXXX_XXXX',0Dh,0Ah,'$'
dos_message_28:
	DB	'Bus number: XXX - Device: XX - Function X',0Dh,0Ah,'$'
dos_message_29:
	DB	'NEWAX: $'
dos_message_30:
	DB	'Installed',0Dh,0Ah,'$'
dos_message_31:
	DB	'Not installed',0Dh,0Ah,'$'
dos_message_32:
	DB	'VESA not found',0Dh,0Ah,'$'
dos_message_33:
	DB	'NEWAX installed',0Dh,0Ah,'$'
dos_message_34:
	DB	'Forced VESA memory to: 000000 KiB',0Dh,0Ah,'$'
dos_message_35:
	DB	'Invalid forced VESA memory (256-262144 KiB)',0Dh,0Ah,'$'
dos_message_36:
	DB	'NEWAX installed with /F switch',0Dh,0Ah,'$'
dos_message_37:
	DB	'Vsync status: Forced to off',0Dh,0Ah,'$'
dos_message_38:
	DB	'Vsync status: Default',0Dh,0Ah,'$'
dos_message_39:
	DB	'Incompatible Nvidia graphic card',0Dh,0Ah,'$'
flag_dos_message:
	DW	OFFSET dos_message_07,OFFSET dos_message_08
	DW	OFFSET dos_message_09,OFFSET dos_message_10
	DW	OFFSET dos_message_11,OFFSET dos_message_12
bus_number:
	DB	0h
devfun_number:
	DB	0h
status_flag_0:
	DB	0h
status_flag_1:
	DB	0h
dos_message_pointer:
	DW	?
pci_version:
	DW	?
pci_spec:
	DB	?
pci_bus:
	DB	?
pci_buses:
	DB	?
nvidia_device_id:
	DW	?
nvidia_subsys_id:
	DD	?
nvidia_revision:
	DB	?
vesa_buffer_func_0:
	VbeInfoBlock <>
void_buffer:

	CODE ENDS
	END start_code
