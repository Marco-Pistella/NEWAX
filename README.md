# NEWAX 0.11

**Nvidia kEpler/maxWell/pAscal fiX** — Advanced VESA VBE TSR for DOS

## Overview

NEWAX is a DOS TSR (Terminate and Stay Resident) that restores **fully functional VESA VBE support** on Nvidia GPUs from the **Kepler, Maxwell and Pascal** generations, where the VBIOS provides incomplete or broken implementations of key VESA functions.

Starting with version **0.10**, NEWAX is no longer a simple patch:
it is a **complete re-implementation** of the VESA functions responsible for:

- **4F06h — Logical Scanline Length**
- **4F07h — Display Start Address / Panning**

NEWAX programs the VGA and Nvidia extended CRTC registers directly, bypassing the VBIOS entirely and restoring correct VESA behavior for DOS games, demos and applications.

---

## Official Vogons Thread

Development, discussion, technical details and community testing:

👉 **<https://www.vogons.org/viewtopic.php?t=57420>**

If you own an Nvidia GPU, **your test results are extremely valuable**.

---

## Call for Beta Testers

NEWAX relies on undocumented Nvidia hardware behavior.
Although it has been tested on several GPUs, **more testers are needed** across:

- different Nvidia architectures (Kepler, Maxwell, Pascal)
- OEM and mobile variants
- secondary or non-primary GPUs
- systems with unusual PCI BIOS behavior
- emulators

If you own any Nvidia card from the **GeForce 600 series through Pascal (GTX 10xx)**,
please report your results in the Vogons thread.

---

## Background

Modern Nvidia VBIOS versions implement VESA functions incorrectly or not at all:

- **4F07h** is frequently a stub (`MOV AX,014Fh / RET`)
- **4F06h** is missing or broken on many cards
- BL=80h retrace logic is inverted, causing display flickering
- Page count is wrong
- VRAM boundary checks trigger INT 0 (divide by zero) on cards with ≥256MB VRAM

NEWAX replaces these broken functions with **fully working implementations** based on
reverse-engineered Nvidia CRTC registers.

---

## Discovery

The Nvidia VBIOS unlock key **2469FDB9h**, required to access the extended CRTC
registers on G7x (GeForce 7) and later architectures, was **first documented publicly
by the author of this project**. The key is present in Nvidia VBIOS from the GeForce 7
series through at least the Ampere generation. On earlier cards (RIVA TNT, GeForce 2/4/6)
the extended CRTC registers are directly accessible without an unlock sequence.

---

## Changes in NEWAX 0.11

### New: hardware compatibility detection (`Detect_Supported_Nvidia`)

NEWAX 0.11 introduces a new routine that distinguishes supported from unsupported Nvidia
cards **before installation**, using a direct hardware-level test.

The detection exploits a structural difference between the two families:

- **Supported cards** (Kepler and later) protect their extended CRTC registers behind a
  lock. After locking CRTC 3Fh, a write to the extended offset register (CRTC 3Bh) has
  no effect — the register is hardware-protected until unlocked.
- **Unsupported cards** (pre-Kepler without lock support) have no such protection:
  CRTC 3Bh is freely readable and writable at all times.

The routine locks CRTC 3Fh, then attempts a non-destructive write (`XOR FFh`) to
CRTC 3Bh and reads back the result:

- Readback **unchanged** → register is protected → card **supported** → installation proceeds
- Readback **changed** → register is writable → card **not supported** → original values
  restored, installation refused

In `/S` diagnostic mode the test is always run and its result displayed, even on
unsupported cards, together with the full PCI information.

### New: `/V` flag — force VSync off

A new `/V` command-line argument toggles forced VSync-off mode. When active, the
4F07h BL=02h handler (set start address during vertical retrace) skips the retrace
wait loop and sets the display start address immediately. Useful on systems where the
retrace wait causes timing problems.

The VSync status is reported in `/S` output:
- `Vsync status: Forced to off`
- `Vsync status: Default`

### Bugfix: stack imbalance in VGA mode set handler

In the `AH=00h` (Set VGA Mode) INT 10h handler, the `POP DS` instruction was
misplaced before the conditional branch:

```asm
; 0.10 — BUGGY: pop ds executed before branch, stack unbalanced on popa
push  BIOS_INTERRUPT_SEGMENT
pop   ds
cmp   ds: byte ptr [BIOS_OFFSET_VGA_VIDEO_MODE],VGA_MAX_VIDEO_MODE
pop   ds
ja    vesa_mode_on
and   cs: byte ptr [status_flag_0_tsr],NOT NEWAX_FLAG_VESA_MODE_TSR
vesa_mode_on:
call  Reset_Nvidia_Start_Address
popa                    ; ← stack unbalanced: ds was already popped
iret
```

