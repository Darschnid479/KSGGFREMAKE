#!/usr/bin/env python3
"""
HD Texture Upscaler + PBR Normal/Roughness Generator + Wavefront OBJ/MTL -> glTF 2.0 (.glb) Packer.

Transforms extracted 2005 Shockwave 3D (.obj + .mtl + .tif/.png/.jpg) models into modern
Godot 4-ready PBR .glb assets with:
  - 4x multi-stage edge-preserving upscaled textures (capped at 2048px, halo-free alpha)
  - Synthesized tangent-space PBR Normal Maps (multi-scale Sobel luminance gradients)
  - Synthesized PBR ORM (Occlusion/Roughness/Metallic) maps with material-aware presets
  - Shockwave 3D Z-up -> glTF/Godot Y-up coordinate conversion
  - Clean sub-mesh splitting by object/material and alpha-cutout/blend detection
"""
import io
import json
import math
import os
import struct
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy.ndimage import sobel, gaussian_filter

MAX_TEX_DIM = 1024  # Crisp HD without ballooning archive sizes (up to 4x upscale)
UPSCALE_FACTOR = 4


def upscale_image_hd(img: Image.Image, max_dim: int = MAX_TEX_DIM) -> Image.Image:
    """Multi-pass 4x Lanczos upscale with halo-free alpha and edge-preserving micro-sharpening."""
    has_alpha = img.mode in ("RGBA", "LA") or ("transparency" in img.info)
    rgba = img.convert("RGBA") if has_alpha else img.convert("RGB")
    w, h = rgba.size

    # Compute target size (up to 4x, clamped to max_dim, power-of-2 friendly)
    scale = UPSCALE_FACTOR
    tw, th = min(w * scale, max_dim), min(h * scale, max_dim)
    # Preserve aspect ratio
    ratio = min(tw / max(w, 1), th / max(h, 1))
    if ratio < 1.0:
        ratio = 1.0
    tw, th = max(16, int(round(w * ratio))), max(16, int(round(h * ratio)))

    if has_alpha:
        # Premultiply RGB by alpha before resizing to prevent black fringes on transparent cutouts
        arr = np.asarray(rgba, dtype=np.float32)
        a = arr[:, :, 3:4] / 255.0
        rgb_pre = np.clip(arr[:, :, :3] * a, 0, 255).astype(np.uint8)
        alpha_ch = rgba.split()[3]

        # Two-stage upscale for sharper edge preservation
        mid_w, mid_h = max(w, (w + tw) // 2), max(h, (h + th) // 2)
        rgb_img = Image.fromarray(rgb_pre, "RGB").resize((mid_w, mid_h), Image.Resampling.LANCZOS)
        rgb_img = rgb_img.filter(ImageFilter.UnsharpMask(radius=1.0, percent=85, threshold=3))
        rgb_img = rgb_img.resize((tw, th), Image.Resampling.LANCZOS)
        rgb_img = rgb_img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=2))

        a_img = alpha_ch.resize((tw, th), Image.Resampling.LANCZOS)
        a_arr = np.asarray(a_img, dtype=np.float32)[:, :, None] / 255.0
        rgb_arr = np.asarray(rgb_img, dtype=np.float32)
        # Un-premultiply safely
        safe_a = np.where(a_arr > 0.02, a_arr, 1.0)
        rgb_un = np.where(a_arr > 0.02, np.clip(rgb_arr / safe_a, 0, 255), rgb_arr)
        out = np.concatenate([rgb_un.astype(np.uint8), np.asarray(a_img, dtype=np.uint8)[:, :, None]], axis=2)
        out_img = Image.fromarray(out, "RGBA")
    else:
        mid_w, mid_h = max(w, (w + tw) // 2), max(h, (h + th) // 2)
        out_img = rgba.resize((mid_w, mid_h), Image.Resampling.LANCZOS)
        out_img = out_img.filter(ImageFilter.UnsharpMask(radius=1.0, percent=80, threshold=3))
        out_img = out_img.resize((tw, th), Image.Resampling.LANCZOS)
        out_img = out_img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=105, threshold=2))
        out_img = ImageEnhance.Contrast(out_img).enhance(1.06)
        out_img = ImageEnhance.Color(out_img).enhance(1.08)

    return out_img


