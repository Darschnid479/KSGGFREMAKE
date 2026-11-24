#!/usr/bin/env python3
"""
Extracts all original 2007 2D bitmaps (ediM JPEG + ALFA alpha masks, and BITD uncompressed/RLE bitmaps)
with their exact Shockwave Director cast member names from decompiled .cst files.
Saves PNGs into work_refs/original_ui/<cast_name>/<member_name>.png and an index JSON.
"""
import io
import json
import os
import re
import struct
from pathlib import Path
from PIL import Image

CAST_ROOT = Path("/home/antigravity/decompiled_casts")
OUT_ROOT = Path("/home/antigravity/sabeltann_remake/work_refs/original_ui")

TARGET_CASTS = [
    "hud",
    "menu",
    "ingamemenu",
    "graal_boss_hud",
    "cave_boss_hud",
    "fatamorgana_boss_hud",
    "mk_boss_hud",
    "swimming_hud",
    "world_map",
    "loading",
    "logointro",
    "numbers",
    "bignumbers",
    "credits",
]


def safe_name(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9_\-\.]", "_", s.strip())
    return s or "unnamed"


def decode_rle_bytes(src: bytes, expected_len: int) -> bytes:
    """Standard PackBits RLE decoder used by Director BITD/ALFA chunks."""
    if len(src) == expected_len:
        return src
    out = bytearray()
    i = 0
    n = len(src)
    while i < n and len(out) < expected_len:
        hdr = src[i]
        i += 1
        if hdr <= 127:
            cnt = hdr + 1
            out.extend(src[i : i + cnt])
            i += cnt
        elif hdr >= 129:
            cnt = 257 - hdr
            if i < n:
                out.extend(bytes([src[i]]) * cnt)
                i += 1
    if len(out) < expected_len:
        out.extend(b"\x00" * (expected_len - len(out)))
    return bytes(out[:expected_len])


def decode_bitd(bitd: bytes, width: int, height: int, row_bytes: int, bit_depth: int):
    if width <= 0 or height <= 0 or row_bytes <= 0:
        return None
    if bit_depth == 32:
        # Director 32-bit BITD stores 4 planar channels (A, R, G, B) per scanline!
        expected = height * width * 4
        raw = decode_rle_bytes(bitd, expected)
        rgba = bytearray(width * height * 4)
        for y in range(height):
            line = raw[y * width * 4 : (y + 1) * width * 4]
            a_ch = line[0:width]
            r_ch = line[width : width * 2]
            g_ch = line[width * 2 : width * 3]
            b_ch = line[width * 3 : width * 4]
            base = y * width * 4
            for x in range(width):
                rgba[base + x * 4 + 0] = r_ch[x]
                rgba[base + x * 4 + 1] = g_ch[x]
                rgba[base + x * 4 + 2] = b_ch[x]
                rgba[base + x * 4 + 3] = a_ch[x]
        return Image.frombytes("RGBA", (width, height), bytes(rgba))
    elif bit_depth == 24:
        expected = height * width * 3
        raw = decode_rle_bytes(bitd, expected)
        rgb = bytearray(width * height * 3)
        for y in range(height):
            line = raw[y * width * 3 : (y + 1) * width * 3]
            r_ch = line[0:width]
            g_ch = line[width : width * 2]
            b_ch = line[width * 2 : width * 3]
            base = y * width * 3
            for x in range(width):
                rgb[base + x * 3 + 0] = r_ch[x]
                rgb[base + x * 3 + 1] = g_ch[x]
                rgb[base + x * 3 + 2] = b_ch[x]
        return Image.frombytes("RGB", (width, height), bytes(rgb))
    elif bit_depth == 8:
        expected = height * row_bytes
        raw = decode_rle_bytes(bitd, expected)
        img = Image.frombytes("L", (row_bytes, height), raw)
        return img.crop((0, 0, width, height))
    elif bit_depth == 16:
        expected = height * row_bytes
        raw = decode_rle_bytes(bitd, expected)
        rgb = bytearray(width * height * 3)
        for y in range(height):
            row = raw[y * row_bytes : (y + 1) * row_bytes]
            for x in range(width):
                px = struct.unpack_from(">H", row, x * 2)[0]
                r = ((px >> 10) & 31) * 255 // 31
                g = ((px >> 5) & 31) * 255 // 31
                b = (px & 31) * 255 // 31
                idx = (y * width + x) * 3
                rgb[idx] = r
                rgb[idx + 1] = g
                rgb[idx + 2] = b
        return Image.frombytes("RGB", (width, height), bytes(rgb))
    return None