```asm
; 0.11 — CORRECT: pop ds after branch, balanced stack on popa
push  BIOS_INTERRUPT_SEGMENT
pop   ds
cmp   ds: byte ptr [BIOS_OFFSET_VGA_VIDEO_MODE],VGA_MAX_VIDEO_MODE
ja    vesa_mode_on
and   cs: byte ptr [status_flag_0_tsr],NOT NEWAX_FLAG_VESA_MODE_TSR
vesa_mode_on:
call  Reset_Nvidia_Start_Address
pop   ds                ; ← correct position
popa
iret
```

Effect of the bug: on every VGA mode set the `PUSHA` / `POPA` pair was unbalanced,
corrupting the saved register state restored on `POPA` and leaving the stack pointer
off by two bytes after `IRET`.

### Improved diagnostic messages

The `/S` status output labels for the original VESA function check have been made
more descriptive:

- `Original 4F06h VESA function` → **`Original Logical Scanline Length (4F06h)`**
- `Original 4F07h VESA function` → **`Original Display Start Address/Panning (4F07h)`**

### New: VRAM clear on mode set (4F02h)

NEWAX now zeroes the entire VRAM when a VESA mode is opened without the
no-clear flag (BX bit 15 = 0), replicating the behavior that a correct VBIOS
should provide. Both banked and linear framebuffer modes are supported,
including planar modes.

The clear sequence:

1. If the no-clear flag (BX bit 15) is set, the clear is skipped entirely.
2. For linear modes: the mode is temporarily reopened in banked form to allow
   bank-switched access, the clear is performed, then the mode is reopened in
   linear form.
3. The number of 64KB banks to clear equals `TotalMemory` from `VbeInfoBlock`;
   for planar modes this is divided by 4 (one bank covers 4 planes).
4. Each bank is selected via INT 10h 4F05h, then zeroed with `REP STOSD`.
5. Bank 0 is restored on exit.

### Code quality: symbolic constants in 4F05h handler

The literal values `3h` and `2h` used in the 4F05h planar alignment check have been
replaced with named constants `NEWAX_PLANAR_MODE` and `VGA_PLANER_PLANE_SHIFT`,
consistent with the rest of the codebase.

---

## Reverse-engineered Nvidia CRTC Architecture

### G80 and later (GeForce 8 series through Ampere)

#### Lock / Unlock

| Operation | Register | Value |
| --------- | -------- | ----- |
| Unlock    | CRTC 3Fh | 57h   |
| Lock      | CRTC 3Fh | 08h   |

Extended CRTC registers for offset and start address are **read-only until unlocked**.
The unlock key **2469FDB9h** is first documented publicly by the author of this project.

#### Start Address

| Bits  | Register       |
| ----- | -------------- |
| 0–7   | CRTC 0Dh       |
| 8–15  | CRTC 0Ch       |
| 16–23 | CRTC 35h       |
| 24–29 | CRTC 34h [5:0] |

#### Offset Register

| Bits  | Register                                    |
| ----- | ------------------------------------------- |
| 0–7   | CRTC 13h                                    |
| 8–15  | **CRTC 3Bh** *(first public documentation)* |

---

### Pre-G80 (RIVA TNT through GeForce 6 series)

No lock/unlock sequence required. Extended registers are always accessible.

#### Start Address

| Bits  | Register          |
| ----- | ----------------- |
| 0–7   | CRTC 0Dh          |
| 8–15  | CRTC 0Ch          |
| 16–20 | CRTC 19h [4:0]    |
| 21–24 | CRTC 2Dh [3:0]    |

#### Offset Register

| Bits  | Register       |
| ----- | -------------- |
| 0–7   | CRTC 13h       |
| 8–10  | CRTC 19h [7:5] |

---

## VESA Function Implementations

### 4F06h — Logical Scanline Length

Complete software implementation, no BIOS delegation:

- All four sub-functions: set by pixels, get, set by bytes, get maximum
- Planar, packed, and direct-color (16/32bpp) support
- Correct pitch calculation using **CRTC 13h + Nvidia CRTC 3Bh**
- VRAM-safe validation: scanline rejected if insufficient memory for the current
  vertical resolution
- Minimum scanline enforced: cannot be set below the mode's horizontal resolution
- Support for extremely large horizontal resolutions (up to 524280px at 8bpp)

### 4F07h — Display Start Address / Panning

- Computes the full **30-bit** start address
- Uses Nvidia extended registers (34h/35h) for bits 16–29
- Supports smooth panning in all color depths
- Fixes inverted retrace logic (BL=80h)
- Optional forced VSync-off via `/V` flag
- Works reliably on all Kepler/Maxwell/Pascal GPUs

### Additional Fixes

