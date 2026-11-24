#!/usr/bin/env python3
"""
Configures hardware VRAM Compressed (S3TC/BC1/BC3 + RGTC/BC5 Normal Maps) with full mipmaps
on all 4K/2K 3D level, character, triplanar PBR, and skybox .import files in godot_project/.
Leaves 2D UI sprites and cutscenes untouched (Lossless).
"""
import json
import re
from pathlib import Path

ROOT = Path("/home/antigravity/sabeltann_remake")
PROJ = ROOT / "godot_project"
CHAR_REPORT = ROOT / "work_refs/cc0_library/character_4k_report.json"
LVL_REPORT = ROOT / "work_refs/cc0_library/level_4k_report.json"


def load_normal_sets():
    norm_files = set()
    for rpath, sub in ((CHAR_REPORT, "models"), (LVL_REPORT, "levels")):
        if not rpath.exists():
            continue
        data = json.loads(rpath.read_text())
        for stem, idxs in data.get("normal_img_indices", {}).items():
            for idx in idxs:
                norm_files.add((sub, f"{stem}_{idx}"))
    return norm_files


def patch_import_file(imp_path: Path, is_normal: bool, is_sky: bool = False):
    txt = imp_path.read_text(encoding="utf-8", errors="ignore")
    if 'importer="texture"' not in txt:
        return False
    orig = txt

    def set_kv(s: str, key: str, val: str) -> str:
        pat = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
        if pat.search(s):
            return pat.sub(f"{key}={val}", s)
        return s.rstrip() + f"\n{key}={val}\n"

    txt = set_kv(txt, "compress/mode", "0" if is_sky else "2")
    txt = set_kv(txt, "compress/high_quality", "false")
    txt = set_kv(txt, "compress/normal_map", "1" if is_normal else "0")
    txt = set_kv(txt, "mipmaps/generate", "false" if is_sky else "true")
    txt = set_kv(txt, "mipmaps/limit", "-1")
    txt = set_kv(txt, "process/size_limit", "0")
    if txt != orig:
        imp_path.write_text(txt, encoding="utf-8")
        return True
    return False


def main():
    norm_sets = load_normal_sets()
    changed = 0
    total = 0

    for sub in ("levels", "models"):
        d = PROJ / "assets" / sub
        for imp in sorted(d.glob("*.import")):
            src_name = imp.name[:-7]  # strip .import
            if not src_name.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            total += 1
            stem = Path(src_name).stem
            is_nrm = (sub, stem) in norm_sets
            if patch_import_file(imp, is_normal=is_nrm, is_sky=False):
                changed += 1

    pbr_dir = PROJ / "assets/textures/pbr"
    if pbr_dir.exists():
        for imp in sorted(pbr_dir.glob("*.import")):
            src_name = imp.name[:-7]
            if not src_name.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            total += 1
            is_nrm = "_normal." in src_name.lower()
            if patch_import_file(imp, is_normal=is_nrm, is_sky=False):
                changed += 1

    sky_dir = PROJ / "assets/skies"
    if sky_dir.exists():
        for imp in sorted(sky_dir.glob("*.import")):
            src_name = imp.name[:-7]
            if not src_name.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            total += 1
            if patch_import_file(imp, is_normal=False, is_sky=True):
                changed += 1

    print(f"[OK] Configured S3TC/BC5 VRAM Compressed .import files: {changed} updated / {total} total textures.", flush=True)


if __name__ == "__main__":
    main()
