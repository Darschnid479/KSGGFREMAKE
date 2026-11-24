# Material- og Asset-register (KSGGFREMAKE — 2026 Ultra-HD 4K Stilisert 3D-nybygg)

Dette registeret dokumenterer samtlige nye lisensierte **4K (`4096×4096`) CC0-kildeteksturer og 4K PureSky-himmelpanoramer**
som er lastet ned og brukt i 2026 Ultra-HD-nybygget av *Kaptein Sabeltann og Grusomme Gabriels forbannelse*,
koblet direkte mot **faktisk kjørende sanntids-audit i Godot 4.7.2** for hvert brett.

## 1. Sammendrag

- **Aktivt koblede og synlige 4K CC0-pakker i spillet:** **`35`** pakker (`Poly Haven` 4K CC0 + `ambientCG` 4K CC0; `9` ubrukte reserver er IKKE talt som i bruk)
- **Ombygde 3D-modeller (GLB):** `43` modeller (`21` nivå-GLB inkl. fullstendig 82-mesh `world_map.glb` + `22` høy-poly karakter-GLB med 2-nivås Curved PN-Triangle + Taubin-skulpturering og topologiske `COLOR_0`-knokkelvekter)
- **Totalt katalogiserte materialflater:** `616` flater (oppløsningsfordeling: `199` flater i **4K**, `347` flater i **2K**, `70` FX/bakgrunn/smådekal)
  - Fullført med nye skarpe 4K/2K CC0 PBR-kart (Albedo + RGTC/BC5 Normal + ORM): **`609`** flater
  - Midlertidig beholdt i påvente av norsk/høyoppløst originalreferanse (ikke talt som ferdig): **`7`** flater (se [`PENDING_REFERENCES.md`](PENDING_REFERENCES.md))
- **Faktisk viste 3D-mesher verifisert i sanntids-audit på tvers av 23 scener:** `1423` synlige mesher

## 2. Lisensiert 4K CC0-tekstur- og himmelbibliotek (kilde, lisens og faktisk bruk)

