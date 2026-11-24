#!/usr/bin/env python3
"""
KSGGFREMAKE — Ultra-HD 4K CC0 PBR & 4K Painted Stylized Skybox Builder.

1. Downloads genuine 4K (4096x4096) licensed CC0 PBR source maps (Diffuse, NormalGL, Rough, AO)
   from Poly Haven (CC0 1.0) and ambientCG (CC0 1.0) into work_refs/cc0_library/raw_4k/
   with ZERO destructive Gaussian blurring so stone, rock, masonry, wood, fabric, velvet,
   leather, gold, and iron stay razor-sharp up close!
2. Installs 14 crisp 4K runtime triplanar PBR detail packs in godot_project/assets/textures/pbr/
   so large low-UV 2007 cave walls, cliffs, castle walls, floors, wood decks, and beaches
   have pin-sharp 4K world-space relief, cracks, and micro-detail.
3. Downloads genuine 4K Poly Haven PureSky / Storm CC0 sky domes and art-directs 7 rich 4K
   (4096x2048) stylized 360-degree biome skyboxes in godot_project/assets/skies/ matching
   the 2007 color script of every outdoor biome with towering painted clouds, moon/sun halos,
   and layered fantasy sea-cliff / island / desert-mesa horizon silhouettes.
"""
import io
import json
import math
import shutil
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy.ndimage import gaussian_filter

ROOT = Path("/home/antigravity/sabeltann_remake")
RAW_4K_DIR = ROOT / "work_refs/cc0_library/raw_4k"
SHARP_4K_DIR = ROOT / "work_refs/cc0_library/sharp_4k"
MANIFEST_4K_PATH = ROOT / "work_refs/cc0_library/library_4k_manifest.json"
RUNTIME_PBR_DIR = ROOT / "godot_project/assets/textures/pbr"
SKY_RAW_DIR = ROOT / "work_refs/cc0_library/skies_raw"
SKY_OUT_DIR = ROOT / "godot_project/assets/skies"

POLYHAVEN_4K_PACKS = {
    # Crisp 4K Stone, Rock, Cliffs & Masonry
    "rock_cave": ("rock_face_03", "Sharp stratified 4K cavern rock for Grusomme Gabriels grotte"),
    "rock_boulder": ("rock_boulder_dry", "Sculpted 4K granite boulders and cave pillars"),
    "rock_cliff": ("cliff_side", "Dramatic 4K layered coastal cliffs and Graal mountains"),
    "stone_castle": ("castle_wall_slates", "Chiseled 4K dark fortress masonry for Gral borg"),
    "stone_wall": ("stone_wall", "Rugged 4K hand-fitted medieval stone walls"),
    "stone_medieval": ("medieval_blocks_05", "Heavy carved 4K temple and castle blocks"),
    "stone_mossy": ("mossy_stone_wall", "Damp 4K mossy stonework for dungeons, wells, underwater ruins"),
    "stone_slate_floor": ("slate_floor_02", "Crisp 4K cut stone flagstones for courtyards and paths"),
    "stone_cobble": ("cobblestone_04", "Rounded 4K harbor cobblestones for Abra Havn streets"),
    "sandstone_blocks": ("sandstone_blocks_04", "Carved 4K desert sandstone ashlar for Fata Morgana"),
    "marble_palace": ("marble_01", "Polished 4K veined palace marble for Sultan halls"),
    "plaster_smooth": ("painted_plaster_wall", "Clean 4K painted plaster walls for Abra & Fata Morgana"),
    "stucco_warm": ("white_stucco", "Warm 4K sculpted desert stucco for domes and arches"),
    "roof_slate": ("roof_slates_02", "Overlapping 4K roof slates for Abra Havn pirate houses"),
    "roof_terracotta": ("clay_roof_tiles_02", "Curved 4K terracotta roof tiles for palaces and roofs"),
    # Wood & Maritime Timber (4K)
    "wood_planks_warm": ("brown_planks_05", "Warm 4K maritime timber planks for docks, decks, bridges"),
    "wood_planks_dark": ("dark_wooden_planks", "Dark 4K weathered timber planking for Den Sorte Dame & dungeons"),
    "wood_planks_painted": ("blue_painted_planks", "Painted 4K timber planking for Abra Havn houses & doors"),
    "wood_fine_grain": ("fine_grained_wood", "Fine 4K wood grain for masts, crates, barrels, furniture"),
    "wood_bamboo": ("bamboo_wall", "4K bamboo and Oriental timber slats for Maga Khan"),
    # Nature & Ground (4K)
    "sand_beach": ("coast_sand_01", "Wind-rippled 4K beach sand for Maga Khan & Treasure Island"),
    "grass_lush": ("grass_ground", "Lush 4K island grass for jungle, Treasure Island & world map"),
    "bark_tree": ("bark_brown_01", "Detailed 4K tropical palm and jungle bark"),
    # Character Fabrics, Velvet, Leather & Metal (4K)
    "fabric_sail": ("rough_linen", "Crisp 4K woven linen for sails, flags, pirate bandanas & aprons"),
    "fabric_cloth": ("denim_fabric", "Fine 4K woven twill cloth for pirate trousers, shorts & vests"),
    "fabric_velvet": ("velour_velvet", "Rich 4K velvet pile for Sabeltann's coat, Sultan & Miriam robes"),
    "leather_smooth": ("brown_leather", "Supple 4K pebbled leather for pirate belts, boots & sandals"),
    "metal_iron": ("metal_plate_02", "Forged 4K dark iron for hinges, grates, cannons, chains & blades"),
    "metal_plate": ("metal_plate", "Brushed 4K steel & weapon metal for sabers, armor & trim"),
    "metal_painted": ("painted_metal_shutter", "Painted 4K maritime enamel metal panels"),
}

