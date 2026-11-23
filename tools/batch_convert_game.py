#!/usr/bin/env python3
"""
Batch converts Kaptein Sabeltann Shockwave 3D (.w3d) levels and characters into
HD PBR Godot 4 .glb assets using Shockwave3DWorldConverter (in Wine32 Docker) +
4x HD Texture Upscaling + PBR Normal/ORM synthesis.
"""
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from upscale_and_pack_glb import build_glb

SRC_W3D = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets/w3d")
WORK_ROOT = Path("/home/antigravity/w3d_batch_work")
GODOT_ASSETS = Path("/home/antigravity/sabeltann_remake/godot_project/assets")

LEVEL_NAMES = [
    "mainmenu",
    "abra",
    "cave",
    "world_map",
    "graal_mountain",
    "graal_bosslevel",
    "fatamorgana_city",
    "fatamorgana_palace",
    "fatamorgana_bosslevel",
    "magakhan_beach",
    "magakhan_jungle",
    "magakhan_palace",
    "magakhan_dungeon",
    "magakhan_endboss_level",
    "cave_end",
    "cave_end_bosslevel",
    "treasurehunt",
    "swimming",
    "outro",
]

MODEL_NAMES = [
    "pinky",
    "sabeltann",
    "langemann",
    "sunniva",
    "pelle",
    "skalken",
    "miriam",
    "ghost",
    "maga_khan",
    "skeleton",
    "arab_guard1",
    "mk_henchman1",
    "tribesman",
    "panther",
    "meatplant",
    "opponent1",
    "sultan",
    "shopkeeper",
    "benjamin",
    "sirikit",
    "malena",
    "chiefs_daughter",
    "dog",
    "movablecrate",
]


def convert_single_w3d(stem: str, category: str, timeout_s: int = 90):
    src = SRC_W3D / f"{stem}.w3d"
    if not src.exists():
        return stem, False, "missing .w3d"

    out_glb = GODOT_ASSETS / category / f"{stem}.glb"
    if out_glb.exists() and out_glb.stat().st_size > 2000:
        return stem, True, "already exists"

    wdir = WORK_ROOT / stem
    if wdir.exists():
        shutil.rmtree(wdir, ignore_errors=True)
    wdir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, wdir / f"{stem}.w3d")

    script = f"""
set -e
Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
sleep 0.6
wine /conv/Shockwave3DWorldConverter.exe "Z:\\\\work\\\\{stem}.w3d" >/dev/null 2>&1 &
WINE_PID=$!

MAINWIN=""
for i in $(seq 1 20); do
  MAINWIN=$(xdotool search --name "Shockwave 3D World Converter" 2>/dev/null | head -n1 || true)
  if [ -n "$MAINWIN" ]; then break; fi
  sleep 0.4
done

if [ -z "$MAINWIN" ]; then
  kill $WINE_PID $XVFB_PID 2>/dev/null || true
  exit 2
fi

sleep 1.5
BEFORE_WINS=$(xdotool search --name ".*" 2>/dev/null | tr '\\n' ' ' || true)
xdotool windowfocus $MAINWIN 2>/dev/null || true
sleep 0.2
xdotool mousemove --window $MAINWIN 320 282 click 1

SAVED=0
STABLE=0
LAST_SZ=0
for i in $(seq 1 {timeout_s}); do
  sleep 1
  if [ $SAVED -eq 0 ]; then
    SAVEWIN=$(xdotool search --name "Export Wavefront" 2>/dev/null | head -n1 || true)
    if [ -n "$SAVEWIN" ]; then
      xdotool windowfocus $SAVEWIN 2>/dev/null || true
      sleep 0.3
      xdotool key Return
      SAVED=1
      sleep 0.5
    elif [ $i -ge 20 ]; then
      break
    elif [ $((i % 2)) -eq 0 ]; then
      xdotool windowfocus $MAINWIN 2>/dev/null || true
      sleep 0.15
      xdotool mousemove --window $MAINWIN 320 282 click 1
    fi
  else
    # Check if an alert dialog popped up (a window ID not in BEFORE_WINS and not SAVEWIN)
    CUR_WINS=$(xdotool search --name ".*" 2>/dev/null || true)
    NEW_ALERT=0
    for w in $CUR_WINS; do
      if [ "$w" != "$MAINWIN" ] && [ "$w" != "$SAVEWIN" ]; then
        case " $BEFORE_WINS " in
          *" $w "*) ;;
          *)
            T=$(xdotool getwindowname $w 2>/dev/null || true)
            if [ -n "$T" ] && [ "$T" != "Default IME" ]; then
              NEW_ALERT=1
              break
            fi
            ;;
        esac
      fi
    done
    if [ $NEW_ALERT -eq 1 ]; then
      sleep 0.4
      break
    fi

    # Fallback: if OBJ exists with faces and stopped growing for 5 consecutive seconds
    OBJF=""
    if [ -f /work/{stem}.obj ]; then OBJF=/work/{stem}.obj; fi
    if [ -f /work/{stem}.OBJ ]; then OBJF=/work/{stem}.OBJ; fi
    if [ -n "$OBJF" ]; then
      SZ=$(stat -c%s "$OBJF" 2>/dev/null || echo 0)
      HAS_F=$(grep -m1 '^f ' "$OBJF" 2>/dev/null | wc -l || echo 0)
      if [ "$SZ" -gt 1000 ] && [ "$HAS_F" -ge 1 ] && [ "$SZ" -eq "$LAST_SZ" ]; then
        STABLE=$((STABLE + 1))
        if [ $STABLE -ge 5 ]; then
          break
        fi
      else
        STABLE=0
        LAST_SZ=$SZ
      fi
    fi
  fi
done

kill $WINE_PID $XVFB_PID 2>/dev/null || true
"""
    t0 = time.time()
    proc = subprocess.run(
        [
            "docker", "run", "--rm",
            "-v", "/home/antigravity/w3d_converter:/conv:ro",
            "-v", f"{wdir}:/work",
            "sabeltann-extractor",
            "bash", "-c", script,
        ],
        capture_output=True,
        text=True,
        timeout=timeout_s + 30,
    )

    obj_file = wdir / f"{stem}.obj"
    if not obj_file.exists():
        obj_file = wdir / f"{stem}.OBJ"
    if not obj_file.exists() or obj_file.stat().st_size < 100:
        return stem, False, f"no OBJ (rc={proc.returncode})"

    ok, msg = build_glb(obj_file, out_glb, upscale=True, scale=0.1, swap_yz=True)
    # Clean temporary OBJ/TIFF to save disk space
    shutil.rmtree(wdir, ignore_errors=True)
    dt = time.time() - t0
    return stem, ok, f"{msg} ({dt:.1f}s)"


