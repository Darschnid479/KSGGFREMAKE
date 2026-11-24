#!/usr/bin/env python3
"""
Builds the crisp, high-resolution 2026 Stylized UI / HUD / Menu / World-Map Overlay asset set
in godot_project/assets/ui/ directly from the extracted original 2007 Shockwave Director cast
references (work_refs/original_ui/), combining clean stylized artwork with licensed CC0
material substrates (parchment/plaster grain, brushed metal gold sheen, woven cloth) while
removing all earlier AI-generated realistic portraits and coins.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from scipy.ndimage import gaussian_filter, sobel

ORIG_UI = Path("/home/antigravity/sabeltann_remake/work_refs/original_ui")
CC0_STYL = Path("/home/antigravity/sabeltann_remake/work_refs/cc0_library/stylized")
OUT_UI = Path("/home/antigravity/sabeltann_remake/godot_project/assets/ui")


def clean_stylized_ui(src_path: Path, scale: int = 2, max_dim: int = 1024, gold_sheen: bool = False, parchment_grain: bool = False) -> Image.Image:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    tw = min(w * scale, max_dim)
    th = min(h * scale, max_dim)
    ratio = min(tw / max(w, 1), th / max(h, 1))
    tw, th = max(32, int(round(w * ratio))), max(32, int(round(h * ratio)))

    arr = np.asarray(im, dtype=np.float32) / 255.0
    a = arr[:, :, 3:4]
    rgb_pre = arr[:, :, :3] * a

    rgb_im = Image.fromarray((np.clip(rgb_pre, 0, 1) * 255).astype(np.uint8), "RGB").resize((tw, th), Image.Resampling.LANCZOS)
    a_im = Image.fromarray((np.clip(a[:, :, 0], 0, 1) * 255).astype(np.uint8), "L").resize((tw, th), Image.Resampling.LANCZOS)

    a_arr = np.asarray(a_im, dtype=np.float32) / 255.0
    rgb_arr = np.asarray(rgb_im, dtype=np.float32) / 255.0
    safe_a = np.where(a_arr > 0.03, a_arr, 1.0)[:, :, None]
    rgb = np.where(a_arr[:, :, None] > 0.03, np.clip(rgb_arr / safe_a, 0.0, 1.0), rgb_arr)

    # Edge-preserving cartoon cleanup (smooths JPEG blocks while keeping bold ink outlines & facial detail sharp!)
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    edge = np.sqrt(sobel(lum, axis=1) ** 2 + sobel(lum, axis=0) ** 2)
    w_edge = np.clip((edge - 0.14) / 0.36, 0.0, 1.0)
    out = np.empty_like(rgb)
    for c in range(3):
        sm = gaussian_filter(rgb[:, :, c], sigma=1.4)
        fine = gaussian_filter(rgb[:, :, c], sigma=0.5)
        out[:, :, c] = sm * (1.0 - w_edge) + fine * w_edge

    # Optional CC0 brushed metallic micro-sheen on gold frames/coins
    if gold_sheen and (CC0_STYL / "metal_iron" / "albedo.png").exists():
        mtex = np.asarray(Image.open(CC0_STYL / "metal_iron" / "albedo.png").convert("L").resize((tw, th), Image.Resampling.LANCZOS), dtype=np.float32) / 255.0
        mmod = np.clip(mtex / max(float(mtex.mean()), 0.1), 0.90, 1.12)[:, :, None]
        # Apply subtle brushed gold texture ONLY to warm gold pixels
        gold_m = ((out[:, :, 0] > 0.45) & (out[:, :, 1] > 0.30) & (out[:, :, 0] > out[:, :, 2] * 1.35)).astype(np.float32)[:, :, None]
        out = np.clip(out * (1.0 - 0.35 * gold_m + 0.35 * gold_m * mmod), 0.0, 1.0)

    # Optional CC0 fine parchment grain on the World Map treasure-map frame
    if parchment_grain and (CC0_STYL / "plaster_clean" / "albedo.png").exists():
        ptex = np.asarray(Image.open(CC0_STYL / "plaster_clean" / "albedo.png").convert("L").resize((tw, th), Image.Resampling.LANCZOS), dtype=np.float32) / 255.0
        pmod = np.clip(ptex / max(float(ptex.mean()), 0.1), 0.90, 1.10)[:, :, None]
        out = np.clip(out * (0.72 + 0.28 * pmod), 0.0, 1.0)

    # Gentle stylized vibrancy & clean anti-aliased alpha
    luma_o = (0.299 * out[:, :, 0] + 0.587 * out[:, :, 1] + 0.114 * out[:, :, 2])[:, :, None]
    out = np.clip(luma_o + (out - luma_o) * 1.08, 0.0, 1.0)
    a_clean = np.clip((a_arr - 0.02) / 0.96, 0.0, 1.0)

    rgba = np.concatenate([out, a_clean[:, :, None]], axis=2)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    OUT_UI.mkdir(parents=True, exist_ok=True)
    manifest = []

    jobs = [
        # Core HUD medallions & coins (replacing earlier AI-generated realistic portrait & coin!)
        ("hud/healthbg_pinky.png", "hud_pinky_medallion.png", 2, 512, True, False),
        ("hud/healthbg_ship.png", "hud_ship_medallion.png", 2, 512, True, False),
        ("hud/healthbar_amount22.png", "hud_healthbar_full.png", 2, 512, False, False),
        ("hud/goldcoin.png", "gold_doubloon.png", 3, 256, True, False),
        ("hud/coppercoin.png", "silver_coin.png", 3, 256, True, False),
        # Equipped weapon badges tucked behind Pinky's medallion
        ("hud/actionitem_swordstick.png", "hud_item_sword.png", 2, 256, True, False),
        ("hud/actionitem_goldsword.png", "hud_item_goldsword.png", 2, 256, True, False),
        ("hud/actionitem_slingshot.png", "hud_item_slingshot.png", 2, 256, True, False),
        ("hud/actionitem_lamp.png", "hud_item_lamp.png", 2, 256, True, False),
        # Context action icons (bottom-right golden medallion matching original 2007 HUD!)
        ("hud/action_talk.png", "hud_action_talk.png", 2, 256, True, False),
        ("hud/action_sword.png", "hud_action_sword.png", 2, 256, True, False),
        ("hud/action_jump.png", "hud_action_jump.png", 2, 256, True, False),
        ("hud/action_pushpull.png", "hud_action_pushpull.png", 2, 256, True, False),
        ("hud/action_climb.png", "hud_action_climb.png", 2, 256, True, False),
        ("hud/action_portal.png", "hud_action_portal.png", 2, 256, True, False),
        ("hud/action_shop.png", "hud_action_shop.png", 2, 256, True, False),
        ("hud/action_dig.png", "hud_action_dig.png", 2, 256, True, False),
        ("hud/action_underwater.png", "hud_action_underwater.png", 2, 256, True, False),
        ("hud/action_gong.png", "hud_action_gong.png", 2, 256, True, False),
        ("hud/action_travel.png", "hud_action_travel.png", 2, 256, True, False),
        ("hud/action_pickup.png", "hud_action_pickup.png", 2, 256, True, False),
        ("hud/action_thrown.png", "hud_action_thrown.png", 2, 256, True, False),
        # All 4 original Boss HUD frames
        ("graal_boss_hud/graalboss_healthbar_background.png", "hud_boss_graal.png", 2, 768, True, False),
        ("cave_boss_hud/skeletonboss_healthbar_background.png", "hud_boss_cave.png", 2, 768, True, False),
        ("fatamorgana_boss_hud/fatamorganaboss_healthbar_background.png", "hud_boss_fatamorgana.png", 2, 768, True, False),
        ("mk_boss_hud/sabeltann_healthbar_background.png", "hud_boss_mk.png", 2, 768, True, False),
        # Underwater HUD frame
        ("swimming_hud/interface_underwater.png", "hud_underwater_bar.png", 2, 512, True, False),
        # World map torn parchment border overlay (from world_map.cst!)
        ("world_map/overlay.png", "world_map_overlay.png", 1, 1024, False, True),
        # Menu islands silhouette overlay
        ("menu/islands.png", "menu_islands_overlay.png", 1, 1024, False, True),
    ]

    for rel_src, dst_name, sc, mdim, gold_s, parch_g in jobs:
        sp = ORIG_UI / rel_src
        if not sp.exists():
            print(f"[SKIP] Missing {sp}")
            continue
        out_im = clean_stylized_ui(sp, scale=sc, max_dim=mdim, gold_sheen=gold_s, parchment_grain=parch_g)
        out_im.save(OUT_UI / dst_name, optimize=True)
        manifest.append({"file": f"res://assets/ui/{dst_name}", "source_ref": rel_src, "size": list(out_im.size)})
        print(f"[UI OK] {dst_name:32s} <- {rel_src} ({out_im.size[0]}x{out_im.size[1]})")

    # Also overwrite pinky_portrait.png cleanly with the authentic stylized medallion so zero old AI portrait remains
    if (OUT_UI / "hud_pinky_medallion.png").exists():
        Image.open(OUT_UI / "hud_pinky_medallion.png").save(OUT_UI / "pinky_portrait.png", optimize=True)

    (OUT_UI / "ui_manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"UI rebuild complete: {len(manifest)} stylized 2026 UI assets written to {OUT_UI}")


if __name__ == "__main__":
    main()