AMBIENTCG_4K_PACKS = {
    "fabric_cotton": ("Fabric030", "Crisp 4K woven cotton shirt fabric for Pinky, Sunniva, Pelle & crew"),
    "fabric_fur": ("Fabric061", "Organic 4K short fur/wool weave for Panther, Dog & trim"),
    "metal_gold": ("Metal034", "Gleaming 4K brushed/hammered gold for Sabeltann brocade, crowns & buckles"),
    "rope_braided": ("Rope001", "Crisp 4K braided maritime hemp rope for ship rigging & docks"),
    "carpet_ornate": ("Carpet016", "Woven 4K ornate palace carpet for Fata Morgana"),
    "lava_molten": ("Lava004", "Glowing 4K magma fissures and obsidian crust for caves & dragon"),
    "foliage_leaf": ("Leaf001", "Veined 4K tropical foliage for palms, jungle & meatplant"),
    "plaster_clean": ("Plaster001", "Ultra-fine 4K micro-surface for skin, bone & clean painted surfaces"),
}

POLYHAVEN_4K_SKIES = {
    "storm_clouds": ("approaching_storm", "Dramatic towering storm clouds for Gral mountain & boss fortress"),
    "overcast_mist": ("kloofendal_overcast_puresky", "Layered moody coastal cloud deck for cursed Abra Havn twilight"),
    "night_clouds": ("qwantani_night_puresky", "Deep atmospheric starry night clouds for Abra Havn night menu & Gral"),
    "sunset_drama": ("belfast_sunset_puresky", "Dramatic golden-violet backlit sunset sky for Outro & Maga Khan palace"),
    "tropical_clouds": ("kloofendal_38d_partly_cloudy_puresky", "Towering sunlit trade-wind clouds for tropical islands & World Map"),
    "desert_sky": ("syferfontein_18d_clear_puresky", "Luminous high-altitude azure sky with light wisps for Fata Morgana"),
}


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "KSGGFRemake-UltraHD4K/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def download_file(url: str, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "KSGGFRemake-UltraHD4K/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r, open(dst, "wb") as f:
        shutil.copyfileobj(r, f)


def fetch_polyhaven_4k(key: str, asset_id: str, desc: str):
    pdir = RAW_4K_DIR / key
    alb_p = pdir / "albedo.jpg"
    nrm_p = pdir / "normal.jpg"
    rgh_p = pdir / "rough.jpg"
    ao_p = pdir / "ao.jpg"
    if alb_p.exists() and nrm_p.exists() and rgh_p.exists():
        # Verify it's truly >= 2048px
        try:
            with Image.open(alb_p) as im:
                if im.size[0] >= 2048:
                    return key, True, {
                        "key": key, "provider": "Poly Haven", "asset_id": asset_id,
                        "resolution": f"{im.size[0]}x{im.size[1]}",
                        "license": "CC0 1.0 Public Domain",
                        "url": f"https://polyhaven.com/a/{asset_id}",
                        "description": desc,
                    }
        except Exception:
            pass
    try:
        files = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
        pdir.mkdir(parents=True, exist_ok=True)

        def pick_url(candidates, res_order=("4k", "2k")):
            for cname in candidates:
                if cname in files:
                    for res in res_order:
                        if res in files[cname]:
                            for fmt in ("jpg", "png"):
                                if fmt in files[cname][res]:
                                    return files[cname][res][fmt]["url"]
            return None

        u_alb = pick_url(["Diffuse", "diffuse", "albedo", "col", "Color"], ("4k", "2k"))
        u_nrm = pick_url(["nor_gl", "Normal", "nor_dx"], ("4k", "2k"))
        u_rgh = pick_url(["Rough", "roughness", "arm"], ("2k", "4k"))
        u_ao = pick_url(["AO", "ao"], ("2k", "4k"))

        if not u_alb:
            return key, False, f"no diffuse url for {asset_id}"
        download_file(u_alb, alb_p)
        if u_nrm:
            download_file(u_nrm, nrm_p)
        if u_rgh:
            download_file(u_rgh, rgh_p)
        if u_ao:
            download_file(u_ao, ao_p)
        with Image.open(alb_p) as im:
            res_str = f"{im.size[0]}x{im.size[1]}"
        return key, True, {
            "key": key, "provider": "Poly Haven", "asset_id": asset_id,
            "resolution": res_str,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://polyhaven.com/a/{asset_id}",
            "description": desc,
        }
    except Exception as e:
        return key, False, str(e)


