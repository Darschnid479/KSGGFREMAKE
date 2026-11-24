# Material- og Asset-register (KSGGFREMAKE — 2026 Stilisert 3D-nybygg)

Dette registeret dokumenterer samtlige nye lisensierte CC0-kildeteksturer som er lastet ned og
stilisert for 2026-grafikknybygget av *Kaptein Sabeltann og Grusomme Gabriels forbannelse*,
koblet direkte mot **faktisk kjørende sanntids-audit i Godot 4.7.2** for hvert brett.

## 1. Sammendrag

- **Aktivt koblede og synlige CC0-materialpakker i spillet:** **`29`** pakker (`Poly Haven` CC0 + `ambientCG` CC0; `3` ekstra nedlastede reservepakker i staging-mappen er IKKE talt som i bruk)
- **Ombygde 3D-modeller (GLB):** `43` modeller (`21` nivå-GLB inkl. fullstendig 82-mesh `world_map.glb` + `22` karakter-GLB)
- **Totalt katalogiserte materialflater:** `622` flater
  - Fullført med nye CC0 PBR-kart (Albedo + Normal + ORM): **`615`** flater
  - Midlertidig beholdt i påvente av norsk/høyoppløst originalreferanse (ikke talt som ferdig): **`7`** flater (se [`PENDING_REFERENCES.md`](PENDING_REFERENCES.md))
- **Faktisk viste 3D-mesher verifisert i sanntids-audit på tvers av 23 scener:** `1420` synlige mesher
- **Fjernede uoriginale tillegg:** Hele `assets/store/` (Poly Haven/KayKit 3D-rekvisitter, borger, nederlandske skip, bøyer), `assets/hdri/` (fotografiske bakgrunns-HDRI-er) og KI-genererte filmsekvensbilder/portretter er fjernet og erstattet med original-tro stilisert 3D og nybygde UI-ressurser.

## 2. Lisensiert CC0-teksturbibliotek (kilde, lisens og faktisk bruk)

