#!/usr/bin/env python3
"""
Extracts all scene graph nodes, transforms, userdata (spawns, triggers, portals,
collision circles, paths, scripted events), skeletons, and animations from
Shockwave 3D (.w3d) files, plus heightmap/terrainmap metadata from decompiled casts.
"""
import json
import math
import os
import re
import struct
from pathlib import Path

GAME_ROOT = Path("/home/antigravity/sabeltann_extracted/ProgramFiles/assets")
DECOMPILED_CASTS = Path("/home/antigravity/decompiled_casts")
OUT_DIR = Path("/home/antigravity/sabeltann_remake/data")


def parse_w3d_nodes(path: Path):
    data = path.read_bytes()
    pos = 0
    nodes = {}
    node_order = []
    skeletons = []
    animations = []

    while pos + 8 <= len(data):
        btype, dsize = struct.unpack_from("<II", data, pos)
        payload = data[pos + 8 : pos + 8 + dsize]
        dpad = (4 - (dsize % 4)) % 4
        pos += 8 + dsize + dpad

        if btype in (0xFFFFFF70, 0xFFFFFF71, 0xFFFFFF72, 0xFFFFFF74):
            kind = {
                0xFFFFFF70: "group",
                0xFFFFFF71: "light",
                0xFFFFFF72: "model",
                0xFFFFFF74: "camera",
            }[btype]
            try:
                off = 0
                nlen = struct.unpack_from("<H", payload, off)[0]; off += 2
                name = payload[off : off + nlen].decode("latin1", errors="replace"); off += nlen
                plen = struct.unpack_from("<H", payload, off)[0]; off += 2
                parent = payload[off : off + plen].decode("latin1", errors="replace"); off += plen
                ulen = struct.unpack_from("<H", payload, off)[0]; off += 2
                userdata = payload[off : off + ulen].decode("latin1", errors="replace"); off += ulen
                mat = list(struct.unpack_from("<16f", payload, off)) if off + 64 <= len(payload) else None
                key = name
                idx = 1
                while key in nodes:
                    idx += 1
                    key = f"{name}__{idx}"
                nodes[key] = {
                    "name": name,
                    "kind": kind,
                    "parent": parent,
                    "userdata": userdata.strip(),
                    "matrix": mat,
                }
                node_order.append(key)
            except Exception:
                pass
        elif btype == 0xFFFFFF4B:
            try:
                off = 0
                slen = struct.unpack_from("<H", payload, off)[0]; off += 2
                sname = payload[off : off + slen].decode("latin1", errors="replace"); off += slen
                nbones = struct.unpack_from("<I", payload, off)[0]; off += 4
                bones = []
                for _ in range(nbones):
                    if off + 2 > len(payload):
                        break
                    blen = struct.unpack_from("<H", payload, off)[0]; off += 2
                    bname = payload[off : off + blen].decode("latin1", errors="replace"); off += blen
                    parent_idx, length = struct.unpack_from("<if", payload, off); off += 8
                    bpos = list(struct.unpack_from("<3f", payload, off)); off += 12
                    brot = list(struct.unpack_from("<4f", payload, off)); off += 16
                    bflags = struct.unpack_from("<I", payload, off)[0]; off += 4
                    bones.append({
                        "name": bname,
                        "parent": parent_idx,
                        "length": length,
                        "pos": bpos,
                        "rot": brot,
                        "flags": bflags,
                    })
                skeletons.append({"name": sname, "bones": bones})
            except Exception:
                pass
        elif btype == 0xFFFFFF67:
            try:
                off = 0
                slen = struct.unpack_from("<H", payload, off)[0]; off += 2
                aname = payload[off : off + slen].decode("latin1", errors="replace"); off += slen
                ntracks = struct.unpack_from("<I", payload, off)[0]; off += 4
                animations.append({"name": aname, "tracks": ntracks, "size": dsize})
            except Exception:
                pass

    # Compute world positions by walking parent chain
    def mat_mul(a, b):
        # Column-major 4x4 (IFX/OpenGL style: translation in indices 12, 13, 14)
        out = [0.0] * 16
        for c in range(4):
            for r in range(4):
                s = 0.0
                for k in range(4):
                    s += a[k * 4 + r] * b[c * 4 + k]
                out[c * 4 + r] = s
        return out

    identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    name_lookup = {}
    for k in node_order:
        nm = nodes[k]["name"]
        if nm not in name_lookup:
            name_lookup[nm] = k

    world_mats = {}
    def get_world_mat(key, depth=0):
        if key in world_mats:
            return world_mats[key]
        if depth > 32 or key not in nodes:
            return identity
        n = nodes[key]
        local = n["matrix"] if n["matrix"] else identity
        p = n["parent"]
        if p and p != "World" and p in name_lookup and name_lookup[p] != key:
            pm = get_world_mat(name_lookup[p], depth + 1)
            wm = mat_mul(pm, local)
        else:
            wm = local
        world_mats[key] = wm
        return wm

    result_nodes = []
    for k in node_order:
        n = nodes[k]
        wm = get_world_mat(k)
        # Convert Shockwave Z-up (X, Y, Z) to Godot Y-up: (X, Z, -Y)
        sx, sy, sz = wm[12], wm[13], wm[14]
        result_nodes.append({
            "name": n["name"],
            "kind": n["kind"],
            "parent": n["parent"],
            "userdata": n["userdata"],
            "sw_pos": [round(sx, 3), round(sy, 3), round(sz, 3)],
            "godot_pos": [round(sx, 3), round(sz, 3), round(-sy, 3)],
        })

    return {
        "file": path.name,
        "nodes": result_nodes,
        "skeletons": skeletons,
        "animations": animations,
    }


