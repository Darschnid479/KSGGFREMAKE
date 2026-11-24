#!/usr/bin/env python3
"""Downloads curated CC0 3D models, 2K PBR texture sets, 1K HDRIs, and Godot Asset Library shaders
from Poly Haven, KayKit (CC0), and Godot Asset Library into godot_project/assets/."""

import concurrent.futures
import io
import json
import os
import pathlib
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
GP = ROOT / "godot_project"
UA = "KSGGF-Remaster-AssetFetcher/1.0"


def fetch_bytes(url: str, timeout: int = 45) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def download_file(url: str, dest: pathlib.Path) -> str:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 128:
        return f"cached:{dest.name}"
    data = fetch_bytes(url, timeout=90)
    dest.write_bytes(data)
    return f"ok:{dest.name}({len(data)//1024}KB)"


def download_polyhaven_textures() -> list:
    packs = {
        "rock_natural": "rock_face_03",
        "wood_planks": "wood_planks",
        "stone_masonry": "mossy_stone_wall",
        "cobblestone": "cobblestone_04",
        "sandstone_wall": "clay_plaster",
        "coast_sand": "coast_sand_01",
        "roof_shingles": "clay_roof_tiles",
        "cutaway_bedrock": "aerial_rocks_02",
        "forged_metal": "metal_plate_02",
        "fabric_detail": "denim_fabric",
        "leather_detail": "brown_leather",
    }
    pbr_dir = GP / "assets" / "textures" / "pbr"
    # Remove synthetic legacy .pngs so only real photogrammetry PBR files are loaded
    for old_png in pbr_dir.glob("*.png"):
        old_png.unlink()
    for old_imp in pbr_dir.glob("*.png.import"):
        old_imp.unlink()

    jobs = []
    for target_name, ph_id in packs.items():
        info = json.loads(fetch_bytes(f"https://api.polyhaven.com/files/{ph_id}").decode())
        for slot_key, suffix in [("Diffuse", "albedo"), ("nor_gl", "normal"), ("Rough", "rough")]:
            slot = info.get(slot_key, {}).get("2k", {})
            fmt = "jpg" if "jpg" in slot else ("png" if "png" in slot else next(iter(slot.keys()), None))
            if not fmt:
                print(f"WARN: missing {ph_id}.{slot_key}")
                continue
            url = slot[fmt]["url"]
            jobs.append((url, pbr_dir / f"{target_name}_{suffix}.{fmt}"))
    return jobs


def download_polyhaven_hdris() -> list:
    hdris = [
        "kloofendal_48d_partly_cloudy_puresky",
        "small_harbor_01",
        "spiaggia_di_mondello",
        "goegap",
        "rogland_moonlit_night",
        "drachenfels_cellar",
    ]
    hdri_dir = GP / "assets" / "hdri"
    jobs = []
    for hid in hdris:
        info = json.loads(fetch_bytes(f"https://api.polyhaven.com/files/{hid}").decode())
        h1k = info.get("hdri", {}).get("1k", {})
        fmt = "hdr" if "hdr" in h1k else next(iter(h1k.keys()), None)
        if fmt:
            jobs.append((h1k[fmt]["url"], hdri_dir / f"{hid}_1k.{fmt}"))
    return jobs


def download_polyhaven_models() -> list:
    models = [
        "wooden_handle_saber",
        "antique_estoc",
        "treasure_chest",
        "wooden_barrels_01",
        "wine_barrel_01",
        "wooden_crate_01",
        "wooden_crate_02",
        "wooden_bucket_01",
        "wooden_lantern_01",
        "brass_diya_lantern",
        "lantern_chandelier_01",
        "cannon_01",
        "ocean_buoy",
        "dutch_ship_medium",
        "modular_fort_01",
        "modular_wooden_pier",
        "fern_02",
        "shrub_sorrel_01",
        "calathea_orbifolia_01",
        "pachira_aquatica_01",
        "rock_moss_set_01",
        "rock_07",
        "rock_09",
        "boulder_01",
        "namaqualand_cliff_01",
        "mountainside",
    ]
    base_dir = GP / "assets" / "store" / "polyhaven"
    jobs = []
    for mid in models:
        info = json.loads(fetch_bytes(f"https://api.polyhaven.com/files/{mid}").decode())
        gltf_1k = info.get("gltf", {}).get("1k", {}).get("gltf", {})
        if not gltf_1k:
            print(f"WARN: no 1k gltf for {mid}")
            continue
        mdir = base_dir / mid
        root_name = pathlib.Path(gltf_1k["url"]).name
        jobs.append((gltf_1k["url"], mdir / root_name))
        for rel_path, inc in gltf_1k.get("include", {}).items():
            jobs.append((inc["url"], mdir / rel_path))
    return jobs