| Pakkenøkkel | Leverandør | Asset-ID | Lisens | Brukt på (antall flater / GLB-er) | Kilde-URL |
|---|---|---|---|---|---|
| `bark_tree` | Poly Haven | `bark_brown_01` | CC0 1.0 Public Domain | **7** flater (`graal_bosslevel.glb`, `magakhan_beach.glb`, `magakhan_jungle.glb`, `magakhan_palace.glb` (+1 til)) | https://polyhaven.com/a/bark_brown_01 |
| `carpet_ornate` | ambientCG | `Carpet016` | CC0 1.0 Public Domain | **2** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_palace.glb`) | https://ambientcg.com/view?id=Carpet016 |
| `fabric_cloth` | Poly Haven | `denim_fabric` | CC0 1.0 Public Domain | **82** flater (`abra.glb`, `cave_end_bosslevel.glb`, `fatamorgana_city.glb`, `graal_bosslevel.glb` (+28 til)) | https://polyhaven.com/a/denim_fabric |
| `fabric_sail` | Poly Haven | `rough_linen` | CC0 1.0 Public Domain | **17** flater (`abra.glb`, `magakhan_beach.glb`, `outro.glb`, `treasurehunt.glb` (+1 til)) | https://polyhaven.com/a/rough_linen |
| `fabric_velvet` | Poly Haven | `velour_velvet` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/velour_velvet |
| `foliage_leaf` | ambientCG | `Leaf001` | CC0 1.0 Public Domain | **28** flater (`abra.glb`, `fatamorgana_underwater.glb`, `graal_underwater.glb`, `magakhan_beach.glb` (+7 til)) | https://ambientcg.com/view?id=Leaf001 |
| `grass_lush` | Poly Haven | `grass_ground` | CC0 1.0 Public Domain | **5** flater (`graal_bosslevel.glb`, `magakhan_jungle.glb`) | https://polyhaven.com/a/grass_ground |
| `lava_molten` | ambientCG | `Lava004` | CC0 1.0 Public Domain | **7** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `magakhan_dungeon.glb`) | https://ambientcg.com/view?id=Lava004 |
| `leather_smooth` | Poly Haven | `brown_leather` | CC0 1.0 Public Domain | **122** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+36 til)) | https://polyhaven.com/a/brown_leather |
| `marble_palace` | Poly Haven | `marble_01` | CC0 1.0 Public Domain | **5** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_palace.glb`) | https://polyhaven.com/a/marble_01 |
| `metal_iron` | Poly Haven | `metal_plate_02` | CC0 1.0 Public Domain | **209** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+33 til)) | https://polyhaven.com/a/metal_plate_02 |
| `metal_painted` | Poly Haven | `painted_metal_shutter` | CC0 1.0 Public Domain | **2** flater (`abra.glb`) | https://polyhaven.com/a/painted_metal_shutter |
| `net_rigging` | ambientCG | `Net002A` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://ambientcg.com/view?id=Net002A |
| `plaster_clean` | ambientCG | `Plaster001` | CC0 1.0 Public Domain | **118** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+36 til)) | https://ambientcg.com/view?id=Plaster001 |
| `plaster_smooth` | Poly Haven | `painted_plaster_wall` | CC0 1.0 Public Domain | **13** flater (`abra.glb`, `fatamorgana_city.glb`, `outro.glb`, `world_map.glb` (+1 til)) | https://polyhaven.com/a/painted_plaster_wall |
| `rock_cave` | Poly Haven | `rock_face_03` | CC0 1.0 Public Domain | **30** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `graal_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/rock_face_03 |
| `rock_cliff` | Poly Haven | `aerial_rocks_02` | CC0 1.0 Public Domain | **6** flater (`magakhan_jungle.glb`, `magakhan_palace.glb`) | https://polyhaven.com/a/aerial_rocks_02 |
| `roof_slate` | Poly Haven | `roof_slates_02` | CC0 1.0 Public Domain | **2** flater (`abra.glb`) | https://polyhaven.com/a/roof_slates_02 |
| `roof_terracotta` | Poly Haven | `clay_roof_tiles_02` | CC0 1.0 Public Domain | **5** flater (`abra.glb`, `magakhan_dungeon.glb`, `magakhan_endboss_level.glb`, `magakhan_jungle.glb` (+1 til)) | https://polyhaven.com/a/clay_roof_tiles_02 |
| `rope_braided` | ambientCG | `Rope001` | CC0 1.0 Public Domain | **9** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+2 til)) | https://ambientcg.com/view?id=Rope001 |
| `sand_beach` | Poly Haven | `coast_sand_01` | CC0 1.0 Public Domain | **18** flater (`cave.glb`, `cave_end.glb`, `fatamorgana_city.glb`, `graal_mountain.glb` (+5 til)) | https://polyhaven.com/a/coast_sand_01 |
| `sandstone_blocks` | Poly Haven | `sandstone_blocks_04` | CC0 1.0 Public Domain | **52** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `fatamorgana_bosslevel.glb` (+8 til)) | https://polyhaven.com/a/sandstone_blocks_04 |
| `stone_castle` | Poly Haven | `castle_wall_slates` | CC0 1.0 Public Domain | **46** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/castle_wall_slates |
| `stone_cobble` | Poly Haven | `cobblestone_04` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/cobblestone_04 |
| `stone_mossy` | Poly Haven | `mossy_stone_wall` | CC0 1.0 Public Domain | **10** flater (`graal_underwater.glb`, `magakhan_dungeon.glb`, `magakhan_dungeon_underwater.glb`, `magakhan_endboss_level.glb`) | https://polyhaven.com/a/mossy_stone_wall |
| `stone_slate_floor` | Poly Haven | `slate_floor_02` | CC0 1.0 Public Domain | **15** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/slate_floor_02 |
| `stucco_warm` | Poly Haven | `white_stucco` | CC0 1.0 Public Domain | **32** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_city.glb`, `fatamorgana_palace.glb`, `fatamorgana_underwater.glb`) | https://polyhaven.com/a/white_stucco |
| `wood_bamboo` | Poly Haven | `bamboo_wall` | CC0 1.0 Public Domain | **6** flater (`magakhan_dungeon.glb`, `magakhan_endboss_level.glb`) | https://polyhaven.com/a/bamboo_wall |
| `wood_fine_grain` | Poly Haven | `fine_grained_wood` | CC0 1.0 Public Domain | **34** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `fatamorgana_bosslevel.glb` (+10 til)) | https://polyhaven.com/a/fine_grained_wood |
| `wood_planks_dark` | Poly Haven | `dark_wooden_planks` | CC0 1.0 Public Domain | **14** flater (`abra.glb`, `graal_mountain.glb`, `magakhan_dungeon.glb`) | https://polyhaven.com/a/dark_wooden_planks |
| `wood_planks_painted` | Poly Haven | `blue_painted_planks` | CC0 1.0 Public Domain | **7** flater (`abra.glb`) | https://polyhaven.com/a/blue_painted_planks |
| `wood_planks_warm` | Poly Haven | `brown_planks_05` | CC0 1.0 Public Domain | **41** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `fatamorgana_bosslevel.glb` (+8 til)) | https://polyhaven.com/a/brown_planks_05 |

