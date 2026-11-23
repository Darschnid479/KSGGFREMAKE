#!/usr/bin/env python3
"""
Extracts all 16 original 24-bit RGB heightmaps + heightmap_info.ls mapping metadata
from Macromedia Director .cct cast files -> PNG + JSON in godot_project/data/heightmaps/.

Exact 1:1 formula from original ParentScript 187 - heightMap.ls:
  pixel_int = (R << 16) | (G << 8) | B
  sw_height = baseHeight + pixel_int * unitsPerColor
  godot_y   = sw_height * 0.1
"""
import json
import re
import shutil
import struct
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image

PROJECTORRAYS = "/home/antigravity/ProjectorRays/projectorrays"
CAST_DIR = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets/cast")
DECOMP_CASTS = Path("/home/antigravity/decompiled_casts")
OUT_DIR = Path("/home/antigravity/sabeltann_remake/godot_project/data/heightmaps")
TMP_DIR = Path("/tmp/extract_hm_work")


def decode_packbits_stream(data: bytes, expected_len: int) -> bytes:
    out = bytearray()
    i = 0
    n = len(data)
    while i < n and len(out) < expected_len:
        b = data[i]
        i += 1
        if b <= 127:
            cnt = b + 1
            out.extend(data[i : i + cnt])
            i += cnt
        elif b > 128:
            cnt = 257 - b
            if i < n:
                out.extend(bytes([data[i]]) * cnt)
                i += 1
        # b == 128 is no-op
    if len(out) < expected_len:
        out.extend(b"\x00" * (expected_len - len(out)))
    return bytes(out[:expected_len])


def decode_director_bitd(cast_bin: bytes, bitd: bytes) -> Image.Image | None:
    if len(cast_bin) < 28:
        return None
    spec = cast_bin[-28:]
    pitch_raw, top, left, bottom, right = struct.unpack_from(">5H", spec, 0)
    w = right - left
    h = bottom - top
    if w <= 0 or h <= 0 or w > 8192 or h > 8192:
        return None
    # Bit depth sits at offset 23 in 28-byte specificData (0x20=32, 0x18=24, 0x10=16, 0x08=8)
    bit_depth = spec[23]
    if bit_depth not in (8, 16, 24, 32):
        # Fallback infer from pitch
        pitch = pitch_raw & 0x7FFF
        if pitch == w * 4:
            bit_depth = 32
        elif pitch == w * 3:
            bit_depth = 24
        elif pitch == w * 2:
            bit_depth = 16
        else:
            bit_depth = 8

    bpp = bit_depth // 8
    raw_size = w * h * bpp
    if len(bitd) == raw_size:
        decoded = bitd
    else:
        decoded = decode_packbits_stream(bitd, raw_size)

    arr = np.frombuffer(decoded, dtype=np.uint8)
    if bit_depth == 32:
        # Director 32-bit BITD stores each scanline planar: [A*w, R*w, G*w, B*w]
        planes = arr.reshape((h, 4, w))
        rgb = np.stack([planes[:, 1, :], planes[:, 2, :], planes[:, 3, :]], axis=2)
        return Image.fromarray(rgb, mode="RGB")
    elif bit_depth == 24:
        planes = arr.reshape((h, 3, w))
        rgb = np.stack([planes[:, 0, :], planes[:, 1, :], planes[:, 2, :]], axis=2)
        return Image.fromarray(rgb, mode="RGB")
    elif bit_depth == 8:
        g = arr.reshape((h, w))
        return Image.fromarray(np.stack([g, g, g], axis=2), mode="RGB")
    return None


def parse_heightmap_info(ls_path: Path) -> dict | None:
    txt = ls_path.read_text(encoding="latin1", errors="replace")
    bh = re.search(r"#baseHeight:\s*([\-0-9.eE]+)", txt)
    upc = re.search(r"#unitsPerColor:\s*([\-0-9.eE]+)", txt)
    tl = re.search(r"#topLeft:\s*vector\(\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)", txt)
    br = re.search(r"#bottomRight:\s*vector\(\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)", txt)
    if not (bh and upc and tl and br):
        return None
    return {
        "base_height": float(bh.group(1)),
        "units_per_color": float(upc.group(1)),
        "top_left": [float(tl.group(1)), float(tl.group(2))],
        "bottom_right": [float(br.group(1)), float(br.group(2))],
    }


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(TMP_DIR, ignore_errors=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    count = 0
    for ls_file in sorted(DECOMP_CASTS.glob("*/**/MovieScript*heightmap_info.ls")):
        level_id = ls_file.parts[len(DECOMP_CASTS.parts)]
        info = parse_heightmap_info(ls_file)
        if not info:
            continue
        cct = CAST_DIR / f"{level_id}.cct"
        if not cct.exists():
            continue

        subprocess.run(
            [PROJECTORRAYS, "decompile", str(cct), "-o", str(TMP_DIR), "--dump-chunks", "--dump-json"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        cd = TMP_DIR / level_id / "chunks"
        if not cd.exists():
            continue

        hm_cid = None
        for f in cd.glob("CASt-*.json"):
            if '"name": "heightmap"' in f.read_text("latin1", "replace"):
                hm_cid = int(f.stem.split("-")[1])
                break
        if hm_cid is None:
            continue

        bitd_sid = None
        for kf in cd.glob("KEY_*.json"):
            m = re.search(
                r'"sectionID":\s*(\d+),\s*"castID":\s*' + str(hm_cid) + r',\s*"fourCC":\s*"BITD"',
                kf.read_text("latin1", "replace"),
            )
            if m:
                bitd_sid = int(m.group(1))
                break
        if bitd_sid is None:
            continue

        cast_bin = (cd / f"CASt-{hm_cid}.bin").read_bytes()
        bitd_bin = (cd / f"BITD-{bitd_sid}.bin").read_bytes()
        img = decode_director_bitd(cast_bin, bitd_bin)
        if img is None:
            print(f"[FAIL] {level_id}: could not decode BITD")
            continue

        # Save lossless 512x512 NEAREST-sampled heightmap (NEVER bilinear on RGB-packed 24-bit ints!)
        # Wait: keep 512x512 by subsampling exact pixels so 24-bit RGB integer bits are NEVER corrupted!
        w0, h0 = img.size
        step = max(1, w0 // 512)
        arr = np.asarray(img, dtype=np.uint8)
        sub = arr[::step, ::step, :]
        out_img = Image.fromarray(sub, mode="RGB")
        out_png = OUT_DIR / f"{level_id}.png"
        out_img.save(out_png, optimize=True)

        # Compute diagnostic height range
        rgb_int = (sub[:, :, 0].astype(np.int64) << 16) | (sub[:, :, 1].astype(np.int64) << 8) | sub[:, :, 2].astype(np.int64)
        valid = rgb_int[rgb_int > 0]
        if valid.size > 0:
            h_min = (info["base_height"] + float(valid.min()) * info["units_per_color"]) * 0.1
            h_max = (info["base_height"] + float(valid.max()) * info["units_per_color"]) * 0.1
        else:
            h_min = h_max = 0.0

        info["width"] = int(sub.shape[1])
        info["height"] = int(sub.shape[0])
        (OUT_DIR / f"{level_id}.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
        print(f"[OK] {level_id:25s} {w0}x{h0} -> {sub.shape[1]}x{sub.shape[0]}  godot_y=[{h_min:.2f}m .. {h_max:.2f}m]")
        count += 1

    shutil.rmtree(TMP_DIR, ignore_errors=True)
    print(f"Extracted {count} original level heightmaps!")


if __name__ == "__main__":
    main()