def extract_cast(cst_path: Path, out_dir: Path):
    data = cst_path.read_bytes()
    le = data[:4] == b"XFIR"
    end = "<" if le else ">"
    tag = lambda b: b[::-1].decode("latin1") if le else b.decode("latin1")

    # Find imap -> mmap
    pos = 12
    imap_off = None
    while pos + 8 <= len(data):
        t = tag(data[pos : pos + 4])
        sz = struct.unpack_from(end + "I", data, pos + 4)[0]
        if t == "imap":
            imap_off = pos + 8
            break
        pos += 8 + sz + (sz % 2)
    if imap_off is None:
        return []

    mmap_pos = struct.unpack_from(end + "I", data, imap_off + 4)[0]
    m_off = mmap_pos + 8
    prop_sz, entry_sz = struct.unpack_from(end + "HH", data, m_off)
    _total_cnt, used_cnt = struct.unpack_from(end + "II", data, m_off + 4)

    entries = {}
    key_entry = None
    cur = m_off + prop_sz
    for i in range(used_cnt):
        et = tag(data[cur : cur + 4])
        esz, eoff = struct.unpack_from(end + "II", data, cur + 4)
        entries[i] = (et, esz, eoff)
        if et == "KEY*":
            key_entry = (esz, eoff)
        cur += entry_sz

    # Parse KEY* mapping (cast_id -> {chunk_type: chunk_id})
    key_map = {}
    if key_entry:
        ksz, koff = key_entry
        kd = data[koff + 8 : koff + 8 + ksz]
        if len(kd) >= 12:
            k_esize, k_hsize, k_total, k_used = struct.unpack_from(end + "HHII", kd, 0)
            p = k_hsize
            for _ in range(k_used):
                if p + k_esize > len(kd):
                    break
                sec_id, cast_id = struct.unpack_from(end + "II", kd, p)
                ct = tag(kd[p + 8 : p + 12])
                key_map.setdefault(cast_id, {})[ct] = sec_id
                p += k_esize

    out_dir.mkdir(parents=True, exist_ok=True)
    extracted = []

    for cid, (et, esz, eoff) in entries.items():
        if et != "CASt" or eoff + 8 + esz > len(data):
            continue
        c = data[eoff + 8 : eoff + 8 + esz]
        if len(c) < 12:
            continue
        mtype, info_len, spec_len = struct.unpack_from(">III", c, 0)
        if mtype != 1:  # 1 = Bitmap
            continue
        info = c[12 : 12 + info_len]
        spec = c[12 + info_len : 12 + info_len + spec_len]

        # Member name
        nm = f"member_{cid}"
        if len(info) >= 20:
            hsz = struct.unpack_from(">I", info, 0)[0]
            if hsz < len(info) - 6:
                lt = info[hsz:]
                cnt = struct.unpack_from(">H", lt, 0)[0]
                if 1 < cnt < 60 and 2 + (cnt + 1) * 4 <= len(lt):
                    offs = [struct.unpack_from(">I", lt, 2 + k * 4)[0] for k in range(cnt + 1)]
                    base = 2 + (cnt + 1) * 4
                    if len(offs) > 2 and base + offs[2] <= len(lt):
                        nb = lt[base + offs[1] : base + offs[2]]
                        if len(nb) > 1:
                            cand = nb[1 : 1 + nb[0]].decode("latin1", errors="ignore").strip()
                            if cand:
                                nm = cand

        # Parse bitmap specific data (Director 6+: pitch, top, left, bottom, right, ..., bitDepth at +22)
        width = height = row_bytes = bit_depth = 0
        if len(spec) >= 10:
            pitch_raw, top, left, bottom, right = struct.unpack_from(">Hhhhh", spec, 0)
            row_bytes = pitch_raw & 0x7FFF
            width = right - left
            height = bottom - top
            if len(spec) >= 24:
                bit_depth = spec[23]
            else:
                bit_depth = 8

        linked = key_map.get(cid, {})
        img = None
        src_kind = ""

        # Case 1: ediM (JPEG image) + optional ALFA
        if "ediM" in linked and linked["ediM"] in entries:
            _, msz, moff = entries[linked["ediM"]]
            ed = data[moff + 8 : moff + 8 + msz]
            jpos = ed.find(b"\xff\xd8\xff")
            if jpos >= 0:
                try:
                    img = Image.open(io.BytesIO(ed[jpos:])).convert("RGBA")
                    src_kind = "ediM"
                except Exception:
                    img = None

        # Case 2: BITD raw/RLE bitmap
        if img is None and "BITD" in linked and linked["BITD"] in entries:
            _, bsz, boff = entries[linked["BITD"]]
            bd = data[boff + 8 : boff + 8 + bsz]
            try:
                img = decode_bitd(bd, width, height, row_bytes, bit_depth)
                if img is not None:
                    img = img.convert("RGBA")
                    src_kind = f"BITD_{bit_depth}"
            except Exception:
                img = None

        # Attach ALFA alpha mask if present
        if img is not None and "ALFA" in linked and linked["ALFA"] in entries:
            _, asz, aoff = entries[linked["ALFA"]]
            ad = data[aoff + 8 : aoff + 8 + asz]
            w, h = img.size
            # ALFA is 8-bit PackBits RLE (sometimes padded to even width)
            try:
                a_raw = decode_rle_bytes(ad, w * h)
                a_img = Image.frombytes("L", (w, h), a_raw)
                # Check if alpha looks valid (not all zeros)
                extrema = a_img.getextrema()
                if extrema[1] > 0:
                    img.putalpha(a_img)
                    src_kind += "+ALFA"
            except Exception:
                pass

        if img is not None:
            fname = safe_name(nm) + ".png"
            out_path = out_dir / fname
            img.save(out_path)
            extracted.append({
                "name": nm,
                "file": str(out_path.relative_to(OUT_ROOT)),
                "size": list(img.size),
                "source": src_kind,
            })

    return extracted


def main():
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    summary = {}
    total = 0
    for cname in TARGET_CASTS:
        p = CAST_ROOT / cname / f"{cname}.cst"
        if not p.exists():
            continue
        items = extract_cast(p, OUT_ROOT / cname)
        summary[cname] = items
        total += len(items)
        print(f"{cname:22s}: extracted {len(items):3d} bitmaps")
    (OUT_ROOT / "index.json").write_text(json.dumps(summary, indent=2))
    print(f"TOTAL extracted original 2007 UI/HUD/Menu bitmaps: {total}")


if __name__ == "__main__":
    main()