def classify_material_hints(name: str):
    """Return (base_roughness, base_metallic, normal_strength) based on material/texture name."""
    n = name.lower()
    if any(k in n for k in ("gold", "coin", "treasure", "crown", "brass", "bell")):
        return 0.25, 0.85, 2.2
    if any(k in n for k in ("sword", "rapier", "metal", "iron", "blade", "armor", "cannon", "anchor", "chain")):
        return 0.32, 0.78, 2.0
    if any(k in n for k in ("water", "sea", "ocean", "wave", "river", "pool")):
        return 0.08, 0.05, 1.5
    if any(k in n for k in ("glass", "crystal", "gem", "lamp", "glow")):
        return 0.15, 0.10, 1.2
    if any(k in n for k in ("wood", "plank", "ship", "darklady", "barrel", "crate", "door", "bridge", "dock", "mast")):
        return 0.68, 0.0, 2.6
    if any(k in n for k in ("rock", "stone", "cave", "wall", "brick", "cliff", "ground", "sand", "mountain", "floor", "road")):
        return 0.82, 0.0, 3.0
    if any(k in n for k in ("leaf", "leaves", "palm", "tree", "grass", "bush", "jungle", "plant", "foliage")):
        return 0.72, 0.0, 1.8
    if any(k in n for k in ("skin", "face", "pinky", "sabeltann", "langemann", "sunniva", "pelle", "cloth", "coat", "hat", "sail")):
        return 0.62, 0.0, 1.4
    return 0.72, 0.0, 2.0


def synthesize_pbr_maps(albedo: Image.Image, mat_name: str):
    """Synthesize tangent-space Normal map and ORM (AO/Roughness/Metallic) map from HD albedo."""
    base_rough, base_metal, strength = classify_material_hints(mat_name)
    rgb = np.asarray(albedo.convert("RGB"), dtype=np.float32) / 255.0
    # Perceptual luminance as height proxy
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]

    # Multi-scale height field (fine + medium frequencies)
    fine = lum - gaussian_filter(lum, sigma=1.2)
    med = gaussian_filter(lum, sigma=1.0) - gaussian_filter(lum, sigma=4.0)
    height = lum * 0.45 + med * 0.35 + fine * 0.20

    dx = sobel(height, axis=1, mode="wrap") * strength
    dy = sobel(height, axis=0, mode="wrap") * strength
    dz = np.ones_like(dx)

    norm = np.sqrt(dx * dx + dy * dy + dz * dz) + 1e-6
    nx = (-dx / norm) * 0.5 + 0.5
    ny = (-dy / norm) * 0.5 + 0.5
    nz = (dz / norm) * 0.5 + 0.5

    normal_arr = np.stack([nx, ny, nz], axis=2)
    normal_img = Image.fromarray(np.clip(normal_arr * 255.0, 0, 255).astype(np.uint8), "RGB")

    # Ambient Occlusion (R): crevices slightly darker
    blur_large = gaussian_filter(lum, sigma=6.0)
    ao = np.clip(0.75 + 0.25 * (lum / (blur_large + 0.15)), 0.45, 1.0)

    # Roughness (G): darker crevices slightly rougher, highlights slightly smoother
    rough = np.clip(base_rough + (0.5 - lum) * 0.22 + np.abs(fine) * 0.35, 0.08, 0.96)

    # Metallic (B)
    metal = np.full_like(rough, base_metal)
    if base_metal > 0.1:
        metal = np.clip(base_metal * (0.7 + 0.3 * lum), 0.0, 1.0)

    orm_arr = np.stack([ao, rough, metal], axis=2)
    orm_img = Image.fromarray(np.clip(orm_arr * 255.0, 0, 255).astype(np.uint8), "RGB")
    return normal_img, orm_img, base_rough, base_metal


