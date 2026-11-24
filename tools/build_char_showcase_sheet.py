#!/usr/bin/env python3
"""Stitches the 10 4K character close-up studio renders into a crisp visual QA contact sheet."""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/home/antigravity/sabeltann_remake")
SRC = ROOT / "docs/before_after/characters_4k"
OUT = ROOT / "docs/before_after/comparisons/characters_4k_showcase.jpg"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

LABELS = [
    ("00_pinky_front.png", "Pinky (forfra — 4K nybygg)"),
    ("01_pinky_back.png", "Pinky (bakfra — 4K nybygg)"),
    ("02_sabeltann_front.png", "Kaptein Sabeltann (4K fløyel + gull)"),
    ("03_langemann_front.png", "Langemann (4K stoff + lær)"),
    ("04_sunniva_front.png", "Sunniva (4K kjole + hår)"),
    ("05_pelle_front.png", "Pelle / Pysa (4K vest + skjorte)"),
    ("06_skalken_front.png", "Skalken (4K kokkedrakt)"),
    ("07_miriam_front.png", "Miriam (4K fløyel + stjerner)"),
    ("08_maga_khan_front.png", "Maga Khan (4K brokade + rustning)"),
    ("09_sultan_front.png", "Sultanen (4K kongekappe)"),
]


def main():
    cols, rows = 2, 5
    tw, th = 640, 420
    pad, hdr = 14, 34
    W = pad * (cols + 1) + tw * cols
    H = pad + rows * (th + hdr + pad) + 46
    canvas = Image.new("RGB", (W, H), (16, 18, 24))
    draw = ImageDraw.Draw(canvas)
    ft = ImageFont.truetype(FONT, 26) if os.path.exists(FONT) else ImageFont.load_default()
    fl = ImageFont.truetype(FONT, 19) if os.path.exists(FONT) else ImageFont.load_default()
    draw.text((pad, 10), "KSGGFREMAKE — Alle karakterer bygget på nytt (4K CC0 PBR + høy-poly skulpturert)", fill=(252, 224, 128), font=ft)

    for idx, (fn, title) in enumerate(LABELS):
        p = SRC / fn
        if not p.exists():
            continue
        r, c = idx // cols, idx % cols
        x0 = pad + c * (tw + pad)
        y0 = 46 + pad + r * (th + hdr + pad)
        draw.text((x0 + 4, y0 + 5), title, fill=(140, 245, 175), font=fl)
        im = Image.open(p).convert("RGB")
        # Crop center portrait tightly around the character
        iw, ih = im.size
        crop_w = int(ih * (tw / th))
        cx0 = max(0, (iw - crop_w) // 2)
        im = im.crop((cx0, 0, min(iw, cx0 + crop_w), ih)).resize((tw, th), Image.Resampling.LANCZOS)
        canvas.paste(im, (x0, y0 + hdr))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, "JPEG", quality=93, optimize=True)
    print(f"[OK] Saved 4K character showcase -> {OUT}")


if __name__ == "__main__":
    main()