def main():
    WORK_ROOT.mkdir(parents=True, exist_ok=True)
    (GODOT_ASSETS / "levels").mkdir(parents=True, exist_ok=True)
    (GODOT_ASSETS / "models").mkdir(parents=True, exist_ok=True)

    # Copy gameplay JSONs into Godot project
    gp_src = Path("/home/antigravity/sabeltann_remake/data/gameplay")
    gp_dst = Path("/home/antigravity/sabeltann_remake/godot_project/data/gameplay")
    gp_dst.mkdir(parents=True, exist_ok=True)
    for jf in gp_src.glob("*.json"):
        shutil.copy2(jf, gp_dst / jf.name)

    # Build conversion queue
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    tasks = []
    if mode in ("all", "models"):
        for m in MODEL_NAMES:
            tasks.append((m, "models", 65))
    if mode in ("all", "levels"):
        for lv in LEVEL_NAMES:
            tasks.append((lv, "levels", 140))

    print(f"Starting HD W3D->GLB batch conversion ({len(tasks)} assets, mode={mode})...")
    ok_count = 0
    # 2 parallel Docker workers match our 2 CPU threads cleanly
    with ThreadPoolExecutor(max_workers=2) as pool:
        futs = {pool.submit(convert_single_w3d, s, c, t): (s, c) for s, c, t in tasks}
        for fut in as_completed(futs):
            stem, ok, msg = fut.result()
            status = "OK  " if ok else "FAIL"
            if ok:
                ok_count += 1
            print(f"[{status}] {futs[fut][1]}/{stem}.glb -> {msg}", flush=True)

    print(f"\nFinished: {ok_count}/{len(tasks)} assets converted to HD PBR GLB!")


if __name__ == "__main__":
    main()