def parse_mtl(mtl_path: Path):
    materials = {}
    if not mtl_path.exists():
        return materials
    cur = None
    for raw in mtl_path.read_text(encoding="latin1", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        key, val = parts[0].lower(), parts[1].strip()
        if key == "newmtl":
            cur = val
            materials[cur] = {
                "Kd": [1.0, 1.0, 1.0],
                "Ks": [0.1, 0.1, 0.1],
                "Ke": [0.0, 0.0, 0.0],
                "d": 1.0,
                "map_Kd": None,
                "map_d": None,
            }
        elif cur is not None:
            if key == "kd":
                nums = [float(x) for x in val.split()[:3]]
                if len(nums) == 3:
                    materials[cur]["Kd"] = nums
            elif key == "ke":
                nums = [float(x) for x in val.split()[:3]]
                if len(nums) == 3:
                    materials[cur]["Ke"] = nums
            elif key == "d":
                try:
                    materials[cur]["d"] = float(val.split()[0])
                except Exception:
                    pass
            elif key == "tr":
                try:
                    materials[cur]["d"] = 1.0 - float(val.split()[0])
                except Exception:
                    pass
            elif key == "map_kd":
                materials[cur]["map_Kd"] = val.strip('"')
            elif key == "map_d":
                materials[cur]["map_d"] = val.strip('"')
    return materials


def parse_obj(obj_path: Path, swap_yz: bool = True, scale: float = 0.1):
    """
    Parse Wavefront OBJ into per-(object, material) triangle primitives.
    Shockwave 3D uses Z-up and ~10 units per meter (Pinky ~15 units tall -> ~1.5m at scale=0.1).
    """
    positions = []
    normals = []
    texcoords = []
    mtllib = None

    cur_obj = "root"
    cur_mat = "default"
    # buckets[(obj_name, mat_name)] = list of face vertex tuples (vi, ti, ni)
    buckets = {}

    for raw in obj_path.read_text(encoding="latin1", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("mtllib "):
            mtllib = line[7:].strip()
        elif line.startswith("v "):
            p = line.split()
            x, y, z = float(p[1]) * scale, float(p[2]) * scale, float(p[3]) * scale
            if swap_yz:
                # Shockwave (X, Y, Z) -> Godot/glTF (X, Z, -Y)
                positions.append((x, z, -y))
            else:
                positions.append((x, y, z))
        elif line.startswith("vn "):
            p = line.split()
            nx, ny, nz = float(p[1]), float(p[2]), float(p[3])
            if swap_yz:
                normals.append((nx, nz, -ny))
            else:
                normals.append((nx, ny, nz))
        elif line.startswith("vt "):
            p = line.split()
            u = float(p[1])
            v = 1.0 - float(p[2])  # glTF UV origin is top-left (OBJ is bottom-left)
            texcoords.append((u, v))
        elif line.startswith("o ") or line.startswith("g "):
            nm = line[2:].strip()
            if nm:
                cur_obj = nm
        elif line.startswith("usemtl "):
            cur_mat = line[7:].strip() or "default"
        elif line.startswith("f "):
            tokens = line.split()[1:]
            face = []
            for tok in tokens:
                parts = tok.split("/")
                vi = int(parts[0]) - 1 if parts[0] else -1
                if vi < -1:
                    vi = len(positions) + vi + 1
                ti = int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1
                if ti < -1:
                    ti = len(texcoords) + ti + 1
                ni = int(parts[2]) - 1 if len(parts) > 2 and parts[2] else -1
                if ni < -1:
                    ni = len(normals) + ni + 1
                face.append((vi, ti, ni))
            if len(face) >= 3:
                key = (cur_obj, cur_mat)
                b = buckets.setdefault(key, [])
                for i in range(1, len(face) - 1):
                    b.append((face[0], face[i], face[i + 1]))

    return positions, normals, texcoords, mtllib, buckets


def encode_image_bytes(img: Image.Image, prefer_jpeg: bool = True, quality: int = 90):
    buf = io.BytesIO()
    if img.mode == "RGBA":
        # Check if alpha channel is actually used (< 252 anywhere)
        a_min = img.getextrema()[3][0]
        if a_min < 252 or not prefer_jpeg:
            img.save(buf, format="PNG", optimize=True)
            return buf.getvalue(), "image/png", True
        img = img.convert("RGB")
    if prefer_jpeg:
        img.save(buf, format="JPEG", quality=quality, subsampling=0)
        return buf.getvalue(), "image/jpeg", False
    else:
        img.save(buf, format="PNG", optimize=True)
        return buf.getvalue(), "image/png", False


def build_glb(obj_path: Path, glb_path: Path, upscale: bool = True, scale: float = 0.1, swap_yz: bool = True):
    positions, normals, texcoords, mtllib, buckets = parse_obj(obj_path, swap_yz=swap_yz, scale=scale)
    if not buckets or not positions:
        return False, "No geometry found"

    mtl_path = obj_path.parent / mtllib if mtllib else obj_path.with_suffix(".MTL")
    if not mtl_path.exists():
        mtl_path = obj_path.with_suffix(".mtl")
    mtl_defs = parse_mtl(mtl_path)

    bin_chunks = bytearray()
    buffer_views = []
    accessors = []
    images = []
    textures = []
    materials = []
    samplers = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]

    def add_buffer_view(data: bytes, target=None):
        while len(bin_chunks) % 4 != 0:
            bin_chunks.append(0)
        offset = len(bin_chunks)
        bin_chunks.extend(data)
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            bv["target"] = target
        idx = len(buffer_views)
        buffer_views.append(bv)
        return idx

    def add_image(img_bytes: bytes, mime: str, name: str):
        bv_idx = add_buffer_view(img_bytes)
        img_idx = len(images)
        images.append({"bufferView": bv_idx, "mimeType": mime, "name": name})
        tex_idx = len(textures)
        textures.append({"sampler": 0, "source": img_idx})
        return tex_idx

    # Build materials (deduplicated)
    mat_index_map = {}
    tex_cache = {}  # tex_path -> (albedo_tex_idx, norm_tex_idx, orm_tex_idx, has_alpha, base_r, base_m)

    def find_texture_file(tex_ref: str):
        if not tex_ref:
            return None
        cand = obj_path.parent / tex_ref
        if cand.exists():
            return cand
        # Case-insensitive fallback
        low = Path(tex_ref).name.lower()
        for f in obj_path.parent.iterdir():
            if f.name.lower() == low:
                return f
        return None

    def get_or_create_material(mat_name: str):
        if mat_name in mat_index_map:
            return mat_index_map[mat_name]
        mdef = mtl_defs.get(mat_name, {"Kd": [0.85, 0.85, 0.85], "d": 1.0, "Ke": [0.0, 0.0, 0.0], "map_Kd": None})
        base_r, base_m, _ = classify_material_hints(mat_name)
        kd = mdef["Kd"]
        alpha = float(mdef.get("d", 1.0))

        tex_file = find_texture_file(mdef.get("map_Kd"))
        has_tex_alpha = False
        albedo_idx = norm_idx = orm_idx = None

        if tex_file is not None:
            cache_key = (str(tex_file), mat_name.lower())
            if cache_key in tex_cache:
                albedo_idx, norm_idx, orm_idx, has_tex_alpha, base_r, base_m = tex_cache[cache_key]
            else:
                try:
                    raw_img = Image.open(tex_file)
                    hd_img = upscale_image_hd(raw_img) if upscale else raw_img
                    norm_img, orm_img, base_r, base_m = synthesize_pbr_maps(hd_img, mat_name + "_" + tex_file.stem)

                    alb_bytes, alb_mime, has_tex_alpha = encode_image_bytes(hd_img, prefer_jpeg=True, quality=92)
                    norm_bytes, norm_mime, _ = encode_image_bytes(norm_img, prefer_jpeg=True, quality=88)
                    orm_bytes, orm_mime, _ = encode_image_bytes(orm_img, prefer_jpeg=True, quality=85)

                    albedo_idx = add_image(alb_bytes, alb_mime, f"{mat_name}_albedo")
                    norm_idx = add_image(norm_bytes, norm_mime, f"{mat_name}_normal")
                    orm_idx = add_image(orm_bytes, orm_mime, f"{mat_name}_orm")
                    tex_cache[cache_key] = (albedo_idx, norm_idx, orm_idx, has_tex_alpha, base_r, base_m)
                except Exception as e:
                    print(f"  [warn] failed texture {tex_file}: {e}")

        pbr = {
            "baseColorFactor": [
                1.0 if albedo_idx is not None else kd[0],
                1.0 if albedo_idx is not None else kd[1],
                1.0 if albedo_idx is not None else kd[2],
                alpha,
            ],
            "roughnessFactor": 1.0 if orm_idx is not None else base_r,
            "metallicFactor": 1.0 if orm_idx is not None else base_m,
        }
        if albedo_idx is not None:
            pbr["baseColorTexture"] = {"index": albedo_idx}
        if orm_idx is not None:
            pbr["metallicRoughnessTexture"] = {"index": orm_idx}

        gltf_mat = {
            "name": mat_name,
            "pbrMetallicRoughness": pbr,
            "doubleSided": True,
        }
        if norm_idx is not None:
            gltf_mat["normalTexture"] = {"index": norm_idx, "scale": 0.75}
        if orm_idx is not None:
            gltf_mat["occlusionTexture"] = {"index": orm_idx, "strength": 0.6}

        ke = mdef.get("Ke", [0.0, 0.0, 0.0])
        if any(c > 0.05 for c in ke) or "glow" in mat_name.lower() or "lamp" in mat_name.lower():
            gltf_mat["emissiveFactor"] = [max(ke[0], 0.35), max(ke[1], 0.28), max(ke[2], 0.12)]

        if alpha < 0.98 or "transparent" in mat_name.lower() or "glow" in mat_name.lower():
            gltf_mat["alphaMode"] = "BLEND"
        elif has_tex_alpha:
            gltf_mat["alphaMode"] = "MASK"
            gltf_mat["alphaCutoff"] = 0.45

        idx = len(materials)
        materials.append(gltf_mat)
        mat_index_map[mat_name] = idx
        return idx

    # Group buckets by object name (skip Shockwave invisible proxy/helper shells)
    obj_groups = {}
    for (obj_name, mat_name), tris in buckets.items():
        low_o = obj_name.lower()
        low_m = mat_name.lower()
        if "proxy" in low_o or "emptymaterial" in low_m or "foginfo" in low_o:
            continue
        obj_groups.setdefault(obj_name, []).append((mat_name, tris))

    meshes = []
    nodes = []

    for obj_name, mat_list in obj_groups.items():
        primitives = []
        for mat_name, tris in mat_list:
            vert_map = {}
            v_pos = []
            v_norm = []
            v_uv = []
            indices = []

            for tri in tris:
                # Compute flat fallback normal if needed
                p0 = positions[tri[0][0]]
                p1 = positions[tri[1][0]]
                p2 = positions[tri[2][0]]
                e1 = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
                e2 = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
                fn = (
                    e1[1] * e2[2] - e1[2] * e2[1],
                    e1[2] * e2[0] - e1[0] * e2[2],
                    e1[0] * e2[1] - e1[1] * e2[0],
                )
                flen = math.sqrt(fn[0] ** 2 + fn[1] ** 2 + fn[2] ** 2)
                fn = (fn[0] / flen, fn[1] / flen, fn[2] / flen) if flen > 1e-8 else (0.0, 1.0, 0.0)

                for vi, ti, ni in tri:
                    key = (vi, ti, ni)
                    idx = vert_map.get(key)
                    if idx is None:
                        idx = len(v_pos)
                        vert_map[key] = idx
                        v_pos.append(positions[vi])
                        if 0 <= ni < len(normals):
                            n = normals[ni]
                            nlen = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
                            v_norm.append((n[0] / nlen, n[1] / nlen, n[2] / nlen) if nlen > 1e-6 else fn)
                        else:
                            v_norm.append(fn)
                        if 0 <= ti < len(texcoords):
                            v_uv.append(texcoords[ti])
                        else:
                            v_uv.append((0.0, 0.0))
                    indices.append(idx)

            if not indices:
                continue

            pos_arr = np.array(v_pos, dtype=np.float32)
            norm_arr = np.array(v_norm, dtype=np.float32)
            uv_arr = np.array(v_uv, dtype=np.float32)
            idx_arr = np.array(indices, dtype=np.uint32)

            pos_bv = add_buffer_view(pos_arr.tobytes(), 34962)
            norm_bv = add_buffer_view(norm_arr.tobytes(), 34962)
            uv_bv = add_buffer_view(uv_arr.tobytes(), 34962)
            idx_bv = add_buffer_view(idx_arr.tobytes(), 34963)

            pos_acc = len(accessors)
            accessors.append({
                "bufferView": pos_bv,
                "componentType": 5126,
                "count": len(v_pos),
                "type": "VEC3",
                "min": [float(x) for x in pos_arr.min(axis=0)],
                "max": [float(x) for x in pos_arr.max(axis=0)],
            })
            norm_acc = len(accessors)
            accessors.append({
                "bufferView": norm_bv,
                "componentType": 5126,
                "count": len(v_norm),
                "type": "VEC3",
            })
            uv_acc = len(accessors)
            accessors.append({
                "bufferView": uv_bv,
                "componentType": 5126,
                "count": len(v_uv),
                "type": "VEC2",
            })
            idx_acc = len(accessors)
            accessors.append({
                "bufferView": idx_bv,
                "componentType": 5125,
                "count": len(indices),
                "type": "SCALAR",
            })

            mat_idx = get_or_create_material(mat_name)
            primitives.append({
                "attributes": {
                    "POSITION": pos_acc,
                    "NORMAL": norm_acc,
                    "TEXCOORD_0": uv_acc,
                },
                "indices": idx_acc,
                "material": mat_idx,
            })

        if primitives:
            mesh_idx = len(meshes)
            meshes.append({"name": obj_name, "primitives": primitives})
            nodes.append({"name": obj_name, "mesh": mesh_idx})

    if not nodes:
        return False, "No valid primitives"

    while len(bin_chunks) % 4 != 0:
        bin_chunks.append(0)

    gltf = {
        "asset": {"version": "2.0", "generator": "Sabeltann HD Remake Pipeline"},
        "scene": 0,
        "scenes": [{"name": obj_path.stem, "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "textures": textures,
        "images": images,
        "samplers": samplers,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(bin_chunks)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "

    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_chunks)
    glb_path.parent.mkdir(parents=True, exist_ok=True)
    with open(glb_path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total_len))
        f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_chunks), 0x004E4942))
        f.write(bin_chunks)

    return True, f"{len(meshes)} meshes, {len(materials)} mats, {len(images)} HD textures"


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: upscale_and_pack_glb.py <input.obj> <output.glb>")
        sys.exit(1)
    ok, msg = build_glb(Path(sys.argv[1]), Path(sys.argv[2]))
    print(f"{'OK' if ok else 'FAIL'}: {msg}")
    sys.exit(0 if ok else 1)
