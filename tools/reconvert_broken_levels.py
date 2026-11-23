#!/usr/bin/env python3
"""
Sanitizes illegal Windows filename characters ('"', '/', ':', '#', etc.) inside
Shockwave 3D (.w3d) shader/texture names in-place (preserving exact byte lengths)
so Shockwave3DWorldConverter exports 100% of all level meshes without crashing,
then packs crisp 4x HD PBR .glb assets.
"""
import shutil
import struct
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from upscale_and_pack_glb import build_glb

SRC_W3D = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets/w3d")
WORK_ROOT = Path("/home/antigravity/w3d_reconvert_work")
OUT_LEVELS = Path("/home/antigravity/sabeltann_remake/godot_project/assets/levels")

LEVELS_TO_FIX = [
    "cave",
    "cave_end",
    "cave_end_bosslevel",
    "graal_mountain",
    "fatamorgana_palace",
    "fatamorgana_bosslevel",
    "magakhan_beach",
    "magakhan_dungeon",
    "outro",
    "treasurehunt",
]

BAD_CHARS = set(b'"/:*?<>|\\#[], ')


def sanitize_w3d_bytes(src_path: Path, dst_path: Path) -> int:
    b = bytearray(src_path.read_bytes())
    bad_strings = set()
    pos = 0
    while pos + 8 <= len(b):
        t, ds = struct.unpack_from("<II", b, pos)
        if pos + 8 + ds > len(b):
            break
        if t in (0xFFFFFF10, 0xFFFFFF20, 0xFFFFFF21, 0xFFFFFF36):
            if ds >= 4:
                sl = struct.unpack_from("<H", b, pos + 8)[0]
                if 1 <= sl <= ds - 2:
                    s = bytes(b[pos + 10 : pos + 10 + sl])
                    if all(32 <= c < 127 for c in s) and any(c in BAD_CHARS for c in s):
                        bad_strings.add(s)
        pos += 8 + ds + ((4 - (ds % 4)) % 4)

    total_repl = 0
    for s in sorted(bad_strings, key=len, reverse=True):
        clean = bytes(ord("_") if c in BAD_CHARS else c for c in s)
        needle = struct.pack("<H", len(s)) + s
        repl = struct.pack("<H", len(clean)) + clean
        idx = 0
        while True:
            f = b.find(needle, idx)
            if f < 0:
                break
            b[f : f + len(needle)] = repl
            total_repl += 1
            idx = f + len(needle)

    dst_path.write_bytes(b)
    return total_repl


def reconvert_one(stem: str):
    src = SRC_W3D / f"{stem}.w3d"
    if not src.exists():
        return stem, False, "missing .w3d"
    wdir = WORK_ROOT / stem
    shutil.rmtree(wdir, ignore_errors=True)
    wdir.mkdir(parents=True, exist_ok=True)
    n_patched = sanitize_w3d_bytes(src, wdir / f"{stem}.w3d")

    run_sh = wdir / "run.sh"
    run_sh.write_text(
        f"""#!/bin/bash
Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
sleep 0.6
wine /conv/Shockwave3DWorldConverter.exe "Z:\\\\work\\\\{stem}.w3d" >/dev/null 2>&1 &
WINE_PID=$!
MAINWIN=""
for i in $(seq 1 25); do
  MAINWIN=$(xdotool search --name "Shockwave 3D World Converter" 2>/dev/null | head -n1 || true)
  [ -n "$MAINWIN" ] && break
  sleep 0.4
done
if [ -z "$MAINWIN" ]; then
  kill $WINE_PID $XVFB_PID 2>/dev/null || true
  exit 2
fi
sleep 1.5
xdotool windowfocus $MAINWIN 2>/dev/null || true
sleep 0.2
xdotool mousemove --window $MAINWIN 320 282 click 1
SAVED=0; LAST_SZ=0; STABLE=0
for i in $(seq 1 130); do
  sleep 1
  if [ $SAVED -eq 0 ]; then
    SAVEWIN=$(xdotool search --name "Export Wavefront" 2>/dev/null | head -n1 || true)
    if [ -n "$SAVEWIN" ]; then
      xdotool windowfocus $SAVEWIN 2>/dev/null || true
      sleep 0.3
      xdotool key Return
      SAVED=1
    elif [ $((i % 3)) -eq 0 ]; then
      xdotool windowfocus $MAINWIN 2>/dev/null || true
      xdotool mousemove --window $MAINWIN 320 282 click 1
    fi
  else
    SZ=$(stat -c%s /work/{stem}.obj 2>/dev/null || echo 0)
    WINS=$(xdotool search --name ".*" 2>/dev/null | xargs -I{{}} sh -c 'T=$(xdotool getwindowname {{}} 2>/dev/null); [ -n "$T" ] && [ "$T" != "Default IME" ] && echo -n "$T | "' )
    if [ "$SZ" -ne "$LAST_SZ" ]; then
      LAST_SZ=$SZ
      STABLE=0
    else
      STABLE=$((STABLE + 1))
    fi
    if echo "$WINS" | grep -qiE "error|script|director|complete|done"; then
      sleep 0.5
      break
    fi
    if [ "$SZ" -gt 10000 ] && [ $STABLE -ge 9 ]; then
      break
    fi
  fi
done
kill $WINE_PID $XVFB_PID 2>/dev/null || true
""",
        encoding="utf-8",
    )
    run_sh.chmod(0o755)

    t0 = time.time()
    subprocess.run(
        [
            "docker", "run", "--rm",
            "-v", "/home/antigravity/w3d_converter:/conv:ro",
            "-v", f"{wdir}:/work",
            "sabeltann-extractor",
            "bash", "/work/run.sh",
        ],
        capture_output=True,
        text=True,
        timeout=170,
    )

    obj_file = wdir / f"{stem}.obj"
    if not obj_file.exists():
        obj_file = wdir / f"{stem}.OBJ"
    if not obj_file.exists() or obj_file.stat().st_size < 1000:
        shutil.rmtree(wdir, ignore_errors=True)
        return stem, False, f"no OBJ (patched={n_patched})"

    out_glb = OUT_LEVELS / f"{stem}.glb"
    ok, msg = build_glb(obj_file, out_glb, upscale=True, scale=0.1, swap_yz=True)
    shutil.rmtree(wdir, ignore_errors=True)
    dt = time.time() - t0
    return stem, ok, f"patched={n_patched} | {msg} ({dt:.1f}s)"


def main():
    WORK_ROOT.mkdir(parents=True, exist_ok=True)
    targets = sys.argv[1:] if len(sys.argv) > 1 else LEVELS_TO_FIX
    print(f"Re-converting {len(targets)} levels with W3D sanitizer...", flush=True)
    with ThreadPoolExecutor(max_workers=2) as pool:
        futs = {pool.submit(reconvert_one, s): s for s in targets}
        for fut in as_completed(futs):
            stem, ok, msg = fut.result()
            print(f"[{'OK  ' if ok else 'FAIL'}] {stem}.glb -> {msg}", flush=True)
    shutil.rmtree(WORK_ROOT, ignore_errors=True)


if __name__ == "__main__":
    main()
