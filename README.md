# **NEWAX 0.10**  
**Nvidia kEpler/maxWell/pAscal fiX** — Advanced VESA VBE TSR for DOS

## **Overview**

NEWAX is a DOS TSR (Terminate and Stay Resident) that restores **fully functional VESA VBE support** on Nvidia GPUs from the **Kepler, Maxwell and Pascal** generations, where the VBIOS provides incomplete or broken implementations of key VESA functions.

Starting with version **0.10**, NEWAX is no longer a simple patch:  
it is a **complete re‑implementation** of the VESA functions responsible for:

- **4F06h — Logical Scanline Length**  
- **4F07h — Display Start Address / Panning**

NEWAX programs the VGA and Nvidia extended CRTC registers directly, bypassing the VBIOS entirely and restoring correct VESA behavior for DOS games, demos and applications.

---

## **Official Vogons Thread**

Development, discussion, technical details and community testing happen here:

👉 **[https://www.vogons.org/viewtopic.php?t=57420](https://www.vogons.org/viewtopic.php?t=57420)**

If you own an Nvidia GPU, **your test results are extremely valuable**.

---

## **Call for Beta Testers**

NEWAX relies on undocumented Nvidia hardware behavior.  
Although it has been tested on several GPUs, **we need as many beta testers as possible** to map compatibility across:

- different Nvidia architectures  
- OEM variants  
- mobile GPUs  
- secondary GPUs  
- systems with unusual PCI BIOS behavior  

If you own any Nvidia card from **GeForce 600 series to Pascal**, your feedback is crucial.  
Please report your results in the Vogons thread.

---

## **Background**

Modern Nvidia VBIOS versions often implement VESA functions incorrectly:

- **4F07h** is frequently a stub (`MOV AX,014Fh / RET`)
- **4F06h** is missing or broken
- BL=80h retrace logic is inverted
- page count is wrong
- VRAM boundary checks are incorrect

NEWAX replaces these functions with **fully working implementations**, based on reverse‑engineered Nvidia CRTC registers.

---

## **Major Changes in NEWAX 0.10**

### 🔧 **Complete rewrite of VESA 4F06h**
NEWAX now implements 4F06h entirely in software:

- pixel‑based and byte‑based scanline modes  
- planar, packed, and direct‑color support  
- correct pitch calculation using **CRTC 13h + Nvidia CRTC 3Bh**  
- VRAM‑safe validation  
- extremely large horizontal resolutions  
- correct GET behavior for all subfunctions  

### 🔧 **Complete rewrite of VESA 4F07h**
The new handler:

- computes the full **30‑bit** start address  
- uses Nvidia extended registers (34h/35h)  
- supports smooth panning in all color depths  
- fixes inverted retrace logic  
- works reliably on all Kepler/Maxwell/Pascal GPUs  

### 🧠 **Reverse‑engineered Nvidia CRTC architecture**

#### **Start Address (30‑bit)**
- Bits 0–7 → CRTC 0Dh  
- Bits 8–15 → CRTC 0Ch  
- Bits 16–23 → CRTC 35h  
- Bits 24–29 → CRTC 34h  

#### **Offset Register (16‑bit)**
- Bits 0–7 → CRTC 13h  
- Bits 8–15 → **CRTC 3Bh (new discovery)**  

#### **Unlock**
- CRTC 3Fh = 57h  

These discoveries enable:

- correct panning  
- correct pitch  
- virtual resolutions far beyond VESA limits  

---

## **Additional Fixes**

- **4F05h** — fixes VRAM boundary checks for >4MB  
- **4F01h** — correct page count for all memory models  
- **4F02h** — tracks memory model and scanline size  
- **VBE version override** — toggle VESA 2.0 / 3.0  
- **One‑page mode** — forces NumberOfImagePages = 0  
- **Forced VRAM size** — override VBE TotalMemory  

---

## **Usage**

```
NEWAX.COM              Install TSR
NEWAX.COM /U           Uninstall from memory
NEWAX.COM /F           Force installation (bypass Nvidia detection)
NEWAX.COM /2           Toggle VESA 2.0 / 3.0 reporting
NEWAX.COM /P           Toggle VBE/PMI support
NEWAX.COM /1           One‑page mode
NEWAX.COM /M:<value>   Force VESA memory size (in KB)
NEWAX.COM /S           Show current status
```

### **/F Flag — IMPORTANT**
`/F` **bypasses Nvidia GPU detection entirely**.

By default, NEWAX installs **only** when a primary Nvidia GPU is detected.  
With `/F`, NEWAX installs even when:

- no Nvidia GPU is present  
- the GPU is secondary  
- PCI BIOS is missing or broken  
- the system is an emulator  

Use `/F` for testing or when detection fails.

---

## **Compatibility**

| GPU | Notes |
|---|---|
| GT210 | |
| GT550Ti | 
| GT740 | |
| GT1030 | Primary development target |
| GTX1050 | |

**More testing needed — please report your results on Vogons.**

---

## **Building**

```
ASMC -bin NEWAX.ASM
```

Requires `CONST.INC` and `STRUCT.INC`.

---

## **Technical Notes**

- NEWAX uses INT 10h AX=4F17h BX='MP' for self‑identification  
- All extended CRTC writes use the unlock sequence  
- All VESA functions validated against VRAM  
- All calculations use 32‑bit arithmetic  

---

## **Acknowledgements**

Special thanks to **Falcosoft** for discovering the original Nvidia VESA bug  
and for extensive real‑hardware testing.

Thanks to the Vogons community for continuous feedback and testing.

---

## **License**

MIT License — © 2026 Marco Pistella

---
