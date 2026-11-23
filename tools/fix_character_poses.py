#!/usr/bin/env python3
"""
Converts static T-pose humanoid .glb characters into natural relaxed stances
using smooth shoulder-skinned rotation + subtle elbow bend + matching normal
rotation, updating glTF accessor min/max bounds cleanly.
"""
import json
import math
import struct
from pathlib import Path
import numpy as np

MODELS_DIR = Path("/home/antigravity/sabeltann_remake/godot_project/assets/models")

NON_HUMANOIDS = {"dog", "panther", "meatplant", "movablecrate"}
PROP_MESH_SUBSTRS = (
    "crosshair", "lamp", "shovel", "slingshot", "swoosh", "rapier", "sword", "bowl"
)


def smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def deform_humanoid_glb(glb_path: Path, drop_deg: float = 68.0, forward_deg: float = 12.0) -> str:
    raw = bytearray(glb_path.read_bytes())
    magic, version, total_len = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF":
        return "not a GLB"

    jlen, jtype = struct.unpack_from("<II", raw, 12)
    gltf = json.loads(raw[20 : 20 + jlen].decode("utf-8"))
    if gltf.get("asset", {}).get("extras", {}).get("poseFixed"):
        return "already pose-fixed"

    bin_hdr_off = 20 + jlen
    blen, btype = struct.unpack_from("<II", raw, bin_hdr_off)
    bin_off = bin_hdr_off + 8

    # Find main humanoid body mesh (exclude props like rapier/lamp/shovel)
    body_meshes = []
    for mi, m in enumerate(gltf.get("meshes", [])):
        nm = m.get("name", "").lower()
        if any(sub in nm for sub in PROP_MESH_SUBSTRS):
            continue
        body_meshes.append(mi)
    if not body_meshes:
        return "no body mesh"

    # Gather all body positions to measure torso & shoulder anatomy
    all_pts = []
    for mi in body_meshes:
        for pr in gltf["meshes"][mi].get("primitives", []):
            acc = gltf["accessors"][pr["attributes"]["POSITION"]]
            bv = gltf["bufferViews"][acc["bufferView"]]
            off = bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            arr = np.frombuffer(raw, dtype=np.float32, count=acc["count"] * 3, offset=off).reshape(-1, 3)
            all_pts.append(arr)
    pts = np.vstack(all_pts)

    ymin, ymax = float(pts[:, 1].min()), float(pts[:, 1].max())
    h = ymax - ymin
    max_abs_x = float(np.abs(pts[:, 0]).max())
    # Skip if character is not in T-pose (arm span < 0.65 * height)
    if max_abs_x * 2.0 < h * 0.65:
        return f"not T-pose (span={max_abs_x*2:.2f}, H={h:.2f})"

    # Measure ribcage/waist half-width in Yfrac [0.50, 0.59]
    torso_mask = (pts[:, 1] >= ymin + 0.50 * h) & (pts[:, 1] <= ymin + 0.59 * h)
    if torso_mask.sum() < 6:
        torso_mask = (pts[:, 1] >= ymin + 0.45 * h) & (pts[:, 1] <= ymin + 0.60 * h)
    torso_half_w = float(np.percentile(np.abs(pts[torso_mask, 0]), 92)) if torso_mask.any() else h * 0.14
    torso_half_w = max(h * 0.09, min(torso_half_w, h * 0.24))

    # Measure arm centerline Y and Z from vertices clearly on the outstretched arms
    arm_band = (pts[:, 1] >= ymin + 0.60 * h) & (pts[:, 1] <= ymin + 0.83 * h) & (np.abs(pts[:, 0]) > torso_half_w * 1.25)
    if arm_band.sum() < 10:
        return "no arm vertices detected"

    shoulder_y = float(np.median(pts[arm_band, 1]))
    shoulder_z = float(np.median(pts[arm_band, 2]))
    shoulder_x = torso_half_w * 0.88
    arm_reach = max(max_abs_x - shoulder_x, 0.15 * h)

    drop_rad = math.radians(drop_deg)
    fwd_rad = math.radians(forward_deg)

    # Apply smooth skinned deformation to each body primitive (positions + normals)
    deformed_verts = 0
    for mi in body_meshes:
        for pr in gltf["meshes"][mi].get("primitives", []):
            p_acc_idx = pr["attributes"]["POSITION"]
            p_acc = gltf["accessors"][p_acc_idx]
            p_bv = gltf["bufferViews"][p_acc["bufferView"]]
            p_off = bin_off + p_bv.get("byteOffset", 0) + p_acc.get("byteOffset", 0)
            pos = np.frombuffer(raw, dtype=np.float32, count=p_acc["count"] * 3, offset=p_off).reshape(-1, 3).copy()

            n_acc_idx = pr["attributes"].get("NORMAL")
            has_n = n_acc_idx is not None
            if has_n:
                n_acc = gltf["accessors"][n_acc_idx]
                n_bv = gltf["bufferViews"][n_acc["bufferView"]]
                n_off = bin_off + n_bv.get("byteOffset", 0) + n_acc.get("byteOffset", 0)
                nrm = np.frombuffer(raw, dtype=np.float32, count=n_acc["count"] * 3, offset=n_off).reshape(-1, 3).copy()

            ax = np.abs(pos[:, 0])
            sign_x = np.where(pos[:, 0] >= 0.0, 1.0, -1.0)

            # Vertical mask: strictly arm height band (avoid hips/skirt/legs & head)
            vy_lo = smoothstep(ymin + 0.56 * h, ymin + 0.63 * h, pos[:, 1])
            vy_hi = 1.0 - smoothstep(ymin + 0.80 * h, ymin + 0.86 * h, pos[:, 1])
            wy = vy_lo * vy_hi

            # Horizontal smooth shoulder weight
            wx = smoothstep(shoulder_x * 0.72, shoulder_x * 1.32, ax)
            w = wx * wy

            active = w > 1e-4
            if not active.any():
                continue
            deformed_verts += int(active.sum())

            # Local vector relative to left/right shoulder pivot
            px = sign_x * shoulder_x
            dx = pos[:, 0] - px
            dy = pos[:, 1] - shoulder_y
            dz = pos[:, 2] - shoulder_z

            # Rotate downward in XY plane around shoulder pivot:
            # Right arm (+X): clockwise rotation (-ang) moves +X toward -Y
            # Left arm (-X): counter-clockwise rotation (+ang) moves -X toward -Y
            ang = -sign_x * w * drop_rad
            ca = np.cos(ang)
            sa = np.sin(ang)

            rx = dx * ca - dy * sa
            ry = dx * sa + dy * ca
            rz = dz

            # Gentle natural forward swing around X axis (arms slightly forward) + subtle elbow bend
            elbow_w = smoothstep(shoulder_x + 0.32 * arm_reach, shoulder_x + 0.85 * arm_reach, ax) * wy
            fang = (w * fwd_rad) + (elbow_w * math.radians(14.0))
            cf = np.cos(fang)
            sf = np.sin(fang)
            # Rotate (ry, rz) slightly forward (towards +Z or -Z; Pinky faces +Z in W3D->glTF? Wait: check Z!)
            # Actually pull hands slightly inward along X and forward toward body front
            ry2 = ry * cf - rz * sf
            rz2 = ry * sf + rz * cf

            pos[active, 0] = (px + rx)[active]
            pos[active, 1] = (shoulder_y + ry2)[active]
            pos[active, 2] = (shoulder_z + rz2)[active]

            # Update buffer + accessor bounds
            raw[p_off : p_off + pos.nbytes] = pos.astype(np.float32).tobytes()
            p_acc["min"] = [float(pos[:, 0].min()), float(pos[:, 1].min()), float(pos[:, 2].min())]
            p_acc["max"] = [float(pos[:, 0].max()), float(pos[:, 1].max()), float(pos[:, 2].max())]

            if has_n:
                nx, ny, nz = nrm[:, 0], nrm[:, 1], nrm[:, 2]
                rnx = nx * ca - ny * sa
                rny = nx * sa + ny * ca
                rny2 = rny * cf - nz * sf
                rnz2 = rny * sf + nz * cf
                out_n = np.stack([rnx, rny2, rnz2], axis=1)
                lens = np.linalg.norm(out_n, axis=1, keepdims=True)
                out_n = np.where(lens > 1e-6, out_n / np.maximum(lens, 1e-6), nrm)
                nrm[active] = out_n[active]
                raw[n_off : n_off + nrm.nbytes] = nrm.astype(np.float32).tobytes()

    # Mark poseFixed in JSON and rebuild GLB cleanly
    gltf.setdefault("asset", {}).setdefault("extras", {})["poseFixed"] = True
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "
    bin_bytes = bytes(raw[bin_off : bin_off + blen])
    while len(bin_bytes) % 4 != 0:
        bin_bytes += b"\x00"

    new_total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, new_total)
    out += struct.pack("<II", len(json_bytes), 0x4E4F534A)
    out += json_bytes
    out += struct.pack("<II", len(bin_bytes), 0x004E4942)
    out += bin_bytes
    glb_path.write_bytes(out)
    return f"fixed {deformed_verts} arm verts (shoulder_x={shoulder_x:.2f}, shoulder_y={shoulder_y:.2f})"


def main():
    for glb in sorted(MODELS_DIR.glob("*.glb")):
        if glb.stem in NON_HUMANOIDS:
            print(f"[SKIP] {glb.name} (non-humanoid)")
            continue
        msg = deform_humanoid_glb(glb)
        print(f"[POSE] {glb.name:22s} -> {msg}")


if __name__ == "__main__":
    main()