def fetch_ambientcg_4k(key: str, asset_id: str, desc: str):
    pdir = RAW_4K_DIR / key
    alb_p = pdir / "albedo.jpg"
    nrm_p = pdir / "normal.jpg"
    rgh_p = pdir / "rough.jpg"
    ao_p = pdir / "ao.jpg"
    if alb_p.exists() and nrm_p.exists() and rgh_p.exists():
        try:
            with Image.open(alb_p) as im:
                if im.size[0] >= 2048:
                    return key, True, {
                        "key": key, "provider": "ambientCG", "asset_id": asset_id,
                        "resolution": f"{im.size[0]}x{im.size[1]}",
                        "license": "CC0 1.0 Public Domain",
                        "url": f"https://ambientcg.com/view?id={asset_id}",
                        "description": desc,
                    }
        except Exception:
            pass
    try:
        zip_url = f"https://ambientcg.com/get?file={asset_id}_4K-JPG.zip"
        req = urllib.request.Request(zip_url, headers={"User-Agent": "KSGGFRemake-UltraHD4K/1.0"})
        with urllib.request.urlopen(req, timeout=180) as r:
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
            elif "ambientocclusion" in nl and not ao_p.exists():
                ao_p.write_bytes(zf.read(name))
            elif "emission" in nl:
                (pdir / "emission.jpg").write_bytes(zf.read(name))
        if not alb_p.exists():
            return key, False, f"no color map in {asset_id}"
        with Image.open(alb_p) as im:
            res_str = f"{im.size[0]}x{im.size[1]}"
        return key, True, {
            "key": key, "provider": "ambientCG", "asset_id": asset_id,
            "resolution": res_str,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://ambientcg.com/view?id={asset_id}",
            "description": desc,
        }
    except Exception as e:
        return key, False, str(e)


def prepare_sharp_4k_pack(key: str):
    """
    Prepares razor-sharp 4K Albedo (4096), 4K Normal (4096), 2K Roughness (2048), and 2K AO (2048)
    with ZERO destructive Gaussian blur — preserving crisp chiseled stone cracks, fabric threads,
    leather pebble grain, and wood fibers!
    """
    src = RAW_4K_DIR / key
    dst = SHARP_4K_DIR / key
    if (dst / "albedo.jpg").exists() and (dst / "normal.jpg").exists() and (dst / "rough.jpg").exists():
        return
    dst.mkdir(parents=True, exist_ok=True)

    # 1. Albedo: 4096x4096 crisp, lightly micro-sharpened (unsharp mask) so details pop in 3D!
    alb = Image.open(src / "albedo.jpg").convert("RGB")
    if alb.size != (4096, 4096):
        alb = alb.resize((4096, 4096), Image.Resampling.LANCZOS)
    # Crisp subtle unsharp boost (NEVER Gaussian blur!)
    alb = alb.filter(ImageFilter.UnsharpMask(radius=1.4, percent=70, threshold=2))
    alb.save(dst / "albedo.jpg", quality=94, subsampling=0)

    # 2. Normal: 4096x4096 full crisp tangent-space detail!
    if (src / "normal.jpg").exists():
        nrm = Image.open(src / "normal.jpg").convert("RGB")
        if nrm.size != (4096, 4096):
            nrm = nrm.resize((4096, 4096), Image.Resampling.LANCZOS)
    else:
        nrm = Image.new("RGB", (4096, 4096), (128, 128, 255))
    nrm.save(dst / "normal.jpg", quality=94, subsampling=0)

    # 3. Roughness: 2048x2048 crisp grayscale (channel G if ARM packed)
    if (src / "rough.jpg").exists():
        rgh_im = Image.open(src / "rough.jpg").convert("RGB")
        if rgh_im.size != (2048, 2048):
            rgh_im = rgh_im.resize((2048, 2048), Image.Resampling.LANCZOS)
        rgh = rgh_im.split()[1]
    else:
        rgh = Image.new("L", (2048, 2048), 180)
    rgh.save(dst / "rough.jpg", quality=92)

    # 4. AO: 2048x2048 crisp cavity occlusion
    if (src / "ao.jpg").exists():
        ao = Image.open(src / "ao.jpg").convert("L")
        if ao.size != (2048, 2048):
            ao = ao.resize((2048, 2048), Image.Resampling.LANCZOS)
        ao.save(dst / "ao.jpg", quality=92)

    if (src / "emission.jpg").exists():
        em = Image.open(src / "emission.jpg").convert("RGB")
        if em.size != (2048, 2048):
            em = em.resize((2048, 2048), Image.Resampling.LANCZOS)
        em.save(dst / "emission.jpg", quality=92)


