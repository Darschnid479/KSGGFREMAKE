#!/usr/bin/env python3
"""
Generates photorealistic, high-frequency, seamless 512x512 modern AAA PBR texture sets
using true anisotropic stretched multi-octave fractal grain (real wood splinters, real
mineral limestone pitting, real desert sandstone grit, real slate strata — zero cartoon
zebra waves or geometric Voronoi webs!).
"""
from pathlib import Path
import numpy as np
from PIL import Image

OUT_DIR = Path("/home/antigravity/sabeltann_remake/godot_project/assets/textures/pbr")
OUT_DIR.mkdir(parents=True, exist_ok=True)
SIZE = 512


def periodic_noise_2d(res: int, fx_freq: int, fy_freq: int, seed: int) -> np.ndarray:
    """Seamless periodic 2D value noise with independent X/Y frequencies (true anisotropic grain!)."""
    rng = np.random.default_rng(seed)
    grid = rng.random((fy_freq, fx_freq), dtype=np.float32)
    cx = np.linspace(0.0, fx_freq, res, endpoint=False, dtype=np.float32)
    cy = np.linspace(0.0, fy_freq, res, endpoint=False, dtype=np.float32)
    ix = np.floor(cx).astype(np.int32)
    iy = np.floor(cy).astype(np.int32)
    tx = cx - ix
    ty = cy - iy
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    ix0, ix1 = ix % fx_freq, (ix + 1) % fx_freq
    iy0, iy1 = iy % fy_freq, (iy + 1) % fy_freq

    v00 = grid[np.ix_(iy0, ix0)]
    v10 = grid[np.ix_(iy0, ix1)]
    v01 = grid[np.ix_(iy1, ix0)]
    v11 = grid[np.ix_(iy1, ix1)]
    top = v00 * (1.0 - tx[None, :]) + v10 * tx[None, :]
    bot = v01 * (1.0 - tx[None, :]) + v11 * tx[None, :]
    return top * (1.0 - ty[:, None]) + bot * ty[:, None]


