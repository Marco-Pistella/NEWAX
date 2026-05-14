# NEWAX
**Nvidia kEpler/maxWell/pAscal fiX** - VESA VBE TSR for DOS

## Overview

NEWAX is a DOS TSR (Terminate and Stay Resident) that fixes broken or missing VESA VBE functions on Nvidia GPU cards from the Kepler generation onward (GeForce 600 series and later), where the VBIOS no longer provides a working implementation of INT 10h function 4F07h (Set/Get Display Start Address).

NEWAX replaces the broken VBIOS implementation with a direct CRTC register approach, restoring correct VESA panning and virtual screen functionality for DOS applications and games such as Quake and Duke Nukem 3D.

## Background

Starting from the Kepler architecture, Nvidia VBIOS provides a stub implementation of INT 10h 4F07h that returns immediately without performing any operation (MOV AX,014Fh / RET). Additionally, the BL=80h variant (set start address during vertical retrace) has inverted retrace logic in affected VBIOS versions, causing display flickering.

NEWAX intercepts INT 10h and replaces 4F07h with a direct implementation using Nvidia extended CRTC registers (index 34h high start address, 35h low start address, 3Fh unlock), which are present and functional across the entire Nvidia GPU family.

## Additional Fixes

Beyond 4F07h, NEWAX also corrects several other VBIOS bugs present across a wider range of Nvidia cards:

- **4F05h** (Set/Get Memory Window): fixes incorrect bank boundary check on cards with VRAM larger than 4MB, preventing display corruption above the 4MB boundary
- **4F06h** (Set/Get Logical Scan Line Length): fixes a divide overflow (INT0) occurring on cards reporting 256MB or more of VRAM when the scan line width is narrow; recalculates the maximum number of scan lines using 32-bit arithmetic
- **4F01h** (Return VBE Mode Information): recalculates NumberOfImagePages, LinNumberOfImagePages and BnkNumberOfImagePages correctly for all memory models including PLANAR, using BytesPerScanLine as the authoritative value
- **4F02h** (Set VBE Mode): tracks the active mode memory model and bytes per scan line for use by the 4F07h handler
- **VBE version reporting**: optional downgrade from VESA 3.0 to 2.0 for compatibility with applications that misbehave under 3.0

## Discovery

The Nvidia VBIOS unlock key **2469FDB9h**, required to access the extended CRTC registers on G7x (GeForce 7) and later architectures, was first documented publicly by the author of this project. The key is present in Nvidia VBIOS from the GeForce 7 series through at least the Ampere generation (RTX A4000 confirmed). On earlier cards (RIVA TNT, GeForce 2/4/6) the extended CRTC registers are directly accessible without an unlock sequence.

## Usage

```
NEWAX.COM              Install TSR
NEWAX.COM /U           Uninstall from memory
NEWAX.COM /F           Force installation (use on cards where 4F07h is functional)
NEWAX.COM /2           Toggle VESA 2.0 / 3.0 reporting
NEWAX.COM /P           Toggle VBE/PMI support
NEWAX.COM /1           Toggle one page mode (sets NumberOfImagePages=0)
NEWAX.COM /S           Show current status flags
```

### /F Flag

By default, NEWAX refuses to install on cards where 4F07h is detected as functional, since those cards do not need the start address replacement. The /F flag bypasses this check, allowing installation on cards where 4F07h works but other fixes (4F05h, 4F06h, 4F01h) are still beneficial.

Use /F with caution on non-Nvidia hardware.

## Compatibility

NEWAX is confirmed working on the following hardware:

| Card | Notes |
|---|---|
| GT210 | /F required |
| GT550Ti | Primary development target |
| GT740 | |
| GTX960 | |
| GTX970 | |
| GTX650 | /F required |
| RTX A4000 (Ampere) | 4F06h absent; /F required |

Community testing ongoing. Cards with functional 4F07h require /F.

## Building

NEWAX is written in x86 real-mode assembly and assembles with ASMC or TASM compatible assembler:

```
ASMC NEWAX.ASM
```

Requires `CONST.INC` and `STRUCT.INC` in the same directory.

## Technical Notes

The MPID identification mechanism (INT 10h AX=4F17h, BX='MP') allows runtime detection of a loaded NEWAX instance and safe inter-instance communication for the toggle commands.

## Acknowledgements

Special thanks to **Falcosoft** for first documenting the Nvidia VESA VBIOS bug
in his [Vogons thread](https://www.vogons.org/viewtopic.php?t=57420), for his
extensive real hardware testing, and for his insightful technical feedback which
directly influenced several design decisions in NEWAX. Thanks also to all the
beta testers on the [Vogons](https://www.vogons.org) retro-computing forum.

## License

MIT License - Copyright (c) 2026 Marco Pistella

See [LICENSE](LICENSE) for full text.