def install_kaykit_packs() -> None:
    specs = [
        (
            "https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0/archive/refs/heads/main.zip",
            GP / "assets" / "store" / "kaykit_medieval",
            "Assets/gltf/",
            lambda rel: (
                not rel.endswith("/")
                and (
                    rel.startswith("buildings/blue/")
                    or rel.startswith("buildings/yellow/")
                    or rel.startswith("buildings/red/")
                    or rel.startswith("buildings/neutral/")
                    or rel.startswith("decoration/nature/")
                    or rel.startswith("decoration/props/")
                    or rel.endswith(".png")
                )
            ),
        ),
        (
            "https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/archive/refs/heads/main.zip",
            GP / "assets" / "store" / "kaykit_dungeon",
            "Assets/gltf/",
            lambda rel: (
                not rel.endswith("/")
                and not rel.startswith("floor_")
                and not rel.startswith("wall_Tsplit")
            ),
        ),
    ]
    for url, out_dir, anchor, pred in specs:
        marker = out_dir / ".installed_ok"
        if marker.exists():
            print("KayKit cached:", out_dir.name)
            continue
        print("Downloading KayKit:", out_dir.name)
        raw = fetch_bytes(url, timeout=90)
        z = zipfile.ZipFile(io.BytesIO(raw))
        cnt = 0
        for name in z.namelist():
            if anchor not in name:
                continue
            rel = name.split(anchor, 1)[1]
            if not rel or not pred(rel):
                continue
            target = out_dir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
            cnt += 1
        marker.write_text(f"files={cnt}\n")
        print(f"Installed {cnt} files into {out_dir}")


def install_boujie_water() -> None:
    addons_dir = GP / "addons" / "boujie_water_shader"
    if (addons_dir / "shader" / "water.gdshader").exists():
        print("Boujie Water Shader cached")
        return
    url = "https://github.com/Chrisknyfe/boujie_water_shader/archive/8b933c4428d6984029cba52cebc224449ac74549.zip"
    raw = fetch_bytes(url, timeout=60)
    z = zipfile.ZipFile(io.BytesIO(raw))
    cnt = 0
    for name in z.namelist():
        if "addons/boujie_water_shader/" not in name or name.endswith("/"):
            continue
        rel = name.split("addons/boujie_water_shader/", 1)[1]
        if rel.startswith("screenshots/"):
            continue
        target = addons_dir / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(z.read(name))
        cnt += 1
    print(f"Installed Boujie Water Shader ({cnt} files)")


def main() -> None:
    print("1/4 Installing Godot Asset Library Boujie Water Shader...")
    install_boujie_water()
    print("2/4 Installing KayKit Medieval & Dungeon CC0 packs...")
    install_kaykit_packs()

    print("3/4 Resolving Poly Haven Textures, HDRIs, and Smugglers Cove 3D models...")
    jobs = []
    jobs.extend(download_polyhaven_textures())
    jobs.extend(download_polyhaven_hdris())
    jobs.extend(download_polyhaven_models())
    print(f"4/4 Downloading {len(jobs)} Poly Haven files in parallel...")

    ok_cnt = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        futs = [ex.submit(download_file, u, p) for u, p in jobs]
        for f in concurrent.futures.as_completed(futs):
            res = f.result()
            ok_cnt += 1
            if ok_cnt % 25 == 0 or ok_cnt == len(jobs):
                print(f"  Progress: {ok_cnt}/{len(jobs)} ({res})")
    print("ALL ASSET STORE DOWNLOADS COMPLETE!")


if __name__ == "__main__":
    main()
