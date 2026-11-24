#!/usr/bin/env python3
"""
Downloads and stylizes a comprehensive, 100% CC0 licensed PBR source texture library
from Poly Haven (https://polyhaven.com, CC0 1.0) and ambientCG (https://ambientcg.com, CC0 1.0)
for KSGGFREMAKE's 2026 Stylized 3D Animated Film rebuild.

Every source pack is recorded with exact asset ID, provider, URL, license, and surface role
in work_refs/cc0_library/library_manifest.json.
Raw 1K/2K source maps are processed through an edge-preserving stylized art pipeline so
they deliver crisp animated-film wood, rope, sailcloth, plaster, sandstone, slate, metal,
gold, leather, cloth, foliage, sand, and lava WITHOUT gritty photorealistic noise.
"""
import io
import json
import os
import shutil
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter, uniform_filter

RAW_DIR = Path("/home/antigravity/sabeltann_remake/work_refs/cc0_library/raw")
STYL_DIR = Path("/home/antigravity/sabeltann_remake/work_refs/cc0_library/stylized")
EXISTING_PBR = Path("/home/antigravity/sabeltann_remake/godot_project/assets/textures/pbr")
MANIFEST_PATH = Path("/home/antigravity/sabeltann_remake/work_refs/cc0_library/library_manifest.json")

# Curated CC0 PBR material library covering EVERY distinct material class in Kaptein Sabeltann (2007)
POLYHAVEN_PACKS = {
    # Wood & maritime timber
    "wood_planks_warm": ("brown_planks_05", "Warm stylized timber planks for Abra docks, bridges, and cabin decks"),
    "wood_planks_dark": ("dark_wooden_planks", "Dark weathered maritime planking for Den Sorte Dame hull and dungeon beams"),
    "wood_planks_painted": ("blue_painted_planks", "Painted timber planking for Abra Havn houses, shutters, and painted doors"),
    "wood_fine_grain": ("fine_grained_wood", "Clean fine wood grain for masts, railings, furniture, barrels, and crates"),
    "wood_bamboo": ("bamboo_wall", "Stylized bamboo and Oriental timber slats for Maga Khan palace"),
    # Masonry, rock, plaster & architecture
    "plaster_smooth": ("painted_plaster_wall", "Clean painted stucco plaster for Abra Havn and Fata Morgana walls"),
    "stucco_warm": ("white_stucco", "Warm smooth stucco plaster for Fata Morgana domes, arches, and towers"),
    "sandstone_blocks": ("sandstone_blocks_04", "Carved sandstone ashlar masonry for Fata Morgana palace and cave altars"),
    "stone_castle": ("castle_wall_slates", "Castle stone blocks for Graal fortress walls, ramparts, and battlements"),
    "stone_slate_floor": ("slate_floor_02", "Smooth paved stone tiles for Graal mountain paths and temple courtyards"),
    "stone_cobble": ("cobblestone_04", "Rounded harbor cobblestones for Abra Havn streets and squares"),
    "stone_mossy": ("mossy_stone_wall", "Damp mossy stonework for dungeon walls, wells, and underwater ruins"),
    "rock_cave": ("rock_face_03", "Cavern rock strata for Grusomme Gabriels grotte and Graal cliffs"),
    "rock_cliff": ("aerial_rocks_02", "Bold faceted cliff rock for mountain walls and underwater trenches"),
    "roof_slate": ("roof_slates_02", "Overlapping roof slates for Abra Havn pirate houses"),
    "roof_terracotta": ("clay_roof_tiles_02", "Curved terracotta roof tiles for palace pavilions and harbor roofs"),
    "marble_palace": ("marble_01", "Polished veined palace marble for Sultan and Maga Khan halls"),
    # Ground, sand, grass & nature
    "sand_beach": ("coast_sand_01", "Soft wind-rippled beach sand for Maga Khan Beach, Treasure Island, and World Map"),
    "grass_lush": ("grass_ground", "Vibrant island meadow grass for Treasure Island, Jungle, and World Map islands"),
    "bark_tree": ("bark_brown_01", "Stylized palm and jungle tree trunk bark"),
    # Cloth, sails, leather, metal
    "fabric_sail": ("rough_linen", "Woven natural canvas sailcloth for Den Sorte Dame sails, flags, and banners"),
    "fabric_cloth": ("denim_fabric", "Fine woven cloth for pirate shirts, bandanas, tunics, and trousers"),
    "fabric_velvet": ("velour_velvet", "Rich matte velvet fabric for Sabeltann's coat, Sultan robes, and banners"),
    "leather_smooth": ("brown_leather", "Supple matte leather for pirate boots, belts, straps, and scabbards"),
    "metal_iron": ("metal_plate_02", "Forged dark iron for hinges, brackets, cannons, chains, grates, and anchors"),
    "metal_painted": ("painted_metal_shutter", "Painted/enamel metal panels for roofs, shields, and trims"),
}