| Pakkenøkkel | Leverandør | Asset-ID | Lisens | Brukt på (antall flater / filer) | Kilde-URL |
|---|---|---|---|---|---|
| `bark_tree` | Poly Haven | `bark_brown_01` | CC0 1.0 Public Domain | **7** flater (`graal_bosslevel.glb`, `magakhan_beach.glb`, `magakhan_jungle.glb`, `magakhan_palace.glb` (+1 til)) | https://polyhaven.com/a/bark_brown_01 |
| `carpet_ornate` | ambientCG | `Carpet016` | CC0 1.0 Public Domain | **4** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_city.glb`, `fatamorgana_palace.glb`) | https://ambientcg.com/view?id=Carpet016 |
| `desert_sky` | Poly Haven | `syferfontein_18d_clear_puresky` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/syferfontein_18d_clear_puresky |
| `fabric_cloth` | Poly Haven | `denim_fabric` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/denim_fabric |
| `fabric_cotton` | ambientCG | `Fabric030` | CC0 1.0 Public Domain | **18** flater (`arab_guard1.glb`, `benjamin.glb`, `langemann.glb`, `maga_khan.glb` (+8 til)) | https://ambientcg.com/view?id=Fabric030 |
| `fabric_fur` | ambientCG | `Fabric061` | CC0 1.0 Public Domain | **2** flater (`dog.glb`, `panther.glb`) | https://ambientcg.com/view?id=Fabric061 |
| `fabric_sail` | Poly Haven | `rough_linen` | CC0 1.0 Public Domain | **37** flater (`abra.glb`, `magakhan_beach.glb`, `outro.glb`, `treasurehunt.glb` (+14 til)) | https://polyhaven.com/a/rough_linen |
| `fabric_velvet` | Poly Haven | `velour_velvet` | CC0 1.0 Public Domain | **9** flater (`chiefs_daughter.glb`, `maga_khan.glb`, `malena.glb`, `miriam.glb` (+3 til)) | https://polyhaven.com/a/velour_velvet |
| `foliage_leaf` | ambientCG | `Leaf001` | CC0 1.0 Public Domain | **27** flater (`abra.glb`, `fatamorgana_underwater.glb`, `graal_underwater.glb`, `magakhan_beach.glb` (+6 til)) | https://ambientcg.com/view?id=Leaf001 |
| `grass_lush` | Poly Haven | `grass_ground` | CC0 1.0 Public Domain | **5** flater (`graal_bosslevel.glb`, `magakhan_jungle.glb`) | https://polyhaven.com/a/grass_ground |
| `lava_molten` | ambientCG | `Lava004` | CC0 1.0 Public Domain | **7** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `magakhan_dungeon.glb`) | https://ambientcg.com/view?id=Lava004 |
| `leather_smooth` | Poly Haven | `brown_leather` | CC0 1.0 Public Domain | **41** flater (`graal_bosslevel.glb`, `magakhan_endboss_level.glb`, `magakhan_jungle.glb`, `treasurehunt.glb` (+20 til)) | https://polyhaven.com/a/brown_leather |
| `marble_palace` | Poly Haven | `marble_01` | CC0 1.0 Public Domain | **5** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_palace.glb`) | https://polyhaven.com/a/marble_01 |
| `metal_gold` | ambientCG | `Metal034` | CC0 1.0 Public Domain | **41** flater (`abra.glb`, `graal_mountain.glb`, `outro.glb`, `treasurehunt.glb` (+19 til)) | https://ambientcg.com/view?id=Metal034 |
| `metal_iron` | Poly Haven | `metal_plate_02` | CC0 1.0 Public Domain | **72** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `fatamorgana_bosslevel.glb` (+11 til)) | https://polyhaven.com/a/metal_plate_02 |
| `metal_painted` | Poly Haven | `painted_metal_shutter` | CC0 1.0 Public Domain | **2** flater (`abra.glb`) | https://polyhaven.com/a/painted_metal_shutter |
| `metal_plate` | Poly Haven | `metal_plate` | CC0 1.0 Public Domain | **3** flater (`pinky.glb`, `sabeltann.glb`) | https://polyhaven.com/a/metal_plate |
| `night_clouds` | Poly Haven | `qwantani_night_puresky` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/qwantani_night_puresky |
| `overcast_mist` | Poly Haven | `kloofendal_overcast_puresky` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/kloofendal_overcast_puresky |
| `plaster_clean` | ambientCG | `Plaster001` | CC0 1.0 Public Domain | **110** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+32 til)) | https://ambientcg.com/view?id=Plaster001 |
| `plaster_smooth` | Poly Haven | `painted_plaster_wall` | CC0 1.0 Public Domain | **22** flater (`abra.glb`, `fatamorgana_city.glb`, `outro.glb`, `world_map.glb` (+1 til)) | https://polyhaven.com/a/painted_plaster_wall |
| `rock_boulder` | Poly Haven | `rock_boulder_dry` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/rock_boulder_dry |
| `rock_cave` | Poly Haven | `rock_face_03` | CC0 1.0 Public Domain | **30** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `graal_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/rock_face_03 |
| `rock_cliff` | Poly Haven | `cliff_side` | CC0 1.0 Public Domain | **6** flater (`magakhan_jungle.glb`, `magakhan_palace.glb`) | https://polyhaven.com/a/cliff_side |
| `roof_slate` | Poly Haven | `roof_slates_02` | CC0 1.0 Public Domain | **2** flater (`abra.glb`) | https://polyhaven.com/a/roof_slates_02 |
| `roof_terracotta` | Poly Haven | `clay_roof_tiles_02` | CC0 1.0 Public Domain | **5** flater (`abra.glb`, `magakhan_dungeon.glb`, `magakhan_endboss_level.glb`, `magakhan_jungle.glb` (+1 til)) | https://polyhaven.com/a/clay_roof_tiles_02 |
| `rope_braided` | ambientCG | `Rope001` | CC0 1.0 Public Domain | **9** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+2 til)) | https://ambientcg.com/view?id=Rope001 |
| `sand_beach` | Poly Haven | `coast_sand_01` | CC0 1.0 Public Domain | **19** flater (`cave.glb`, `cave_end.glb`, `fatamorgana_city.glb`, `graal_mountain.glb` (+5 til)) | https://polyhaven.com/a/coast_sand_01 |
| `sandstone_blocks` | Poly Haven | `sandstone_blocks_04` | CC0 1.0 Public Domain | **58** flater (`cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb`, `fatamorgana_bosslevel.glb` (+9 til)) | https://polyhaven.com/a/sandstone_blocks_04 |
| `stone_castle` | Poly Haven | `castle_wall_slates` | CC0 1.0 Public Domain | **9** flater (`graal_bosslevel.glb`, `graal_mountain.glb`) | https://polyhaven.com/a/castle_wall_slates |
| `stone_cobble` | Poly Haven | `cobblestone_04` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/cobblestone_04 |
| `stone_medieval` | Poly Haven | `medieval_blocks_05` | CC0 1.0 Public Domain | **44** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/medieval_blocks_05 |
| `stone_mossy` | Poly Haven | `mossy_stone_wall` | CC0 1.0 Public Domain | **13** flater (`graal_underwater.glb`, `magakhan_dungeon.glb`, `magakhan_dungeon_underwater.glb`, `magakhan_endboss_level.glb`) | https://polyhaven.com/a/mossy_stone_wall |
| `stone_slate_floor` | Poly Haven | `slate_floor_02` | CC0 1.0 Public Domain | **15** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `cave_end_bosslevel.glb` (+5 til)) | https://polyhaven.com/a/slate_floor_02 |
| `stone_wall` | Poly Haven | `stone_wall` | CC0 1.0 Public Domain | **2** flater (`abra.glb`) | https://polyhaven.com/a/stone_wall |
| `storm_clouds` | Poly Haven | `approaching_storm` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/approaching_storm |
| `stucco_warm` | Poly Haven | `white_stucco` | CC0 1.0 Public Domain | **37** flater (`fatamorgana_bosslevel.glb`, `fatamorgana_city.glb`, `fatamorgana_palace.glb`, `fatamorgana_underwater.glb`) | https://polyhaven.com/a/white_stucco |
| `sunset_drama` | Poly Haven | `belfast_sunset_puresky` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/belfast_sunset_puresky |
| `tropical_clouds` | Poly Haven | `kloofendal_38d_partly_cloudy_puresky` | CC0 1.0 Public Domain | *0 flater — reserve i staging (ikke i bruk)* | https://polyhaven.com/a/kloofendal_38d_partly_cloudy_puresky |
| `wood_bamboo` | Poly Haven | `bamboo_wall` | CC0 1.0 Public Domain | **6** flater (`magakhan_dungeon.glb`, `magakhan_endboss_level.glb`) | https://polyhaven.com/a/bamboo_wall |
| `wood_fine_grain` | Poly Haven | `fine_grained_wood` | CC0 1.0 Public Domain | **35** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `fatamorgana_bosslevel.glb` (+10 til)) | https://polyhaven.com/a/fine_grained_wood |
| `wood_planks_dark` | Poly Haven | `dark_wooden_planks` | CC0 1.0 Public Domain | **15** flater (`abra.glb`, `graal_mountain.glb`, `magakhan_dungeon.glb`) | https://polyhaven.com/a/dark_wooden_planks |
| `wood_planks_painted` | Poly Haven | `blue_painted_planks` | CC0 1.0 Public Domain | **10** flater (`abra.glb`, `fatamorgana_city.glb`) | https://polyhaven.com/a/blue_painted_planks |
| `wood_planks_warm` | Poly Haven | `brown_planks_05` | CC0 1.0 Public Domain | **49** flater (`abra.glb`, `cave.glb`, `cave_end.glb`, `fatamorgana_bosslevel.glb` (+8 til)) | https://polyhaven.com/a/brown_planks_05 |

## 3. Sanntids-audit: Materialer og shadere faktisk vist under spilling

| Scene / Brett | Navn | Synlige 3D-mesher | Aktive CC0/PBR-teksturkoblinger | Aktive shadere / materialtyper |
|---|---|---:|---:|---|
| `main_menu` | Hovedmeny (Abra Havn natt) | 14 | 344 | `world_pbr_enhance.gdshader` (110), `StandardMaterial3D` (7), `ocean_water.gdshader` (1) |
| `cave` | 01. Grusomme Gabriels grotte | 130 | 449 | `StandardMaterial3D` (100), `world_pbr_enhance.gdshader` (71), `character_anim.gdshader` (16) |
| `abra` | 02. Abra Havn | 67 | 431 | `world_pbr_enhance.gdshader` (110), `StandardMaterial3D` (49), `character_anim.gdshader` (19), `water.gdshader` (1) |
| `world_map` | 03. Verdenskartet – De Syv Hav | 61 | 151 | `StandardMaterial3D` (38), `world_pbr_enhance.gdshader` (25), `ship_wake.gdshader` (5), `water.gdshader` (1) |
| `graal_mountain` | 04. Gral-fjellet | 83 | 324 | `world_pbr_enhance.gdshader` (66), `StandardMaterial3D` (65), `character_anim.gdshader` (7), `water.gdshader` (1) |
| `graal_underwater` | 05. Gral – Undervannsbrønnen (2D) | 22 | 39 | `StandardMaterial3D` (19), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `graal_bosslevel` | 06. Gral – Bosskamp | 38 | 101 | `StandardMaterial3D` (51), `world_pbr_enhance.gdshader` (13), `character_anim.gdshader` (4) |
| `fatamorgana_city` | 07. Fata Morgana – Byen | 75 | 299 | `world_pbr_enhance.gdshader` (55), `StandardMaterial3D` (51), `character_anim.gdshader` (22), `water.gdshader` (1) |
| `fatamorgana_underwater` | 08. Fata Morgana – Brønndykk (2D) | 16 | 29 | `StandardMaterial3D` (12), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `fatamorgana_palace` | 09. Fata Morgana – Palasset | 118 | 786 | `world_pbr_enhance.gdshader` (207), `StandardMaterial3D` (83), `character_anim.gdshader` (10) |
| `fatamorgana_bosslevel` | 10. Fata Morgana – Bosskamp | 47 | 145 | `world_pbr_enhance.gdshader` (32), `StandardMaterial3D` (23), `character_anim.gdshader` (4) |
| `magakhan_beach` | 11. Maga Khans strand | 44 | 133 | `StandardMaterial3D` (26), `world_pbr_enhance.gdshader` (18), `character_anim.gdshader` (18), `water.gdshader` (1) |
| `magakhan_jungle` | 12. Maga Khans jungel | 83 | 668 | `world_pbr_enhance.gdshader` (151), `StandardMaterial3D` (82), `character_anim.gdshader` (35) |
| `magakhan_palace` | 13. Maga Khans palass | 104 | 468 | `world_pbr_enhance.gdshader` (133), `StandardMaterial3D` (36), `character_anim.gdshader` (19) |
| `magakhan_dungeon` | 14. Maga Khans fangehull | 143 | 856 | `world_pbr_enhance.gdshader` (208), `StandardMaterial3D` (89), `character_anim.gdshader` (28) |
| `magakhan_dungeon_underwater` | 15. Maga Khans fangehull – Nøkkeldykk (2D) | 63 | 67 | `StandardMaterial3D` (59), `world_pbr_enhance.gdshader` (6), `swimmer_anim.gdshader` (4) |
| `magakhan_endboss_level` | 16. Maga Khans drage – Sluttkamp | 29 | 126 | `world_pbr_enhance.gdshader` (29), `StandardMaterial3D` (10), `character_anim.gdshader` (10) |
| `cave_end` | 17. Tilbake til Gabriels grotte | 120 | 370 | `StandardMaterial3D` (100), `world_pbr_enhance.gdshader` (59), `character_anim.gdshader` (14) |
| `cave_end_bosslevel` | 18. Grusomme Gabriels spøkelse – Finale | 47 | 136 | `world_pbr_enhance.gdshader` (29), `StandardMaterial3D` (24), `character_anim.gdshader` (5) |
| `treasurehunt` | 19. Skattejakt-øya | 20 | 62 | `world_pbr_enhance.gdshader` (11), `StandardMaterial3D` (10), `character_anim.gdshader` (6), `water.gdshader` (1) |
| `world_map_underwater` | 20. De Syv Hav – Skipsvrak-dykk (2D) | 43 | 57 | `StandardMaterial3D` (39), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `swimming` | 21. Undervannsdykk (2D) | 21 | 49 | `StandardMaterial3D` (17), `world_pbr_enhance.gdshader` (5), `swimmer_anim.gdshader` (4) |
| `outro` | 22. Outro – Forbannelsen er brutt! | 35 | 117 | `world_pbr_enhance.gdshader` (28), `StandardMaterial3D` (18), `character_anim.gdshader` (4), `water.gdshader` (1) |

## 4. Ressurser lastet fra kode (4K triplanar PBR, 4K himler, UI og filmsekvenser)

- **Runtime 4K CC0 triplanar PBR-sett (`godot_project/assets/textures/pbr/`):** 20 skarpe 4K-sett (`rock_cave_4k`, `rock_boulder_4k`, `rock_cliff_4k`, `stone_castle_4k`, `stone_wall_4k`, `stone_mossy_4k`, `sandstone_4k`, `slate_floor_4k`, `wood_planks_4k`, `wood_dark_4k`, `coast_sand_4k`, `grass_lush_4k`, `marble_4k`, `cutaway_bedrock_4k` m.fl.) koblet med Reoriented Normal Mapping (RNM) i `world_pbr_enhance.gdshader`.
- **4K stiliserte 360°-biomhimler (`godot_project/assets/skies/`):** 7 nybygde `4096×2048` himmelpanoramer basert på Poly Haven CC0 PureSky-skyer med fjerne fjell-, klippe-, øy- og ørkensilhuetter (`sky_graal_storm_4k.png`, `sky_abra_twilight_4k.png`, `sky_abra_night_4k.png`, `sky_fatamorgana_4k.png`, `sky_tropical_4k.png`, `sky_jungle_4k.png`, `sky_outro_sunset_4k.png`) gjengitt via `stylized_pano_sky.gdshader`.
- **HUD, menyer & filmsekvenser:** 29 nybygde 2026-stiliserte UI-ressurser + 5 norske bue-kalligrafiske sjøkarttitler + alle 7 filmsekvensplatene gjengitt direkte fra 3D-brettene.