- **4F05h** — fixes VRAM boundary checks for cards with >4MB VRAM
- **4F01h** — correct page count for all memory models (planar ×4 correction)
- **4F02h** — tracks memory model, scanline size and resolution for use by 4F06h/4F07h
- **VBE version override** — toggle VESA 2.0 / 3.0 reporting (`/2`)
- **One-page mode** — forces NumberOfImagePages = 0 (`/1`)
- **Forced VRAM size** — override VBE TotalMemory reporting (`/M`)

---

## Usage

```
NEWAX.COM                    Install TSR
NEWAX.COM /U                 Uninstall from memory
NEWAX.COM /S                 Show current status
NEWAX.COM /F                 Force installation (bypass Nvidia detection)
NEWAX.COM /2                 Toggle VESA 2.0 / 3.0 reporting
NEWAX.COM /P                 Toggle VBE/PMI support
NEWAX.COM /1                 Toggle one-page mode
NEWAX.COM /V                 Toggle force VSync off
NEWAX.COM /M:<value>         Force VESA memory size (in KB, 256–262144)
```

Arguments `/2`, `/P`, `/1`, `/V` and `/M` can be combined with each other and used
both at install time and on an already-installed TSR.

### /F Flag

By default, NEWAX installs **only** when a primary Nvidia GPU is detected,
the hardware compatibility check (`Detect_Supported_Nvidia`) passes, and VESA
functions are confirmed broken. Use `/F` to bypass this check when:

- the GPU is Nvidia but detection fails (unusual PCI BIOS, OEM variant)
- the GPU is not primary
- 4F07h works correctly but other fixes (4F05h, 4F06h, 4F01h) are still needed
- testing on a non-Nvidia system or emulator

### /V Flag

Skips the vertical retrace wait in the 4F07h BL=02h handler. Useful on systems
where the retrace loop causes issues. Can be toggled on an already-installed TSR.

### /M Flag

Overrides the VRAM size reported by the VBIOS (`VbeInfoBlock.TotalMemory`).
Useful when the BIOS reports an incorrect value. Accepts values in KB from
256 to 262144 (256KB–256MB).

---

## Compatibility

Confirmed working on the following hardware (NEWAX 0.11):

| Card | PCI_ID | Rev | SUBSYS_ID | Notes | Submitter |
| ---- | ------ | --- | --------- | ----- | --------- |
| GeForce GTX 1050 | 10DE:1C81 | A1 | 1458:3766 | 4F07h broken in VBIOS | Marco Pistella |
| GeForce GT 1030  | 10DE:1D01 | A1 | 1462:8C98 | 4F07h broken in VBIOS | Marco Pistella |
| GeForce GTX 970  | 10DE:13C2 | A1 | 1462:3161 | 4F07h broken in VBIOS | Falcosoft |
| GeForce GT 740   | 10DE:0FC8 | A1 | 10DE:0FC8 | 4F07h broken in VBIOS; /M:16384 recommended | Marco Pistella |
| GeForce GTX 550 Ti | 10DE:1244 | A1 | 0000:0000 | /M:16384 recommended | Marco Pistella |
| GeForce 210      | 10DE:0A65 | A2 | 1043:8490 | /M:16384 recommended | Marco Pistella |
| GeForce 210      | 10DE:0A65 | A2 | 1043:852D | /M:16384 recommended | Marco Pistella |
| GeForce 8400 GS  | 10DE:0422 | A1 | 1ACC:0851 | /M:16384 recommended | Marco Pistella |
| GeForce 7025     | 10DE:03D6 | A2 | 1043:83A4 | Integrated GPU; 4F06h and 4F07h not supported | Marco Pistella |

**More testing needed — please report your results in the Vogons thread.**

---

## Building

```
ASMC -bin NEWAX.ASM
```

Produces a flat binary. Rename the output to `NEWAX.COM`.
Requires `CONST.INC` and `STRUCT.INC` in the same directory.

---

## Technical Notes

- NEWAX identifies itself via INT 10h AX=4F17h BX='MP' (MPID mechanism)
- All extended CRTC writes use the unlock sequence (CRTC 3Fh ← 57h)
- Hardware compatibility verified at install time via non-destructive CRTC register test
- All VESA functions validated against actual VRAM size
- All calculations use 32-bit arithmetic to prevent overflow
- TSR resident size: ~1.3KB

---

## Acknowledgements

Special thanks to **Falcosoft** for first documenting the Nvidia VESA VBIOS bug,
for his [original Vogons thread](https://www.vogons.org/viewtopic.php?t=57420),
and for extensive real-hardware testing and technical feedback.

Thanks to the Vogons community for continuous feedback and testing.

---

## License

MIT License — © 2026 Marco Pistella