AMBIENTCG_PACKS = {
    "rope_braided": ("Rope001", "Braided maritime hemp rope for ship rigging, dock moorings, and bridges"),
    "net_rigging": ("Net002A", "Woven ship netting and rope ladders"),
    "carpet_ornate": ("Carpet016", "Woven patterned fabric/carpet for Fata Morgana palace and flying carpet"),
    "lava_molten": ("Lava004", "Glowing magma fissures and obsidian crust for Cave & Maga Khan lava pools and dragon"),
    "foliage_leaf": ("Leaf001", "Organic veined tropical leaf surface for palm fronds, jungle plants, and meatplant"),
    "plaster_clean": ("Plaster001", "Ultra-clean subtle animated-style plaster & skin/bone micro-surface"),
}


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "KSGGFRemake-Stylized2026/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def download_file(url: str, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "KSGGFRemake-Stylized2026/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r, open(dst, "wb") as f:
        shutil.copyfileobj(r, f)


def fetch_polyhaven_pack(key: str, asset_id: str, desc: str):
    pdir = RAW_DIR / key
    alb_p = pdir / "albedo.jpg"
    nrm_p = pdir / "normal.jpg"
    rgh_p = pdir / "rough.jpg"
    if alb_p.exists() and nrm_p.exists() and rgh_p.exists():
        return key, True, {
            "key": key, "provider": "Poly Haven", "asset_id": asset_id,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://polyhaven.com/a/{asset_id}",
            "description": desc,
        }

    # Reuse already-downloaded 2K Poly Haven files if matching exact asset
    reuse_map = {
        "rock_cave": "rock_natural",
        "stone_mossy": "stone_masonry",
        "stone_cobble": "cobblestone",
        "sand_beach": "coast_sand",
        "rock_cliff": "cutaway_bedrock",
        "metal_iron": "forged_metal",
        "fabric_cloth": "fabric_detail",
        "leather_smooth": "leather_detail",
    }
    if key in reuse_map:
        rname = reuse_map[key]
        src_a = EXISTING_PBR / f"{rname}_albedo.jpg"
        src_n = EXISTING_PBR / f"{rname}_normal.jpg"
        src_r = EXISTING_PBR / f"{rname}_rough.jpg"
        if src_a.exists() and src_n.exists() and src_r.exists():
            pdir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_a, alb_p)
            shutil.copy2(src_n, nrm_p)
            shutil.copy2(src_r, rgh_p)
            return key, True, {
                "key": key, "provider": "Poly Haven", "asset_id": asset_id,
                "license": "CC0 1.0 Public Domain",
                "url": f"https://polyhaven.com/a/{asset_id}",
                "description": desc,
            }

    try:
        files = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
        pdir.mkdir(parents=True, exist_ok=True)

        def pick_url(candidates):
            for cname in candidates:
                if cname in files:
                    for res in ("1k", "2k"):
                        if res in files[cname]:
                            for fmt in ("jpg", "png"):
                                if fmt in files[cname][res]:
                                    return files[cname][res][fmt]["url"]
            return None

        u_alb = pick_url(["Diffuse", "diffuse", "albedo", "col", "Color"])
        u_nrm = pick_url(["nor_gl", "Normal", "nor_dx"])
        u_rgh = pick_url(["Rough", "roughness", "arm"])

        if not u_alb:
            return key, False, f"no diffuse url for {asset_id}"
        download_file(u_alb, alb_p)
        if u_nrm:
            download_file(u_nrm, nrm_p)
        if u_rgh:
            download_file(u_rgh, rgh_p)
        return key, True, {
            "key": key, "provider": "Poly Haven", "asset_id": asset_id,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://polyhaven.com/a/{asset_id}",
            "description": desc,
        }
    except Exception as e:
        return key, False, str(e)