## 3. Sanntids-audit: Materialer og shadere faktisk vist under spilling

Hver rad under er generert direkte fra levende kjøring av scenen i Godot 4.7.2 (`work_refs/audit_after/*.json`),
inkludert materialer som byttes av kode (`VisualEnhancer.gd`, `LevelRunner.gd`, `CharacterAnimator.gd`, `BoatController.gd`)
og overstyres av egne shadere (`world_pbr_enhance.gdshader`, `character_anim.gdshader`, `outset_ocean_material.tres`, `stylized_sky.gdshader`, `storm_sky.gdshader`).

| Scene / Brett | Navn | Synlige 3D-mesher | Aktive CC0/PBR-teksturkoblinger | Aktive shadere / materialtyper |
|---|---|---:|---:|---|
| `main_menu` | Hovedmeny (Abra Havn natt) | 14 | 358 | `world_pbr_enhance.gdshader` (110), `StandardMaterial3D` (7), `ocean_water.gdshader` (1) |
| `cave` | 01. Grusomme Gabriels grotte | 130 | 655 | `StandardMaterial3D` (100), `world_pbr_enhance.gdshader` (71), `character_anim.gdshader` (16) |
| `abra` | 02. Abra Havn | 67 | 445 | `world_pbr_enhance.gdshader` (110), `StandardMaterial3D` (49), `character_anim.gdshader` (19), `water.gdshader` (1) |
| `world_map` | 03. Verdenskartet – De Syv Hav | 61 | 260 | `StandardMaterial3D` (37), `world_pbr_enhance.gdshader` (25), `ship_wake.gdshader` (5), `water.gdshader` (1) |
| `graal_mountain` | 04. Gral-fjellet | 83 | 330 | `world_pbr_enhance.gdshader` (66), `StandardMaterial3D` (65), `character_anim.gdshader` (7), `water.gdshader` (1) |
| `graal_underwater` | 05. Gral – Undervannsbrønnen (2D) | 22 | 57 | `StandardMaterial3D` (19), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `graal_bosslevel` | 06. Gral – Bosskamp | 38 | 85 | `StandardMaterial3D` (35), `world_pbr_enhance.gdshader` (13), `character_anim.gdshader` (4) |
| `fatamorgana_city` | 07. Fata Morgana – Byen | 75 | 271 | `world_pbr_enhance.gdshader` (55), `StandardMaterial3D` (51), `character_anim.gdshader` (22), `water.gdshader` (1) |
| `fatamorgana_underwater` | 08. Fata Morgana – Brønndykk (2D) | 16 | 39 | `StandardMaterial3D` (12), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `fatamorgana_palace` | 09. Fata Morgana – Palasset | 118 | 834 | `world_pbr_enhance.gdshader` (207), `StandardMaterial3D` (83), `character_anim.gdshader` (10) |
| `fatamorgana_bosslevel` | 10. Fata Morgana – Bosskamp | 47 | 179 | `world_pbr_enhance.gdshader` (32), `StandardMaterial3D` (23), `character_anim.gdshader` (4) |
| `magakhan_beach` | 11. Maga Khans strand | 44 | 130 | `StandardMaterial3D` (26), `world_pbr_enhance.gdshader` (18), `character_anim.gdshader` (18), `water.gdshader` (1) |
| `magakhan_jungle` | 12. Maga Khans jungel | 83 | 751 | `world_pbr_enhance.gdshader` (151), `StandardMaterial3D` (82), `character_anim.gdshader` (35) |
| `magakhan_palace` | 13. Maga Khans palass | 104 | 457 | `world_pbr_enhance.gdshader` (133), `StandardMaterial3D` (36), `character_anim.gdshader` (19) |
| `magakhan_dungeon` | 14. Maga Khans fangehull | 143 | 984 | `world_pbr_enhance.gdshader` (208), `StandardMaterial3D` (89), `character_anim.gdshader` (28) |
| `magakhan_dungeon_underwater` | 15. Maga Khans fangehull – Nøkkeldykk (2D) | 63 | 109 | `StandardMaterial3D` (59), `world_pbr_enhance.gdshader` (6), `swimmer_anim.gdshader` (4) |
| `magakhan_endboss_level` | 16. Maga Khans drage – Sluttkamp | 29 | 130 | `world_pbr_enhance.gdshader` (29), `StandardMaterial3D` (10), `character_anim.gdshader` (10) |
| `cave_end` | 17. Tilbake til Gabriels grotte | 120 | 570 | `StandardMaterial3D` (100), `world_pbr_enhance.gdshader` (59), `character_anim.gdshader` (14) |
| `cave_end_bosslevel` | 18. Grusomme Gabriels spøkelse – Finale | 47 | 200 | `world_pbr_enhance.gdshader` (29), `StandardMaterial3D` (24), `character_anim.gdshader` (5) |
| `treasurehunt` | 19. Skattejakt-øya | 20 | 88 | `world_pbr_enhance.gdshader` (11), `StandardMaterial3D` (10), `character_anim.gdshader` (6), `water.gdshader` (1) |
| `world_map_underwater` | 20. De Syv Hav – Skipsvrak-dykk (2D) | 40 | 89 | `StandardMaterial3D` (36), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `swimming` | 21. Undervannsdykk (2D) | 21 | 83 | `StandardMaterial3D` (17), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `outro` | 22. Outro – Forbannelsen er brutt! | 35 | 137 | `world_pbr_enhance.gdshader` (28), `StandardMaterial3D` (18), `character_anim.gdshader` (4), `water.gdshader` (1) |