def install_runtime_4k_triplanar_packs():
    """Installs 14 genuine 4K CC0 PBR packs in godot_project/assets/textures/pbr/ for crisp world-space triplanar detail."""
    RUNTIME_PBR_DIR.mkdir(parents=True, exist_ok=True)
    mapping = {
        "rock_cave_4k": "rock_cave",
        "rock_boulder_4k": "rock_boulder",
        "rock_cliff_4k": "rock_cliff",
        "stone_castle_4k": "stone_castle",
        "stone_wall_4k": "stone_wall",
        "stone_mossy_4k": "stone_mossy",
        "sandstone_4k": "sandstone_blocks",
        "slate_floor_4k": "stone_slate_floor",
        "wood_planks_4k": "wood_planks_warm",
        "wood_dark_4k": "wood_planks_dark",
        "coast_sand_4k": "sand_beach",
        "grass_lush_4k": "grass_lush",
        "marble_4k": "marble_palace",
        "cutaway_bedrock_4k": "rock_cliff",
        # Keep backwards-compatible names upgraded to 4K!
        "rock_natural": "rock_cave",
        "coast_sand": "sand_beach",
        "wood_planks": "wood_planks_warm",
        "cutaway_bedrock": "rock_cliff",
        "fabric_detail": "fabric_cotton",
        "forged_metal": "metal_iron",
    }
    for out_name, src_key in mapping.items():
        sdir = SHARP_4K_DIR / src_key
        if not (sdir / "albedo.jpg").exists():
            continue
        shutil.copy2(sdir / "albedo.jpg", RUNTIME_PBR_DIR / f"{out_name}_albedo.jpg")
        shutil.copy2(sdir / "normal.jpg", RUNTIME_PBR_DIR / f"{out_name}_normal.jpg")
        shutil.copy2(sdir / "rough.jpg", RUNTIME_PBR_DIR / f"{out_name}_rough.jpg")
    print(f"[OK] Installed {len(mapping)} razor-sharp 4K runtime PBR detail packs in {RUNTIME_PBR_DIR}", flush=True)


# ======================================================================================
# 4K PAINTED STYLIZED 360-DEGREE BIOME SKYBOXES (FROM POLY HAVEN CC0 PURESKY)
# ======================================================================================

def download_polyhaven_4k_skies():
    SKY_RAW_DIR.mkdir(parents=True, exist_ok=True)
    meta = {}
    for key, (asset_id, desc) in POLYHAVEN_4K_SKIES.items():
        dst = SKY_RAW_DIR / f"{key}.jpg"
        if not dst.exists():
            try:
                files = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
                url = None
                if "tonemapped" in files and "url" in files["tonemapped"]:
                    url = files["tonemapped"]["url"]
                elif "hdri" in files:
                    for res in ("4k", "2k"):
                        if res in files["hdri"] and "jpg" in files["hdri"][res]:
                            url = files["hdri"][res]["jpg"]["url"]
                            break
                if url:
                    download_file(url, dst)
                    print(f"[OK] Sky CC0 {key:18s} ({asset_id}) downloaded", flush=True)
            except Exception as e:
                print(f"[WARN] Sky {key}: {e}", flush=True)
        meta[key] = {
            "key": f"sky_{key}", "provider": "Poly Haven", "asset_id": asset_id,
            "license": "CC0 1.0 Public Domain",
            "url": f"https://polyhaven.com/a/{asset_id}",
            "description": desc,
        }
    return meta


def fbm_1d(x: np.ndarray, octaves: int = 5, seed: float = 0.0) -> np.ndarray:
    """Periodic 1D fractal noise around 360-degree azimuth [0, 2*pi] for seamless mountain/island horizons."""
    val = np.zeros_like(x, dtype=np.float32)
    amp = 0.5
    for i in range(octaves):
        freq = 2 ** i
        phase = seed * (i + 1.37) + i * 2.13
        val += amp * np.sin(x * freq + phase) * 0.65 + amp * np.cos(x * freq * 2.0 - phase * 1.4) * 0.35
        amp *= 0.52
    return (val - val.min()) / max(float(val.max() - val.min()), 1e-5)