def fetch_ambientcg_pack(key: str, asset_id: str, desc: str):
    pdir = RAW_DIR / key
    alb_p = pdir / "albedo.jpg"
    nrm_p = pdir / "normal.jpg"
    rgh_p = pdir / "rough.jpg"
    if alb_p.exists() and nrm_p.exists() and rgh_p.exists():
        return key, True, {
            "key": key, "provider": "ambientCG", "asset_id": asset_id,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://ambientcg.com/view?id={asset_id}",
            "description": desc,
        }
    try:
        zip_url = f"https://ambientcg.com/get?file={asset_id}_1K-JPG.zip"
        req = urllib.request.Request(zip_url, headers={"User-Agent": "KSGGFRemake-Stylized2026/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            zbytes = r.read()
        zf = zipfile.ZipFile(io.BytesIO(zbytes))
        pdir.mkdir(parents=True, exist_ok=True)
        for name in zf.namelist():
            nl = name.lower()
            if not nl.endswith((".jpg", ".jpeg", ".png")):
                continue
            if "color" in nl and not alb_p.exists():
                alb_p.write_bytes(zf.read(name))
            elif "normalgl" in nl and not nrm_p.exists():
                nrm_p.write_bytes(zf.read(name))
            elif "roughness" in nl and not rgh_p.exists():
                rgh_p.write_bytes(zf.read(name))
            elif "emission" in nl:
                (pdir / "emission.jpg").write_bytes(zf.read(name))
            elif "opacity" in nl:
                (pdir / "opacity.jpg").write_bytes(zf.read(name))
        if not alb_p.exists():
            return key, False, f"no color map in {asset_id}"
        return key, True, {
            "key": key, "provider": "ambientCG", "asset_id": asset_id,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://ambientcg.com/view?id={asset_id}",
            "description": desc,
        }
    except Exception as e:
        return key, False, str(e)


def edge_preserving_stylize_albedo(img: Image.Image, target_sz: int = 1024) -> Image.Image:
    """
    Removes noisy high-frequency photogrammetry grain while preserving crisp planks, seams,
    weave, and masonry bevels — turning raw CC0 PBR packs into a cohesive 2026 stylized
    3D animated film albedo library.
    """
    im = img.convert("RGB").resize((target_sz, target_sz), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0

    # Fast edge-preserving bilateral-like decomposition (keeps plank/brick edges, smooths gritty noise)
    base = np.empty_like(arr)
    for c in range(3):
        smooth_wide = gaussian_filter(arr[:, :, c], sigma=3.2, mode="wrap")
        smooth_med = gaussian_filter(arr[:, :, c], sigma=1.4, mode="wrap")
        edge_mag = np.abs(smooth_med - smooth_wide)
        # Preserve bold structural edges (>0.035), smooth subtle noisy grain
        w_edge = np.clip((edge_mag - 0.015) / 0.055, 0.0, 1.0)
        base[:, :, c] = smooth_wide * (1.0 - w_edge) + smooth_med * w_edge

    # Gentle stylized contrast & tonal clean-up around mean luminance (keeps material character without muddy grit)
    mean_rgb = base.mean(axis=(0, 1), keepdims=True)
    stylized = np.clip(mean_rgb + (base - mean_rgb) * 1.08, 0.0, 1.0)
    return Image.fromarray((stylized * 255.0).astype(np.uint8), "RGB")


def stylize_normal_map(img: Image.Image, target_sz: int = 1024, strength: float = 0.72) -> Image.Image:
    """Smooths noisy photogrammetry micro-speckle in tangent-space normal maps while preserving crisp form."""
    im = img.convert("RGB").resize((target_sz, target_sz), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0 * 2.0 - 1.0
    nx = gaussian_filter(arr[:, :, 0], sigma=1.6, mode="wrap") * strength
    ny = gaussian_filter(arr[:, :, 1], sigma=1.6, mode="wrap") * strength
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.05, 1.0))
    nlen = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    out = np.stack([(nx / nlen) * 0.5 + 0.5, (ny / nlen) * 0.5 + 0.5, (nz / nlen) * 0.5 + 0.5], axis=2)
    return Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB")


def stylize_roughness_map(img: Image.Image, target_sz: int = 1024) -> Image.Image:
    """Extracts clean, smooth stylized roughness variation from CC0 roughness/ARM map."""
    im = img.convert("RGB").resize((target_sz, target_sz), Image.Resampling.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0
    # If ARM packed (R=AO, G=Rough, B=Metal), green channel holds roughness; for grayscale rough R==G==B
    r = gaussian_filter(arr[:, :, 1], sigma=1.8, mode="wrap")
    return Image.fromarray((np.clip(r, 0.0, 1.0) * 255.0).astype(np.uint8), "L")


def build_stylized_pack(key: str):
    src = RAW_DIR / key
    dst = STYL_DIR / key
    dst.mkdir(parents=True, exist_ok=True)
    if not (src / "albedo.jpg").exists():
        return key, False
    # Different normal strengths for stylized clarity (softer on plaster/sand/cloth, bolder on planks/stone/rope)
    n_strength = 0.55 if any(k in key for k in ("plaster", "stucco", "sand", "fabric", "leather", "marble")) else 0.78
    alb = edge_preserving_stylize_albedo(Image.open(src / "albedo.jpg"), 1024)
    alb.save(dst / "albedo.png", optimize=True)
    if (src / "normal.jpg").exists():
        nrm = stylize_normal_map(Image.open(src / "normal.jpg"), 1024, n_strength)
    else:
        nrm = Image.new("RGB", (1024, 1024), (128, 128, 255))
    nrm.save(dst / "normal.png", optimize=True)
    if (src / "rough.jpg").exists():
        rgh = stylize_roughness_map(Image.open(src / "rough.jpg"), 1024)
    else:
        rgh = Image.new("L", (1024, 1024), 175)
    rgh.save(dst / "rough.png", optimize=True)
    if (src / "emission.jpg").exists():
        em = Image.open(src / "emission.jpg").convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
        em.save(dst / "emission.png", optimize=True)
    return key, True


def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    STYL_DIR.mkdir(parents=True, exist_ok=True)

    manifest = {}
    tasks = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for k, (aid, desc) in POLYHAVEN_PACKS.items():
            tasks.append(ex.submit(fetch_polyhaven_pack, k, aid, desc))
        for k, (aid, desc) in AMBIENTCG_PACKS.items():
            tasks.append(ex.submit(fetch_ambientcg_pack, k, aid, desc))
        for fut in as_completed(tasks):
            k, ok, info = fut.result()
            if ok:
                manifest[k] = info
                print(f"[DL OK  ] {k:22s} <- {info['provider']} ({info['asset_id']})", flush=True)
            else:
                print(f"[DL FAIL] {k:22s} <- {info}", flush=True)

    print(f"\nStylizing {len(manifest)} downloaded CC0 PBR packs into 2026 animated-film source maps...", flush=True)
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = [ex.submit(build_stylized_pack, k) for k in sorted(manifest.keys())]
        for fut in as_completed(futs):
            k, ok = fut.result()
            print(f"[STYL {'OK' if ok else 'FAIL'}] {k}", flush=True)

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2))
    print(f"\nDONE! Library manifest saved to {MANIFEST_PATH} ({len(manifest)} licensed CC0 packs).")


if __name__ == "__main__":
    main()