## 4. Ressurser lastet fra kode (UI, HUD, hav, himmel og filmsekvenser)

- **HUD & menyer (`godot_project/assets/ui/`):** 29 nybygde høyoppløselige 2026-stiliserte UI-ressurser rekonstruert 1:1 fra originale 2007 Cast-bitmaps over nye CC0 gull- og pergamentunderlag (`hud_pinky_medallion.png`, `hud_ship_medallion.png`, `hud_healthbar_full.png`, `gold_doubloon.png`, `silver_coin.png`, `hud_action_*.png`, `hud_boss_{graal,cave,fatamorgana,mk}.png`, `hud_underwater_bar.png`, `world_map_overlay.png`, `menu_islands_overlay.png`) + 5 norske bue-kalligrafiske sjøkarttitler (`map_text{abra,fatamorgana,graal,shangrila,skjebnegrotten}.png`).
- **Runtime CC0 PBR-kart (`godot_project/assets/textures/pbr/`):** 6 kompakte stiliserte CC0-sett (`cutaway_bedrock`, `wood_planks`, `rock_natural`, `coast_sand`, `fabric_detail`, `forged_metal`) brukt til 2D-undervanns-tverrsnitt, ødeleggbare tønner, sabelklinge og ankringsmarkører.
- **Filmsekvenser (`godot_project/assets/cutscenes/01..07*.jpg`):** Alle 7 filmsekvensplatene er erstattet med ekte 3D-renders rett fra de nybygde 2026-nivåene og -karakterene i Godot — ingen KI-genererte tolkninger gjenstår.
- **Shadere som overstyrer importerte materialer:**
  - `res://shaders/world_pbr_enhance.gdshader` — leser de bakte CC0 Albedo/Normal/ORM-teksturene direkte uten fotorealistisk overflatestøy; bruker kun stilisert lagdelt fjelltekstur på 2D undervanns-tverrsnitt (`blackwall`).
  - `res://shaders/character_anim.gdshader` — sanntids skjelettdeformasjon + per-karakter semantiske CC0 Normal/ORM-kart med varm hud-SSS (`BACKLIGHT`), matt stoff, lær og blankt metall.
  - `res://shaders/stylized_sky.gdshader` & `res://shaders/storm_sky.gdshader` — erstatter alle fotografiske HDRI-himler med originale 2007-fargeskript per biom.
