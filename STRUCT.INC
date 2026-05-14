VbeInfoBlock STRUC
	VbeSignature		DB 4d DUP (?)
	VbeVersion		DW ?
	OemStringPtr		DD ?
	Capabilities		DB 4d DUP (?)
	VideoModePtr		DD ?
	TotalMemory		DW ?
	OemSoftwareRev		DW ?
	OemVendorNamePtr        DD ?
	OemProductNamePtr	DD ?
	OemProductRevPtr	DD ?
	Reserved1		DB 222d DUP (?)
	OemData			DB 256d DUP (?)
VbeInfoBlock ENDS

ModeInfoBlock STRUC
	ModeAttributes 		DW ?
	WinAAttributes		DB ?
	WinBAttributes		DB ?
	WinGranularity		DW ?
	WinSize			DW ?
	WinASegment		DW ?
	WinBSegment		DW ?
	WinFuncPtr		DD ?
	BytesPerScanLine	DW ?
	XResolution		DW ?
	YResolution		DW ?
	XCharSize		DB ?
	YCharSize		DB ?
	NumberOfPlanes		DB ?
	BitsPerPixel		DB ?
	NumberOfBanks		DB ?
	MemoryModel		DB ?
	BankSize		DB ?
	NumberOfImagePages	DB ?
	Reserved2		DB ?
	RedMaskSize		DB ?
	RedFieldPosition	DB ?
	GreenMaskSize		DB ?
	GreenFieldPosition	DB ?
	BlueMaskSize		DB ?
	BlueFieldPosition	DB ?
	RsvdMaskSize		DB ?
	RsvdFieldPosition	DB ?
	DirectColorModeInfo	DB ?
	PhysBasePtr		DD ?
	OffScreenMemOffset	DD ?
	OffScreenMemSize	DW ?
	LinBytesPerScanLine	DW ?
	BnkNumberOfImagePages	DB ?
	LinNumberOfImagePages	DB ?
	LinRedMaskSize		DB ?
	LinRedFieldPosition	DB ?
	LinGreenMaskSize	DB ?
	LinGreenFieldPosition	DB ?
	LinBlueMaskSize		DB ?
	LinBlueFieldPosition	DB ?
	LinRsvdMaskSize		DB ?
	LinRsvdFieldPosition	DB ?
	MaxPixelClock		DD ?
	Reserved3		DB 189d dup (?)
ModeInfoBlock ENDS