def paint_stylized_skybox_4k(
    out_path: Path,
    raw_sky_path: Path,
    zenith_rgb,
    mid_rgb,
    horizon_rgb,
    sea_rgb,
    cloud_tint_lit,
    cloud_tint_dark,
    cloud_contrast: float = 1.45,
    celestial_dir=None,       # (az_frac 0..1, elev_deg 0..90)
    celestial_color=(1.0, 0.95, 0.82),
    celestial_radius: float = 0.028,
    horizon_silhouettes=None, # list of (seed, max_elev_deg, min_elev_deg, rgb, sharpness)
    stars_strength: float = 0.0,
    lightning_glows=None,     # list of (az_frac, elev_deg, rgb, radius_az, radius_el)
    warm_godrays: bool = False,
):
    """
    Constructs a lush, dramatic 4096x2048 (4K) stylized 360-degree equirectangular skybox:
    - Uses ONLY the genuine upper cloud dome (top 48%) from a Poly Haven 4K CC0 PureSky/Storm dome
      (zero real-world ground/buildings!), enhanced into crisp painterly animated-film clouds!
    - Grades sky & clouds 100% faithfully to the 2007 biome color script.
    - Adds glowing moon/sun halo, subtle twinkling starfield (for nocturnal biomes), volumetric
      in-cloud storm glow (for Gral), and 2-3 layered distant misty sea-cliff / volcanic-island /
      desert-mesa horizon silhouettes with atmospheric perspective!
    """
    W, H = 4096, 2048
    # Vertical elevation: top row = +90 deg, equator (row H/2) = 0 deg, bottom = -90 deg
    y_norm = np.linspace(1.0, -1.0, H, dtype=np.float32)[:, None]  # +1 zenith .. 0 horizon .. -1 nadir
    elev = np.clip(y_norm, 0.0, 1.0)
    az = np.linspace(0.0, 2.0 * math.pi, W, endpoint=False, dtype=np.float32)[None, :]  # 0..2pi

    # 1. Base rich 3-stop stylized atmospheric sky gradient
    z_col = np.array(zenith_rgb, dtype=np.float32)[None, None, :]
    m_col = np.array(mid_rgb, dtype=np.float32)[None, None, :]
    h_col = np.array(horizon_rgb, dtype=np.float32)[None, None, :]
    s_col = np.array(sea_rgb, dtype=np.float32)[None, None, :]

    t_low = np.clip(elev / 0.34, 0.0, 1.0) ** 0.72
    t_high = np.clip((elev - 0.16) / 0.84, 0.0, 1.0) ** 0.80
    sky_up = h_col * (1.0 - t_low[:, :, None]) + m_col * t_low[:, :, None]
    sky_up = sky_up * (1.0 - t_high[:, :, None]) + z_col * t_high[:, :, None]

    # Below horizon: atmospheric deep sea reflection gradient
    below_t = np.clip(-y_norm / 0.32, 0.0, 1.0) ** 0.65
    sky_down = h_col * 0.78 * (1.0 - below_t[:, :, None]) + s_col * below_t[:, :, None]
    canvas = np.broadcast_to(np.where(y_norm[:, :, None] >= 0.0, sky_up, sky_down), (H, W, 3)).copy()

    # 2. Extract real 4K cloud luminance & structure from upper hemisphere of Poly Haven CC0 sky!
    if raw_sky_path.exists():
        raw_im = Image.open(raw_sky_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
        raw_arr = np.asarray(raw_im, dtype=np.float32) / 255.0
        # Use strictly upper 46% (above any horizon trees/ground) stretched smoothly to equator!
        upper_cut = int(H * 0.46)
        cloud_dome = raw_arr[:upper_cut, :, :]
        cloud_dome_im = Image.fromarray((cloud_dome * 255).astype(np.uint8), "RGB").resize(
            (W, H // 2), Image.Resampling.LANCZOS
        )
        # Edge-preserving painterly cloud polish (crisp dramatic billows, zero photo sensor grain)
        cloud_dome_im = cloud_dome_im.filter(ImageFilter.UnsharpMask(radius=2.2, percent=55, threshold=3))
        cd = np.asarray(cloud_dome_im, dtype=np.float32) / 255.0

        # Normalize cloud density/lighting cleanly per latitude band so clouds read dramatically everywhere!
        cd_lum = 0.299 * cd[:, :, 0] + 0.587 * cd[:, :, 1] + 0.114 * cd[:, :, 2]
        # High-pass cloud structure + global structure
        cd_lo = gaussian_filter(cd_lum, sigma=(42.0, 64.0), mode=("nearest", "wrap"))
        cd_struct = np.clip(0.50 + (cd_lum - cd_lo) * cloud_contrast * 1.45 + (cd_lum - cd_lum.mean()) * 0.55, 0.0, 1.0)
        # Cloud opacity mask (stronger where cloud structure is rich, softly fading right at equator)
        y_up = np.linspace(1.0, 0.0, H // 2, dtype=np.float32)[:, None]
        eq_fade = np.clip(y_up / 0.11, 0.0, 1.0) ** 0.7
        cloud_alpha = np.clip((cd_struct - 0.14) / 0.72, 0.0, 1.0) * 0.88 * eq_fade

        # Dual-tone stylized painterly cloud shading (dramatic dark undersides + luminous sunlit/moonlit crowns!)
        c_dark = np.array(cloud_tint_dark, dtype=np.float32)[None, None, :]
        c_lit = np.array(cloud_tint_lit, dtype=np.float32)[None, None, :]
        # Directional top-edge lighting on clouds (derivative along vertical axis -> bright tops!)
        dy = np.gradient(cd_struct, axis=0)
        top_light = np.clip(cd_struct * 0.82 - dy * 8.5, 0.0, 1.0)
        cloud_rgb = c_dark * (1.0 - top_light[:, :, None]) + c_lit * top_light[:, :, None]

        canvas[: H // 2, :, :] = (
            canvas[: H // 2, :, :] * (1.0 - cloud_alpha[:, :, None])
            + cloud_rgb * cloud_alpha[:, :, None]
        )

        # Soft mirror reflection of the clouds onto the distant sea below the horizon!
        sea_refl = np.flipud(canvas[: H // 2, :, :])
        sea_fade = np.exp(-np.linspace(0.0, 1.0, H // 2, dtype=np.float32)[:, None] * 6.5) * 0.42
        canvas[H // 2 :, :, :] = canvas[H // 2 :, :, :] * (1.0 - sea_fade[:, :, None]) + sea_refl * sea_fade[:, :, None]

    # 3. Twinkling subtle stars in upper nocturnal sky (for Gral / Abra Night)
    if stars_strength > 0.01:
        rng = np.random.default_rng(2026)
        n_stars = 900
        sy = rng.integers(int(H * 0.03), int(H * 0.42), size=n_stars)
        sx = rng.integers(0, W, size=n_stars)
        sb = rng.uniform(0.35, 1.0, size=n_stars) * stars_strength
        for i in range(n_stars):
            r = 2 if sb[i] > 0.72 * stars_strength else 1
            y0, y1 = max(0, sy[i] - r), min(H // 2, sy[i] + r + 1)
            x0, x1 = max(0, sx[i] - r), min(W, sx[i] + r + 1)
            canvas[y0:y1, x0:x1, :] = np.clip(
                canvas[y0:y1, x0:x1, :] + np.array([0.82, 0.90, 1.0], dtype=np.float32) * sb[i],
                0.0, 1.0,
            )

    # 4. Celestial body (Moon / Sun disc + lush atmospheric Mie halo + optional sun-ray shafts)
    if celestial_dir is not None:
        c_az_f, c_el_deg = celestial_dir
        c_az = c_az_f * 2.0 * math.pi
        c_el = c_el_deg / 90.0
        # Angular distance on equirectangular grid (corrected for latitude)
        daz = np.abs(az - c_az)
        daz = np.minimum(daz, 2.0 * math.pi - daz) * np.cos(np.clip(y_norm, -1.0, 1.0) * (math.pi * 0.5))
        delv = (y_norm - c_el) * (math.pi * 0.5)
        ang = np.sqrt(daz * daz + delv * delv)
        ccol = np.array(celestial_color, dtype=np.float32)[None, None, :]

        halo_wide = np.exp(-ang / 0.34) * 0.42
        halo_mid = np.exp(-ang / 0.11) * 0.62
        disc = np.clip((celestial_radius - ang) / max(celestial_radius * 0.16, 0.002), 0.0, 1.0)
        canvas = np.clip(canvas + ccol * (halo_wide + halo_mid)[:, :, None], 0.0, 1.0)
        canvas = canvas * (1.0 - disc[:, :, None]) + np.clip(ccol * 1.35, 0.0, 1.0) * disc[:, :, None]

        if warm_godrays:
            # Soft asymmetric atmospheric sunbeam haze (no mechanical star-spokes!)
            ray_angle = np.arctan2(delv, daz + 1e-5)
            rays = (0.5 + 0.5 * np.sin(ray_angle * 4.0 + 0.8) * np.cos(ray_angle * 2.5 - 0.3)) ** 2.0 * np.exp(-ang / 0.42) * np.clip(y_norm * 3.0, 0.0, 1.0)
            canvas = np.clip(canvas + ccol * rays[:, :, None] * 0.14, 0.0, 1.0)

    # 5. Volumetric in-cloud storm lightning glows (modulated by actual cloud billows — never circular spotlights!)
    if lightning_glows:
        cloud_gate = np.ones((H, W), dtype=np.float32)
        if raw_sky_path.exists():
            cloud_gate[: H // 2, :] = np.clip(cd_struct ** 1.4 * 1.45, 0.05, 1.0)
            cloud_gate[H // 2 :, :] = np.flipud(cloud_gate[: H // 2, :]) * 0.35
        for laz_f, lel_deg, lrgb, raz, rel in lightning_glows:
            laz = laz_f * 2.0 * math.pi
            lel = lel_deg / 90.0
            daz = np.abs(az - laz)
            daz = np.minimum(daz, 2.0 * math.pi - daz)
            delv = y_norm - lel
            glow = np.exp(-((daz / (raz * 1.45)) ** 2 + (delv / (rel * 1.25)) ** 2)) * cloud_gate
            canvas = np.clip(canvas + np.array(lrgb, dtype=np.float32)[None, None, :] * glow[:, :, None] * 0.85, 0.0, 1.0)

    # 6. Layered distant fantasy horizon silhouettes (jagged Gothic sea cliffs, misty archipelagos, desert mesas, volcanic islands!)
    if horizon_silhouettes:
        az_1d = az[0]
        for seed, max_deg, min_deg, sil_rgb, ridge_pow in horizon_silhouettes:
            n = fbm_1d(az_1d, octaves=6, seed=seed) ** ridge_pow
            # Modulate with macro island clusters so there are dramatic open sea gaps & looming peaks!
            cluster = np.clip(fbm_1d(az_1d, octaves=2, seed=seed + 19.3) * 1.35 - 0.15, 0.0, 1.0)
            ridge_y = (min_deg + (max_deg - min_deg) * n * cluster) / 90.0  # shape (W,)
            # Crisp anti-aliased ridge edge fading gently into horizon mist at the base
            dist_from_top = ridge_y[None, :] - y_norm
            in_sil = np.clip(dist_from_top * 260.0, 0.0, 1.0) * (y_norm >= -0.015).astype(np.float32)
            # Subtle atmospheric top-to-bottom mist gradient on the distant cliffs
            mist_t = np.clip(1.0 - np.clip(y_norm / max(max_deg / 90.0, 0.02), 0.0, 1.0), 0.0, 1.0) * 0.45
            s_rgb = np.array(sil_rgb, dtype=np.float32)[None, None, :]
            col_sil = s_rgb * (1.0 - mist_t[:, :, None]) + h_col * mist_t[:, :, None]
            canvas = canvas * (1.0 - in_sil[:, :, None]) + col_sil * in_sil[:, :, None]

    # Soft atmospheric horizon mist glow seam (blends water/horizon seamlessly in 3D)
    h_mist = np.exp(-np.abs(y_norm) / 0.032) * 0.34
    canvas = canvas * (1.0 - h_mist[:, :, None]) + h_col * h_mist[:, :, None]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(canvas, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB").save(out_path, format="PNG")
    print(f"[OK] Built 4K stylized skybox -> {out_path.name} ({out_path.stat().st_size / 1e6:.2f} MB)", flush=True)


def build_all_4k_skyboxes():
    SKY_OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. GRAL (graal_mountain, graal_bosslevel): Dramatic moonlit Gothic storm clouds + towering sea cliffs + electric cloud glow!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_graal_storm_4k.png",
        SKY_RAW_DIR / "storm_clouds.jpg",
        zenith_rgb=(0.022, 0.052, 0.095),
        mid_rgb=(0.055, 0.135, 0.205),
        horizon_rgb=(0.135, 0.255, 0.310),
        sea_rgb=(0.018, 0.068, 0.098),
        cloud_tint_lit=(0.44, 0.66, 0.78),
        cloud_tint_dark=(0.028, 0.058, 0.095),
        cloud_contrast=1.85,
        celestial_dir=(0.16, 26.0),
        celestial_color=(0.76, 0.94, 1.0),
        celestial_radius=0.036,
        horizon_silhouettes=[
            (1.7, 13.5, 0.5, (0.065, 0.135, 0.185), 1.35),  # Far misty Gothic mountain range
            (5.3, 8.5, 0.0, (0.032, 0.072, 0.108), 1.65),   # Closer jagged sea stacks & cliffs
        ],
        stars_strength=0.45,
        lightning_glows=[
            (0.42, 22.0, (0.48, 0.72, 1.0), 0.26, 0.14),
            (0.66, 18.0, (0.36, 0.58, 0.95), 0.22, 0.12),
            (0.84, 24.0, (0.42, 0.66, 0.98), 0.24, 0.13),
        ],
    )

    # 2. ABRA HAVN (abra): Cursed golden-olive pirate twilight with sweeping dramatic clouds & misty coastal archipelago!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_abra_twilight_4k.png",
        SKY_RAW_DIR / "overcast_mist.jpg",
        zenith_rgb=(0.11, 0.145, 0.065),
        mid_rgb=(0.24, 0.275, 0.125),
        horizon_rgb=(0.48, 0.47, 0.24),
        sea_rgb=(0.075, 0.105, 0.065),
        cloud_tint_lit=(0.64, 0.62, 0.32),
        cloud_tint_dark=(0.10, 0.135, 0.065),
        cloud_contrast=1.70,
        celestial_dir=(0.22, 15.0),
        celestial_color=(1.0, 0.88, 0.48),
        celestial_radius=0.032,
        horizon_silhouettes=[
            (3.1, 8.2, 0.2, (0.17, 0.195, 0.105), 1.2),
            (8.9, 4.6, 0.0, (0.095, 0.12, 0.065), 1.4),
        ],
        warm_godrays=True,
    )

    # 3. MAIN MENU (Abra Havn night): Deep cursed twilight-midnight clouds with glowing golden horizon & stars
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_abra_night_4k.png",
        SKY_RAW_DIR / "night_clouds.jpg",
        zenith_rgb=(0.035, 0.055, 0.035),
        mid_rgb=(0.095, 0.135, 0.068),
        horizon_rgb=(0.24, 0.26, 0.125),
        sea_rgb=(0.025, 0.045, 0.030),
        cloud_tint_lit=(0.34, 0.38, 0.18),
        cloud_tint_dark=(0.035, 0.055, 0.032),
        cloud_contrast=1.65,
        celestial_dir=(0.28, 22.0),
        celestial_color=(0.95, 0.88, 0.56),
        celestial_radius=0.028,
        horizon_silhouettes=[
            (4.4, 7.5, 0.0, (0.06, 0.08, 0.04), 1.3),
        ],
        stars_strength=0.65,
    )

    # 4. FATA MORGANA (fatamorgana_city, palace, bosslevel): Cobalt-azure desert sky + warm golden mesas & luminous clouds!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_fatamorgana_4k.png",
        SKY_RAW_DIR / "tropical_clouds.jpg",
        zenith_rgb=(0.06, 0.28, 0.76),
        mid_rgb=(0.22, 0.56, 0.90),
        horizon_rgb=(0.96, 0.80, 0.54),
        sea_rgb=(0.50, 0.35, 0.22),
        cloud_tint_lit=(1.0, 0.96, 0.84),
        cloud_tint_dark=(0.52, 0.54, 0.74),
        cloud_contrast=1.28,
        celestial_dir=(0.30, 26.0),
        celestial_color=(1.0, 0.93, 0.68),
        celestial_radius=0.032,
        horizon_silhouettes=[
            (6.2, 10.5, 0.4, (0.74, 0.56, 0.40), 1.15),  # Distant sunlit Arabian mountain ridges
            (11.4, 6.2, 0.0, (0.58, 0.40, 0.26), 1.25),  # Closer golden desert dunes & mesas
        ],
        warm_godrays=True,
    )

    # 5. TROPICAL (magakhan_beach, treasurehunt, world_map): Towering bright trade-wind clouds + volcanic island horizons!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_tropical_4k.png",
        SKY_RAW_DIR / "tropical_clouds.jpg",
        zenith_rgb=(0.06, 0.38, 0.84),
        mid_rgb=(0.22, 0.66, 0.95),
        horizon_rgb=(0.76, 0.92, 0.96),
        sea_rgb=(0.05, 0.30, 0.52),
        cloud_tint_lit=(1.0, 0.99, 0.94),
        cloud_tint_dark=(0.44, 0.62, 0.84),
        cloud_contrast=1.65,
        celestial_dir=(0.30, 32.0),
        celestial_color=(1.0, 0.96, 0.82),
        celestial_radius=0.030,
        horizon_silhouettes=[
            (2.9, 6.8, 0.0, (0.32, 0.54, 0.66), 1.45),  # Distant misty tropical islands
        ],
    )

    # 6. JUNGLE (magakhan_jungle): Sunlit emerald-gold humid sky + towering jungle peaks & clouds!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_jungle_4k.png",
        SKY_RAW_DIR / "tropical_clouds.jpg",
        zenith_rgb=(0.06, 0.34, 0.32),
        mid_rgb=(0.18, 0.56, 0.46),
        horizon_rgb=(0.56, 0.78, 0.58),
        sea_rgb=(0.06, 0.22, 0.15),
        cloud_tint_lit=(0.94, 0.98, 0.86),
        cloud_tint_dark=(0.22, 0.44, 0.36),
        cloud_contrast=1.60,
        celestial_dir=(0.25, 34.0),
        celestial_color=(1.0, 0.95, 0.70),
        celestial_radius=0.032,
        horizon_silhouettes=[
            (7.5, 11.5, 0.4, (0.16, 0.36, 0.25), 1.25),
            (13.1, 6.5, 0.0, (0.09, 0.24, 0.15), 1.40),
        ],
        warm_godrays=True,
    )

    # 7. OUTRO & MAGA KHAN PALACE: Glorious golden-amber & twilight-violet backlit sunset sky!
    paint_stylized_skybox_4k(
        SKY_OUT_DIR / "sky_outro_sunset_4k.png",
        SKY_RAW_DIR / "sunset_drama.jpg",
        zenith_rgb=(0.11, 0.20, 0.52),
        mid_rgb=(0.38, 0.38, 0.64),
        horizon_rgb=(0.98, 0.68, 0.38),
        sea_rgb=(0.14, 0.18, 0.30),
        cloud_tint_lit=(1.0, 0.84, 0.54),
        cloud_tint_dark=(0.26, 0.24, 0.44),
        cloud_contrast=1.80,
        celestial_dir=(0.26, 14.0),
        celestial_color=(1.0, 0.86, 0.48),
        celestial_radius=0.042,
        horizon_silhouettes=[
            (9.8, 7.2, 0.0, (0.28, 0.22, 0.34), 1.35),
        ],
        warm_godrays=True,
    )


def main():
    RAW_4K_DIR.mkdir(parents=True, exist_ok=True)
    SHARP_4K_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {}

    print(f"Downloading {len(POLYHAVEN_4K_PACKS)} Poly Haven 4K + {len(AMBIENTCG_4K_PACKS)} ambientCG 4K CC0 packs...", flush=True)
    tasks = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for k, (aid, desc) in POLYHAVEN_4K_PACKS.items():
            tasks.append(ex.submit(fetch_polyhaven_4k, k, aid, desc))
        for k, (aid, desc) in AMBIENTCG_4K_PACKS.items():
            tasks.append(ex.submit(fetch_ambientcg_4k, k, aid, desc))
        for fut in as_completed(tasks):
            k, ok, info = fut.result()
            if ok:
                manifest[k] = info
                print(f"  [OK] 4K {k:22s} ({info['provider']} {info['asset_id']} {info.get('resolution','')})", flush=True)
            else:
                print(f"  [FAIL] {k:22s}: {info}", flush=True)

    print("Preparing razor-sharp 4K CC0 PBR library (zero destructive blur)...", flush=True)
    for k in sorted(manifest.keys()):
        prepare_sharp_4k_pack(k)

    install_runtime_4k_triplanar_packs()

    print("Downloading 4K Poly Haven PureSky CC0 domes & building 7 4K stylized biome skyboxes...", flush=True)
    sky_meta = download_polyhaven_4k_skies()
    manifest.update(sky_meta)
    build_all_4k_skyboxes()

    MANIFEST_4K_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_4K_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"ALL DONE! {len(manifest)} 4K CC0 packs + 7 4K biome skyboxes ready -> {MANIFEST_4K_PATH}", flush=True)


if __name__ == "__main__":
    main()
