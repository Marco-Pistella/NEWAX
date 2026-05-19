# NEWAX 0.10
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

👉 **[https://www.vogons.org/viewtopic.php?t=57420](https://www.vogons.org/viewtopic.php?t=57420)**

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

If you own any Nvidia card from the **GeForce 600 series through Pascal (GTX 10xx)**, please report your results in the Vogons thread.

---

## Background

Modern Nvidia VBIOS versions implement VESA functions incorrectly or not at all:

- **4F07h** is frequently a stub (`MOV AX,014Fh / RET`)
- **4F06h** is missing or broken on many cards
- BL=80h retrace logic is inverted, causing display flickering
- Page count is wrong
- VRAM boundary checks trigger INT 0 (divide by zero) on cards with ≥256MB VRAM

NEWAX replaces these broken functions with **fully working implementations** based on reverse-engineered Nvidia CRTC registers.

---

## Discovery

The Nvidia VBIOS unlock key **2469FDB9h**, required to access the extended CRTC registers on G7x (GeForce 7) and later architectures, was **first documented publicly by the author of this project**. The key is present in Nvidia VBIOS from the GeForce 7 series through at least the Ampere generation. On earlier cards (RIVA TNT, GeForce 2/4/6) the extended CRTC registers are directly accessible without an unlock sequence.

---

## Major Changes in NEWAX 0.10

### Complete rewrite of VESA 4F06h

NEWAX now implements 4F06h entirely in software, with no BIOS delegation:

- All four sub-functions: set by pixels, get, set by bytes, get maximum
- Planar, packed, and direct-color (16/32bpp) support
- Correct pitch calculation using **CRTC 13h + Nvidia CRTC 3Bh**
- VRAM-safe validation: scanline rejected if insufficient memory for the current vertical resolution
- Minimum scanline enforced: cannot be set below the mode's horizontal resolution
- Support for extremely large horizontal resolutions (up to 524280px at 8bpp)

### Complete rewrite of VESA 4F07h

The new handler:

- Computes the full **30-bit** start address
- Uses Nvidia extended registers (34h/35h) for bits 16–29
- Supports smooth panning in all color depths
- Fixes inverted retrace logic (BL=80h)
- Works reliably on all Kepler/Maxwell/Pascal GPUs

### Reverse-engineered Nvidia CRTC architecture

#### Start Address (30-bit)
| Bits | Register |
|------|----------|
| 0–7  | CRTC 0Dh |
| 8–15 | CRTC 0Ch |
| 16–23 | CRTC 35h |
| 24–29 | CRTC 34h |

#### Offset Register (16-bit)
| Bits | Register |
|------|----------|
| 0–7  | CRTC 13h |
| 8–15 | **CRTC 3Bh** *(first public documentation)* |

#### Unlock sequence
- CRTC 3Fh ← 57h

These registers are **invariant from NV5 (RIVA TNT) through Ampere**. On NV5/NV11 no unlock is required.

---

## Additional Fixes

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
NEWAX.COM /M:<value>         Force VESA memory size (in KB, 256–262144)
```

Arguments `/2`, `/P`, `/1` and `/M` can be combined with each other and used
both at install time and on an already-installed TSR.

### /F Flag

By default, NEWAX installs **only** when a primary Nvidia GPU is detected and
VESA functions are confirmed broken. Use `/F` to bypass this check when:

- the GPU is Nvidia but detection fails (unusual PCI BIOS, OEM variant)
- the GPU is not primary
- 4F07h works correctly but other fixes (4F05h, 4F06h, 4F01h) are still needed
- testing on a non-Nvidia system or emulator

### /M Flag

Overrides the VRAM size reported by the VBIOS (`VbeInfoBlock.TotalMemory`).
Useful when the BIOS reports an incorrect value. Accepts values in KB from
256 to 262144 (256KB–256MB).

---

## Compatibility

Confirmed working on the following hardware (NEWAX 0.10):

| Card | Notes |
|------|-------|
| GT210 | |
| GT550Ti | |
| GT740 | |
| GT1030 | Primary development target |
| GTX1050 | |

Results from NEWAX 0.9 (pending re-test on 0.10):

| Card | Notes |
|------|-------|
| GT650 | /F required |
| GTX960 | |
| GTX970 | |
| RTX A4000 (Ampere) | 4F06h absent from VBIOS; /F required |
| GF6200 | Divide-by-zero in 4F06h confirmed; /F required |

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
- All VESA functions are validated against actual VRAM size
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
