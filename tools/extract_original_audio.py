#!/usr/bin/env python3
"""
Extracts original sound effects and music from Macromedia Director .cct files
via ProjectorRays chunk dumps -> standard 16-bit PCM WAV files for Godot 4.
"""
import json
import re
import shutil
import struct
import subprocess
import wave
from pathlib import Path

PROJECTORRAYS = "/home/antigravity/ProjectorRays/projectorrays"
CAST_DIR = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets/cast")
TMP_DUMP = Path("/home/antigravity/audio_dump_all")
OUT_AUDIO = Path("/home/antigravity/sabeltann_remake/godot_project/assets/audio")

CASTS_TO_EXTRACT = [
    "generic",
    "generic2",
    "abra",
    "cave",
    "menu_",
    "world_map",
    "swimming",
    "outro",
]


def parse_mac_snd_to_wav(data: bytes, out_wav: Path) -> bool:
    """Parse classic Mac 'snd ' resource (Format 1 or 2, standard/extended/compressed PCM)."""
    if len(data) < 42:
        return False
    fmt = struct.unpack_from(">H", data, 0)[0]
    if fmt == 1:
        num_mods = struct.unpack_from(">H", data, 2)[0]
        off = 4 + num_mods * 6
    elif fmt == 2:
        off = 4
    else:
        return False

    if off + 2 > len(data):
        return False
    num_cmds = struct.unpack_from(">H", data, off)[0]
    off += 2
    hdr_off = None
    for _ in range(num_cmds):
        if off + 8 > len(data):
            break
        cmd, p1, p2 = struct.unpack_from(">HHI", data, off)
        off += 8
        if (cmd & 0x7FFF) in (80, 81):  # soundCmd / bufferCmd
            hdr_off = p2
            break
    if hdr_off is None or hdr_off + 22 > len(data):
        return False

    # SoundHeader
    sample_ptr, num_ch_or_len, sample_rate_fixed = struct.unpack_from(">III", data, hdr_off)
    sample_rate = max(8000, min(48000, sample_rate_fixed >> 16))
    encode = data[hdr_off + 20]

    if encode == 0x00:  # stdSH (8-bit unsigned mono)
        num_frames = num_ch_or_len
        channels = 1
        bits = 8
        pcm_off = hdr_off + 22
    elif encode == 0xFF:  # extSH
        if hdr_off + 64 > len(data):
            return False
        channels = max(1, min(2, num_ch_or_len))
        num_frames = struct.unpack_from(">I", data, hdr_off + 22)[0]
        bits = struct.unpack_from(">H", data, hdr_off + 48)[0]
        if bits not in (8, 16):
            bits = 16
        pcm_off = hdr_off + 64
    elif encode == 0xFE:  # cmpSH (skip unsupported compressed unless raw PCM)
        if hdr_off + 64 > len(data):
            return False
        comp_id = struct.unpack_from(">h", data, hdr_off + 56)[0]
        if comp_id != 0:
            return False
        channels = max(1, min(2, num_ch_or_len))
        num_frames = struct.unpack_from(">I", data, hdr_off + 22)[0]
        bits = struct.unpack_from(">H", data, hdr_off + 62)[0]
        if bits not in (8, 16):
            bits = 16
        pcm_off = hdr_off + 64
    else:
        return False

    pcm = data[pcm_off : pcm_off + num_frames * channels * (bits // 8)]
    if len(pcm) < 64:
        return False

    # Convert big-endian 16-bit PCM to little-endian 16-bit PCM for WAV
    if bits == 16:
        arr = bytearray(len(pcm))
        arr[0::2] = pcm[1::2]
        arr[1::2] = pcm[0::2]
        pcm = bytes(arr)

    out_wav.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out_wav), "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(bits // 8)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm)
    return True


def sanitize(name: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9_\-]+", "_", name.strip().lower()).strip("_")
    return s or "sound"


def main():
    OUT_AUDIO.mkdir(parents=True, exist_ok=True)
    TMP_DUMP.mkdir(parents=True, exist_ok=True)
    total = 0

    for cname in CASTS_TO_EXTRACT:
        cct = CAST_DIR / f"{cname}.cct"
        if not cct.exists():
            continue
        cdump = TMP_DUMP / cname
        subprocess.run(
            [PROJECTORRAYS, "decompile", str(cct), "-o", str(TMP_DUMP), "--dump-chunks", "--dump-json"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        chunks_dir = cdump / "chunks"
        if not chunks_dir.exists():
            continue

        # Parse KEY_ table via regex (ProjectorRays occasionally emits unescaped fourCC chars)
        sec_to_cast = {}
        key_re = re.compile(r'"sectionID":\s*(\d+),\s*"castID":\s*(\d+),\s*"fourCC":\s*"snd "')
        for kf in chunks_dir.glob("KEY_*.json"):
            txt = kf.read_text(encoding="latin1", errors="replace")
            for m in key_re.finditer(txt):
                sec_to_cast[int(m.group(1))] = int(m.group(2))

        # Parse CASt names: castID -> member name
        cast_names = {}
        name_re = re.compile(r'"name":\s*"([^"]+)"')
        for cf in chunks_dir.glob("CASt-*.json"):
            try:
                cid = int(cf.stem.split("-")[1])
                m = name_re.search(cf.read_text(encoding="latin1", errors="replace"))
                if m:
                    cast_names[cid] = m.group(1)
            except Exception:
                pass

        extracted_here = 0
        for sf in sorted(chunks_dir.glob("snd -*.bin")):
            try:
                sid = int(sf.stem.split("-")[1])
            except Exception:
                continue
            cid = sec_to_cast.get(sid)
            raw_name = cast_names.get(cid, "")
            if not raw_name:
                continue
            low = raw_name.lower()
            # Skip Russian voice-over lines (keep authentic SFX, footsteps, swords, coins, ambient, music!)
            if any(skip in low for skip in ("speech", "dialog", "voice", "conv", "talk", "mumble", "shout", "ru_")):
                continue
            out_name = sanitize(f"{cname}_{raw_name}" if cname not in ("generic", "generic2") else raw_name)
            out_ogg = OUT_AUDIO / f"{out_name}.ogg"
            if out_ogg.exists():
                continue
            tmp_wav = TMP_DUMP / f"{out_name}.wav"
            if parse_mac_snd_to_wav(sf.read_bytes(), tmp_wav):
                res = subprocess.run(
                    ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp_wav), "-c:a", "libvorbis", "-q:a", "4", str(out_ogg)],
                )
                tmp_wav.unlink(missing_ok=True)
                if res.returncode == 0 and out_ogg.exists():
                    extracted_here += 1
                    total += 1
        print(f"Cast {cname}: extracted {extracted_here} OGG sounds", flush=True)

    shutil.rmtree(TMP_DUMP, ignore_errors=True)
    print(f"Total original OGG sounds extracted: {total}")


if __name__ == "__main__":
    main()
