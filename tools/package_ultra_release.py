#!/usr/bin/env python3
"""
Prepares the 5 GB+ Ultra-HD Windows Desktop release (v0.3-ultra-hd) for GitHub Releases:
- Splits the large 64-bit .pck file into <= 1.8 GB parts (under GitHub's 2 GiB per-asset limit)
- Creates a 1-click Windows native batch assembler & launcher (SPILL_SAMLE_OG_START.bat)
  that joins the .pck parts with built-in Windows `copy /b` (no 7-Zip/WinRAR needed!)
- Writes SHA256SUMS.txt and LESMEG_INSTALLASJON.txt.
"""
import hashlib
import os
from pathlib import Path

BUILD_DIR = Path("/home/antigravity/sabeltann_remake/builds/v0.3-ultra-hd")
PARTS_DIR = BUILD_DIR / "release_parts"
EXE_NAME = "KapteinSabeltannHD_v0.3-ultra-hd.exe"
PCK_NAME = "KapteinSabeltannHD_v0.3-ultra-hd.pck"
CHUNK_BYTES = 1_800_000_000  # 1.80 GB (< 2 GiB GitHub release asset cap)


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while True:
            buf = f.read(8 * 1024 * 1024)
            if not buf:
                break
            h.update(buf)
    return h.hexdigest()


def main():
    exe_p = BUILD_DIR / EXE_NAME
    pck_p = BUILD_DIR / PCK_NAME
    assert exe_p.exists(), f"Missing {exe_p}"
    assert pck_p.exists(), f"Missing {pck_p}"

    exe_sz = exe_p.stat().st_size
    pck_sz = pck_p.stat().st_size
    tot_sz = exe_sz + pck_sz
    print(f"Build verified: {EXE_NAME} = {exe_sz/1e6:.2f} MB, {PCK_NAME} = {pck_sz/1e9:.3f} GB, TOTAL = {tot_sz/1e9:.3f} GB ({tot_sz/1073741824:.3f} GiB)")

    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    for old in PARTS_DIR.glob("*"):
        old.unlink()

    parts = []
    with open(pck_p, "rb") as src:
        idx = 1
        while True:
            part_p = PARTS_DIR / f"{PCK_NAME}.part{idx}"
            written = 0
            with open(part_p, "wb") as dst:
                while written < CHUNK_BYTES:
                    to_read = min(8 * 1024 * 1024, CHUNK_BYTES - written)
                    chunk = src.read(to_read)
                    if not chunk:
                        break
                    dst.write(chunk)
                    written += len(chunk)
            if written == 0:
                part_p.unlink(missing_ok=True)
                break
            parts.append(part_p)
            print(f"  Created {part_p.name} ({written/1e9:.3f} GB)")
            idx += 1

    # Generate 1-click native Windows .bat joiner + launcher!
    join_expr = "+".join(f'"{p.name}"' for p in parts)
    bat_lines = [
        "@echo off",
        "chcp 65001 >nul",
        "cd /d \"%~dp0\"",
        f'if exist "{PCK_NAME}" goto :launch',
        "echo =====================================================================",
        "echo  Kaptein Sabeltann HD Remake (v0.3 Ultra-HD 4K) - Klargjor spillfil",
        "echo =====================================================================",
        f"echo Setter sammen {len(parts)} datadeler til {PCK_NAME} (tar 10-30 sekunder)...",
    ]
    for p in parts:
        bat_lines += [
            f'if not exist "{p.name}" (',
            f'  echo FEIL: Mangler filen {p.name} i samme mappe!',
            "  pause",
            "  exit /b 1",
            ")",
        ]
    bat_lines += [
        f'copy /b {join_expr} "{PCK_NAME}" >nul',
        "if errorlevel 1 (",
        "  echo FEIL: Kunne ikke sette sammen datapakkene. Sjekk ledig diskplass.",
        "  pause",
        "  exit /b 1",
        ")",
        f"echo Ferdig! {PCK_NAME} er klar. (Du kan naa slette .part*-filene hvis du vil spare plass.)",
        ":launch",
        f'start "" "{EXE_NAME}"',
    ]
    bat_p = PARTS_DIR / "SPILL_SAMLE_OG_START.bat"
    bat_p.write_text("\r\n".join(bat_lines) + "\r\n", encoding="utf-8")

    # Write Norwegian readme
    readme = f"""Kaptein Sabeltann og Grusomme Gabriels forbannelse — Ultra-HD 4K Remake (v0.3)
================================================================================

Total spillstørrelse: {tot_sz / 1e9:.2f} GB ({tot_sz / 1073741824:.2f} GiB)
- {EXE_NAME} ({exe_sz / 1e6:.1f} MB)
- {PCK_NAME} ({pck_sz / 1e9:.2f} GB — delt i {len(parts)} deler på grunn av GitHubs 2 GB filgrense)

SLIK SPILLER DU PÅ WINDOWS:
1. Last ned ALLE filene fra releasen til samme mappe på PC-en:
   - {EXE_NAME}
   - SPILL_SAMLE_OG_START.bat
""" + "\n".join(f"   - {p.name}" for p in parts) + f"""
2. Dobbeltklikk på SPILL_SAMLE_OG_START.bat (ingen 7-Zip eller ekstra programmer kreves!).
   Skriptet setter automatisk sammen {PCK_NAME} og starter spillet!
3. Neste gang kan du bare dobbeltklikke direkte på {EXE_NAME}.
"""
    (PARTS_DIR / "LESMEG_INSTALLASJON.txt").write_text(readme, encoding="utf-8")

    # Compute SHA256SUMS
    sums = [f"{sha256_file(exe_p)}  {EXE_NAME}", f"{sha256_file(pck_p)}  {PCK_NAME}"]
    for p in parts:
        sums.append(f"{sha256_file(p)}  {p.name}")
    (PARTS_DIR / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    print(f"[OK] Packaged {len(parts)} parts + SPILL_SAMLE_OG_START.bat + SHA256SUMS.txt in {PARTS_DIR}")


if __name__ == "__main__":
    main()