def aniso_fbm(res: int, fx0: int, fy0: int, octaves: int, seed: int, persistence: float = 0.56) -> np.ndarray:
    out = np.zeros((res, res), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    fx, fy = fx0, fy0
    for o in range(octaves):
        out += amp * periodic_noise_2d(res, min(fx, res // 2), min(fy, res // 2), seed + o * 131)
        norm += amp
        amp *= persistence
        fx = min(fx * 2, res // 2)
        fy = min(fy * 2, res // 2)
    return out / max(norm, 1e-6)


def warp_sample(img: np.ndarray, dx: np.ndarray, dy: np.ndarray) -> np.ndarray:
    """Seamless bilinear domain-warp of a 2D array."""
    h, w = img.shape
    gx = (np.arange(w, dtype=np.float32)[None, :] + dx) % w
    gy = (np.arange(h, dtype=np.float32)[:, None] + dy) % h
    ix0 = np.floor(gx).astype(np.int32) % w
    iy0 = np.floor(gy).astype(np.int32) % h
    ix1 = (ix0 + 1) % w
    iy1 = (iy0 + 1) % h
    fx = gx - np.floor(gx)
    fy = gy - np.floor(gy)
    top = img[iy0, ix0] * (1.0 - fx) + img[iy0, ix1] * fx
    bot = img[iy1, ix0] * (1.0 - fx) + img[iy1, ix1] * fx
    return top * (1.0 - fy) + bot * fy


def height_to_normal(h: np.ndarray, strength: float = 6.0) -> np.ndarray:
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    rgb = np.stack([nx * inv_len * 0.5 + 0.5, ny * inv_len * 0.5 + 0.5, nz * inv_len * 0.5 + 0.5], axis=-1)
    return np.clip(rgb * 255.0, 0, 255).astype(np.uint8)


def save_pbr(name: str, alb: np.ndarray, height: np.ndarray, rough: np.ndarray, normal_strength: float = 6.0):
    Image.fromarray(np.clip(alb * 255.0, 0, 255).astype(np.uint8), "RGB").save(OUT_DIR / f"{name}_albedo.png")
    Image.fromarray(height_to_normal(height, strength=normal_strength), "RGB").save(OUT_DIR / f"{name}_normal.png")
    Image.fromarray(np.clip(rough * 255.0, 0, 255).astype(np.uint8), "L").save(OUT_DIR / f"{name}_rough.png")
    print(f"[OK] {name}", flush=True)


def make_wood_planks():
    """Realistic fine weathered oak planks with crisp anisotropic timber fibers (NO zebra stripes!)."""
    n = SIZE
    y = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[:, None]
    x = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[None, :]

    # Fine elongated longitudinal wood splinters & micro-pores (fx << fy!)
    fibers = aniso_fbm(n, 4, 48, 5, 11, persistence=0.60)
    micro_pores = aniso_fbm(n, 16, 128, 3, 19, persistence=0.58)
    # Subtle natural grain bend via gentle low-freq warp
    wx = (aniso_fbm(n, 4, 8, 3, 27) - 0.5) * 10.0
    wy = (aniso_fbm(n, 3, 6, 3, 31) - 0.5) * 6.0
    wood_grain = warp_sample(fibers * 0.65 + micro_pores * 0.35, wx, wy)

    # Fine dark weathered plank seams (8 narrow oak deck boards)
    num_planks = 8
    p_idx = np.floor(y * num_planks).astype(np.int32)
    pv = (y * num_planks) % 1.0
    rng = np.random.default_rng(109)
    p_tint = (0.80 + 0.36 * rng.random(num_planks)).astype(np.float32)[p_idx]
    p_shift = rng.random(num_planks).astype(np.float32)[p_idx]
    # Shift grain per plank so seams look genuinely cut from separate boards!
    wood_shifted = np.zeros_like(wood_grain)
    for pi in range(num_planks):
        r0 = pi * (n // num_planks)
        r1 = (pi + 1) * (n // num_planks)
        wood_shifted[r0:r1] = np.roll(wood_grain[r0:r1], int(rng.integers(0, n)), axis=1)

    xu = (x * 2.0 + p_shift) % 1.0
    seam_h = np.clip(np.minimum(pv, 1.0 - pv) / 0.026, 0.0, 1.0)
    seam_v = np.clip(np.minimum(xu, 1.0 - xu) / 0.010, 0.0, 1.0)
    groove = np.minimum(seam_h, seam_v)

    # Crisp dark micro-crevices + warm rich aged oak tone
    weather = aniso_fbm(n, 6, 12, 4, 45)
    h = groove * (0.48 + 0.36 * wood_shifted + 0.16 * micro_pores)
    val = p_tint * (0.58 + 0.58 * wood_shifted) * (0.84 + 0.32 * weather) * (0.22 + 0.78 * groove)

    alb = np.stack([
        np.clip(val * 0.64, 0.0, 1.0),
        np.clip(val * 0.45, 0.0, 1.0),
        np.clip(val * 0.28, 0.0, 1.0),
    ], axis=-1)
    rough = np.clip(0.50 + 0.34 * (1.0 - wood_shifted) + 0.20 * (1.0 - groove), 0.24, 0.94)
    save_pbr("wood_planks", alb, h, rough, normal_strength=7.5)


def make_stone_masonry():
    """Photorealistic chiselled dark weathered granite/limestone with deep fine mineral grit (NO Voronoi webs!)."""
    n = SIZE
    y = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[:, None]
    x = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[None, :]

    # True multi-scale mineral granite rock surface
    macro = aniso_fbm(n, 6, 6, 4, 201)
    med = aniso_fbm(n, 16, 16, 4, 205)
    fine_grit = aniso_fbm(n, 64, 64, 3, 209, persistence=0.65)
    wx = (macro - 0.5) * 18.0
    wy = (aniso_fbm(n, 6, 6, 4, 211) - 0.5) * 18.0
    rock = warp_sample(med * 0.52 + fine_grit * 0.48, wx, wy)

    # Organic ridged hairline rock fractures (domain-warped ridge noise!)
    f1 = np.abs(warp_sample(aniso_fbm(n, 10, 10, 4, 220), wx * 1.4, wy * 1.4) - 0.5) * 2.0
    micro_crack = np.clip(f1 / 0.055, 0.0, 1.0)

    # Subtle weathered stone courses
    rows, cols = 6, 3
    w_m = (macro - 0.5) * 0.015
    yr = (y + w_m) * rows
    ri = np.floor(yr).astype(np.int32) % rows
    rv = yr % 1.0
    xr = (x + w_m + (ri % 2) * 0.166) * cols
    ci = np.floor(xr).astype(np.int32) % cols
    cu = xr % 1.0

    rng = np.random.default_rng(230)
    b_tone = (0.78 + 0.36 * rng.random((rows, cols))).astype(np.float32)[ri, ci]
    mh = np.clip(np.minimum(rv, 1.0 - rv) / 0.036, 0.0, 1.0)
    mv = np.clip(np.minimum(cu, 1.0 - cu) / 0.024, 0.0, 1.0)
    mortar = np.minimum(mh, mv)

    h = mortar * (0.40 + 0.42 * rock + 0.18 * fine_grit) * (0.78 + 0.22 * micro_crack)
    s = b_tone * (0.56 + 0.54 * rock) * (0.74 + 0.26 * micro_crack) * (0.28 + 0.72 * mortar)
    moss = np.clip((1.0 - mortar * 0.75) * (aniso_fbm(n, 8, 8, 4, 240) - 0.46) * 2.8, 0.0, 1.0)

    alb = np.stack([
        np.clip(s * 0.56 - moss * 0.10, 0.0, 1.0),
        np.clip(s * 0.57 + moss * 0.06, 0.0, 1.0),
        np.clip(s * 0.55 - moss * 0.12, 0.0, 1.0),
    ], axis=-1)
    rough = np.clip(0.58 + 0.32 * (1.0 - rock) + 0.14 * (1.0 - mortar), 0.30, 0.96)
    save_pbr("stone_masonry", alb, h, rough, normal_strength=9.0)


def make_sandstone_wall():
    """Realistic fine sunlit Arabian sandstone & weathered plaster (NO spiderwebs!)."""
    n = SIZE
    macro = aniso_fbm(n, 5, 10, 4, 301)
    sediment = aniso_fbm(n, 6, 36, 4, 305)
    grit = aniso_fbm(n, 64, 64, 3, 309, persistence=0.64)
    wx = (macro - 0.5) * 14.0
    wy = (aniso_fbm(n, 5, 5, 3, 311) - 0.5) * 10.0
    stone = warp_sample(sediment * 0.55 + grit * 0.45, wx, wy)

    # Subtle weathered plaster pits
    pits = np.clip((aniso_fbm(n, 12, 12, 4, 320) - 0.22) / 0.12, 0.0, 1.0)
    h = (0.45 + 0.35 * stone + 0.20 * grit) * (0.78 + 0.22 * pits)
    s = (0.64 + 0.46 * stone) * (0.80 + 0.20 * pits)
    alb = np.stack([
        np.clip(s * 0.80, 0.0, 1.0),
        np.clip(s * 0.62, 0.0, 1.0),
        np.clip(s * 0.38, 0.0, 1.0),
    ], axis=-1)
    rough = np.clip(0.64 + 0.28 * (1.0 - grit), 0.36, 0.96)
    save_pbr("sandstone_wall", alb, h, rough, normal_strength=7.2)


def make_roof_shingles():
    """Weathered overlapping slate roof tiles with crisp fine stone grain."""
    n = SIZE
    y = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[:, None]
    x = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[None, :]

    rows, cols = 10, 8
    ri = np.floor(y * rows).astype(np.int32) % rows
    rv = (y * rows) % 1.0
    xu = (x * cols + (ri % 2) * 0.5) % 1.0
    ci = np.floor((x * cols + (ri % 2) * 0.5) % cols).astype(np.int32)

    rng = np.random.default_rng(401)
    tv = (0.74 + 0.40 * rng.random((rows, cols))).astype(np.float32)[ri, ci]
    grit = aniso_fbm(n, 32, 32, 4, 405, persistence=0.62)
    ex = np.clip(np.minimum(xu, 1.0 - xu) / 0.045, 0.0, 1.0)
    ov = np.clip(rv / 0.10, 0.0, 1.0)

    h = (0.22 + 0.60 * (1.0 - rv)) * ex * ov + 0.18 * grit
    s = tv * (0.30 + 0.70 * ov) * (0.40 + 0.60 * ex) * (0.72 + 0.42 * grit)
    alb = np.stack([np.clip(s * 0.36, 0.0, 1.0), np.clip(s * 0.38, 0.0, 1.0), np.clip(s * 0.44, 0.0, 1.0)], axis=-1)
    rough = np.clip(0.50 + 0.34 * (1.0 - grit), 0.24, 0.92)
    save_pbr("roof_shingles", alb, h, rough, normal_strength=8.0)


def make_forged_metal():
    """Crisp brushed antique brass/gold/iron with fine hammered patina."""
    n = SIZE
    brush = aniso_fbm(n, 8, 96, 4, 501, persistence=0.62)
    patina = aniso_fbm(n, 10, 10, 4, 505)
    fine = aniso_fbm(n, 64, 64, 3, 509)
    h = 0.45 + 0.35 * brush + 0.20 * fine
    s = (0.68 + 0.36 * brush) * (0.76 + 0.36 * patina)
    alb = np.stack([np.clip(s * 0.80, 0.0, 1.0), np.clip(s * 0.62, 0.0, 1.0), np.clip(s * 0.26, 0.0, 1.0)], axis=-1)
    rough = np.clip(0.20 + 0.32 * (1.0 - patina) + 0.10 * (1.0 - brush), 0.14, 0.68)
    save_pbr("forged_metal", alb, h, rough, normal_strength=5.5)


def make_cutaway_bedrock():
    """Rich organic Ori/Rayman-style layered subterranean slate cliff cross-section (ZERO geometric Voronoi polygons!)."""
    n = SIZE
    macro = aniso_fbm(n, 5, 10, 4, 601)
    wx = (macro - 0.5) * 32.0
    wy = (aniso_fbm(n, 6, 6, 4, 602) - 0.5) * 26.0

    # Deep layered sedimentary slate bands + rugged domain-warped rock shelves
    strata = warp_sample(aniso_fbm(n, 4, 28, 5, 603, persistence=0.58), wx, wy)
    fine = aniso_fbm(n, 48, 48, 4, 604, persistence=0.64)
    # Sharp ridged rocky ledges & deep dark fissures
    ridge1 = 1.0 - np.abs(warp_sample(aniso_fbm(n, 6, 12, 4, 605), wx * 1.2, wy * 1.2) - 0.5) * 2.0
    ridge2 = 1.0 - np.abs(warp_sample(aniso_fbm(n, 14, 14, 4, 606), wx * 0.8, wy * 0.8) - 0.5) * 2.0
    cracks = np.clip((1.0 - ridge1) / 0.18, 0.0, 1.0)
    shelf = np.power(np.clip(ridge1, 0.0, 1.0), 1.8) * 0.55 + np.power(np.clip(ridge2, 0.0, 1.0), 2.0) * 0.45

    # Subtle glowing damp teal-emerald mineral moss veins deep in rock fissures
    vein = np.clip((1.0 - cracks) * (aniso_fbm(n, 8, 8, 3, 615) - 0.42) * 3.2, 0.0, 1.0)

    h = (0.35 * strata + 0.40 * shelf + 0.25 * fine) * (0.45 + 0.55 * cracks)
    val = (0.14 + 0.34 * strata + 0.22 * shelf + 0.14 * fine) * (0.35 + 0.65 * cracks)

    alb = np.stack([
        np.clip(val * 0.38 + vein * 0.04, 0.0, 1.0),
        np.clip(val * 0.62 + vein * 0.34, 0.0, 1.0),
        np.clip(val * 0.80 + vein * 0.40, 0.0, 1.0),
    ], axis=-1)
    rough = np.clip(0.56 + 0.34 * (1.0 - shelf) - vein * 0.24, 0.24, 0.95)
    save_pbr("cutaway_bedrock", alb, h, rough, normal_strength=10.5)


def make_fabric_detail():
    """Fine pirate linen/canvas micro-weave for characters."""
    n = SIZE
    y = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[:, None]
    x = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)[None, :]
    wx = np.sin(x * 128.0 * np.pi) * 0.5 + 0.5
    wy = np.sin(y * 128.0 * np.pi) * 0.5 + 0.5
    weave = (wx * 0.5 + wy * 0.5) * 0.55 + aniso_fbm(n, 16, 16, 4, 701) * 0.45
    alb = np.stack([weave, weave, weave], axis=-1)
    rough = np.clip(0.64 + 0.26 * (1.0 - weave), 0.42, 0.94)
    save_pbr("fabric_detail", alb, weave, rough, normal_strength=4.2)


if __name__ == "__main__":
    make_wood_planks()
    make_stone_masonry()
    make_sandstone_wall()
    make_roof_shingles()
    make_forged_metal()
    make_cutaway_bedrock()
    make_fabric_detail()
    print("All 7 photorealistic high-frequency PBR texture sets ready!")