def parse_heightmap_info(ls_path: Path):
    txt = ls_path.read_text(encoding="latin1", errors="replace")
    info = {}
    m = re.search(r"#baseHeight:\s*([-0-9.eE]+)", txt)
    if m:
        info["baseHeight"] = float(m.group(1))
    m = re.search(r"#unitsPerColor:\s*([-0-9.eE]+)", txt)
    if m:
        info["unitsPerColor"] = float(m.group(1))
    m = re.search(r"#topLeft:\s*vector\(\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)", txt)
    if m:
        info["topLeft"] = [float(m.group(1)), float(m.group(2))]
    m = re.search(r"#bottomRight:\s*vector\(\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)", txt)
    if m:
        info["bottomRight"] = [float(m.group(1)), float(m.group(2))]
    return info


def main():
    (OUT_DIR / "gameplay").mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "models_meta").mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "heightmaps").mkdir(parents=True, exist_ok=True)

    # 1. Gameplay W3Ds
    gp_summary = {}
    for p in sorted((GAME_ROOT / "gameplayw3ds").glob("*.w3d")):
        parsed = parse_w3d_nodes(p)
        level_id = p.stem.replace("_gameplay", "")
        out_file = OUT_DIR / "gameplay" / f"{level_id}.json"
        out_file.write_text(json.dumps(parsed, indent=2), encoding="utf-8")

        # Summarize key gameplay entities
        chars = [n["name"] for n in parsed["nodes"] if n["name"].lower().startswith("character_")]
        portals = [n["name"] for n in parsed["nodes"] if "portal" in n["name"].lower()]
        triggers = [n["name"] for n in parsed["nodes"] if "trigger" in n["name"].lower()]
        circles = [n["name"] for n in parsed["nodes"] if n["parent"].lower() == "collisiondata"]
        gp_summary[level_id] = {
            "total_nodes": len(parsed["nodes"]),
            "characters": chars,
            "portals": portals,
            "triggers": triggers,
            "collision_shapes": len(circles),
        }

    (OUT_DIR / "gameplay_summary.json").write_text(json.dumps(gp_summary, indent=2), encoding="utf-8")

    # 2. Model/Level W3D metadata (skeletons, animations, scene nodes)
    model_summary = {}
    for p in sorted((GAME_ROOT / "w3d").glob("*.w3d")):
        parsed = parse_w3d_nodes(p)
        out_file = OUT_DIR / "models_meta" / f"{p.stem}.json"
        out_file.write_text(json.dumps(parsed, indent=2), encoding="utf-8")
        model_summary[p.stem] = {
            "nodes": len(parsed["nodes"]),
            "skeletons": len(parsed["skeletons"]),
            "animations": [a["name"] for a in parsed["animations"]],
        }
    (OUT_DIR / "models_summary.json").write_text(json.dumps(model_summary, indent=2), encoding="utf-8")

    # 3. Heightmap info from decompiled casts
    hm_all = {}
    for ls_path in sorted(DECOMPILED_CASTS.rglob("*heightmap_info.ls")):
        # path is decompiled_casts/<level>/<level>/casts/...
        level_id = ls_path.relative_to(DECOMPILED_CASTS).parts[0]
        hm_all[level_id] = parse_heightmap_info(ls_path)
    (OUT_DIR / "heightmaps" / "heightmaps_info.json").write_text(json.dumps(hm_all, indent=2), encoding="utf-8")

    print(f"Extracted {len(gp_summary)} gameplay W3Ds, {len(model_summary)} model W3Ds, {len(hm_all)} heightmap configs.")


if __name__ == "__main__":
    main()
