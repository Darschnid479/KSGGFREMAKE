#!/usr/bin/env python3
"""
Extracts ALL 808 original sound members from all 23 Macromedia Director .cct cast files:
  - Music, ambient & SFX -> godot_project/assets/audio/<name>.ogg
  - Spoken character voice lines -> godot_project/assets/voices_orig/<exact_member_name>.ogg
  - Full structured catalog -> godot_project/data/voice_catalog.json (used to generate 1:1 Norwegian voices!)
"""
import json
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
from extract_original_audio import parse_mac_snd_to_wav, sanitize

PROJECTORRAYS = "/home/antigravity/ProjectorRays/projectorrays"
CAST_DIR = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets/cast")
OUT_SFX = Path("/home/antigravity/sabeltann_remake/godot_project/assets/audio")
OUT_VOICES_ORIG = Path("/home/antigravity/sabeltann_remake/godot_project/assets/voices_orig")
CATALOG_OUT = Path("/home/antigravity/sabeltann_remake/godot_project/data/voice_catalog.json")
TMP_DIR = Path("/tmp/extract_all_audio_work")

SPEAKER_SUFFIXES = (
    "sabeltann", "pinky", "langemann", "pelle", "pysa", "skalken", "benjamin",
    "sunniva", "miriam", "sultan", "shopkeeper", "sirikit", "malena",
    "storyteller", "boss", "graal", "greven", "magakhan", "maga_khan",
    "gabriel", "ghost", "guard", "arab", "boy", "daughter", "chief",
    "villager", "npc", "pirate", "parrot", "beggar", "merchant", "woman", "man", "girl",
)


def is_voice_member(raw_name: str, cast_name: str) -> tuple[bool, str]:
    low = raw_name.lower().strip()
    parts = re.split(r"[^a-z0-9]+", low)
    if any(k in low for k in ("music", "ambience", "ambient", "lavaloop", "lavamovement", "lavasink", "crushablewall", "footstep", "swordswing", "fireball", "bashbarrel", "coinpopup", "door_", "areatrigger_", "flames_", "portal_loop", "actionicon", "glassball", "water_", "splash", "cannon", "explosion")):
        return False, ""
    if parts and parts[-1] in SPEAKER_SUFFIXES:
        return True, parts[-1]
    if len(parts) >= 2 and parts[-2] in SPEAKER_SUFFIXES and parts[-1].isdigit():
        return True, parts[-2]
    # Numbered conversation items like <conv>_1_<speaker>
    m = re.search(r"_(\d+)_([a-z0-9_]+)$", low)
    if m:
        return True, m.group(2)
    if any(k in low for k in ("_intro", "_speech", "_talk", "_shout", "_mumble", "_storyteller", "_dialog", "_conv", "_start_", "_end_")):
        return True, parts[-1] if parts else "narrator"
    return False, ""


def convert_wav_to_ogg(wav_path: Path, ogg_path: Path, is_voice: bool) -> bool:
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
        "-c:a", "libvorbis", "-q:a", "1" if is_voice else "4",
    ]
    if is_voice:
        cmd += ["-ac", "1", "-ar", "22050"]
    cmd.append(str(ogg_path))
    res = subprocess.run(cmd)
    wav_path.unlink(missing_ok=True)
    return res.returncode == 0 and ogg_path.exists()


def main():
    OUT_SFX.mkdir(parents=True, exist_ok=True)
    OUT_VOICES_ORIG.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(TMP_DIR, ignore_errors=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    catalog = {}
    jobs = []

    for cct in sorted(CAST_DIR.glob("*.cct")):
        cname = cct.stem
        subprocess.run(
            [PROJECTORRAYS, "decompile", str(cct), "-o", str(TMP_DIR), "--dump-chunks", "--dump-json"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        cd = TMP_DIR / cname / "chunks"
        if not cd.exists():
            continue

        sec_to_cast = {}
        key_re = re.compile(r'"sectionID":\s*(\d+),\s*"castID":\s*(\d+),\s*"fourCC":\s*"snd "')
        for kf in cd.glob("KEY_*.json"):
            for m in key_re.finditer(kf.read_text("latin1", "replace")):
                sec_to_cast[int(m.group(1))] = int(m.group(2))

        cast_names = {}
        name_re = re.compile(r'"name":\s*"([^"]+)"')
        for cf in cd.glob("CASt-*.json"):
            try:
                cid = int(cf.stem.split("-")[1])
                m = name_re.search(cf.read_text("latin1", "replace"))
                if m:
                    cast_names[cid] = m.group(1)
            except Exception:
                pass

        for sf in sorted(cd.glob("snd -*.bin")):
            try:
                sid = int(sf.stem.split("-")[1])
            except Exception:
                continue
            cid = sec_to_cast.get(sid)
            raw_name = cast_names.get(cid, "")
            if not raw_name:
                continue
            is_v, speaker = is_voice_member(raw_name, cname)
            clean_key = sanitize(raw_name)
            if is_v:
                out_ogg = OUT_VOICES_ORIG / f"{clean_key}.ogg"
                catalog[clean_key] = {
                    "raw_name": raw_name,
                    "cast": cname,
                    "speaker": speaker,
                }
            else:
                out_name = sanitize(f"{cname}_{raw_name}" if cname not in ("generic", "generic2") else raw_name)
                out_ogg = OUT_SFX / f"{out_name}.ogg"

            if out_ogg.exists():
                continue
            tmp_wav = TMP_DIR / f"{cname}_{sid}_{clean_key}.wav"
            if parse_mac_snd_to_wav(sf.read_bytes(), tmp_wav):
                jobs.append((tmp_wav, out_ogg, is_v))

    print(f"Encoding {len(jobs)} new audio/voice OGG files across 4 threads...", flush=True)
    ok_n = 0
    with ThreadPoolExecutor(max_workers=4) as pool:
        for res in pool.map(lambda j: convert_wav_to_ogg(*j), jobs):
            if res:
                ok_n += 1

    CATALOG_OUT.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_OUT.write_text(json.dumps(catalog, indent=2, ensure_ascii=False), encoding="utf-8")
    shutil.rmtree(TMP_DIR, ignore_errors=True)
    print(f"Done! Encoded {ok_n} new files. Total voice clips cataloged: {len(catalog)}")
    # Print summary per cast
    by_cast = {}
    for v in catalog.values():
        by_cast[v["cast"]] = by_cast.get(v["cast"], 0) + 1
    for c, cnt in sorted(by_cast.items()):
        print(f"  {c:26s}: {cnt:3d} voice lines")


if __name__ == "__main__":
    main()
