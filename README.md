# Kaptein Sabeltann og Grusomme Gabriels forbannelse – HD Remake

![Godot 4](https://img.shields.io/badge/Engine-Godot%204.7%20(Forward%2B%20PBR)-478CBF?logo=godotengine&logoColor=white)
![Graphics](https://img.shields.io/badge/Grafikk-AAA%20Animasjons%2DPBR%20%7C%20AgX%20%7C%20SSIL-F5A623)
![Cutscenes](https://img.shields.io/badge/Filmsekvenser-7%20Animerte%20HD%2DKapitler-9B59B6)
![Platform](https://img.shields.io/badge/Plattform-Windows%20%7C%20Linux%20%7C%20macOS-2EA44F)
![Language](https://img.shields.io/badge/Spr%C3%A5k-Norsk-BA0C2F)

En moderne, frittstående **Godot 4 (Forward+ PBR)** nyversjon (*recompile / HD remake*) av 2005–2009 PC-klassikeren ***Kaptein Sabeltann og Grusomme Gabriels forbannelse*** – bygget direkte fra originalspillets dekompilerte Lingo-skript, 3D-verdener, karaktermodeller og originale lydspor, oppgradert til **moderne animasjonsspill-grafikk** (AgX, SSAO, SSIL indirekte lys, volumetrisk tåke, turkist skumhav og Pixar-inspirert belysning) med **100 % tro original historieflyt** og **7 oppskalerte animerte historie-filmsekvenser**.

![Hovedmeny – Abra Havn i solnedgang](docs/screenshots/01_main_menu.png)

---

## Ekte skjermbilder fra HD-remaken (Godot 4 Forward+)

| Abra Havn – ombord på *Den Sorte Dame* | De Syv Hav – Verdenskartet |
| :---: | :---: |
| ![Abra Havn](docs/screenshots/02_abra_havn.png) | ![Verdenskartet](docs/screenshots/03_world_map_sailing.png) |
| **Gral – 2D Undervanns-svømming i brønnen** | **Dragen løfter Pinky opp av brønnen til borgen** |
| ![Gral 2D Undervannsbrønn](docs/screenshots/08_graal_underwater_2d.png) | ![Dragen løfter Pinky fra brønnen](docs/screenshots/09_graal_well_dragon_cutscene.png) |
| **Gral – Bosskamp mot Greven av Gral på dragen** | **Fata Morgana – Ørkenbyen** |
| ![Gral Bossarena](docs/screenshots/05_graal_bosslevel.png) | ![Fata Morgana](docs/screenshots/04_fatamorgana_city.png) |
| **Finalen – Grusomme Gabriels spøkelse** | **Oppskalerte animerte historie-filmsekvenser** |
| ![Grusomme Gabriels finale](docs/screenshots/06_grusomme_gabriel_finale.png) | ![Animert filmsekvens](docs/screenshots/07_animated_cutscene.png) |

---

## Hva er modernisert i HD-remaken?

- **Moderne AAA animasjonsspill-grafikk (Godot 4.7 Forward+ PBR):**
  - **AgX Filmic tonemapping**, **SSAO**, **SSIL (sanntids indirekte bounce-lys)**, **Volumetrisk tåke**, **4K PCF5 myke skygger**, **MSAA 4x** og 16x anisotropisk filtrering.
  - **Malte volumetriske skyhimler** ([`stylized_sky.gdshader`](godot_project/shaders/stylized_sky.gdshader) & [`storm_sky.gdshader`](godot_project/shaders/storm_sky.gdshader)) + skummel normalmappet gotisk fjellkjede, forankrede ruin-vakttårn og forgrenede 3D-lynnedslag bak Gral-borgen.
  - **Neste-generasjons skumhav & skulpturerte øyer** ([`ocean_water.gdshader`](godot_project/shaders/ocean_water.gdshader), [`island_terrain.gdshader`](godot_project/shaders/island_terrain.gdshader) & [`ship_wake.gdshader`](godot_project/shaders/ship_wake.gdshader)) med ekte `DEPTH_TEXTURE`-absorpsjon, automatisk kystskum, bratte klippeterrasser og organiske V-kjølvann.
  - **Triplanar PBR mikrodetalj & Pixar karakter-kantglød** ([`world_pbr_enhance.gdshader`](godot_project/shaders/world_pbr_enhance.gdshader) & [`VisualEnhancer.gd`](godot_project/scripts/world/VisualEnhancer.gd)): skarpe nærdetaljer på treverk, stein og grotter, varme vinduer, brennende smijerns-fakkelfat, håndlagde eiketønner og pregede 3D-gullmynter.
- **4x Oppskalerte HD-teksturer + automatisk PBR-syntese:**
  - **18 originale 3D- og 2D-undervannsverdener** (inkludert `graal_underwater`, `fatamorgana_underwater`, `magakhan_dungeon_underwater` og `world_map_underwater`) og **22 karaktermodeller** konvertert fra Shockwave 3D (`.w3d`) til moderne glTF 2.0 (`.glb`) med 4x oppskalering, Normal Maps og ORM-kart, samt fikset T-pose på alle 19 humanoide karakterer og Greven av Gral på dragen.
- **Komplett 1:1 2D side-scrolling undervanns-svømming (`SwimmingController.gd` + `UnderwaterHazard.gd`):**
  - Tro port av originalens `mapManager_swimming.ls` og `swimmer.ls`: 2D XY-svømmekontroll med ekte originale spline-tunnelvegger, **luftmåler (`LUFT`)** i HUD, stigende luftboblesøyler, sjøminer, patruljerende haier og pirajaer, brønnkaken (`wellcake`), fangehullsnøkkelen (`key2`) og sunkne skattkister!
- **100 % original historieflyt + 7 oppskalerte animerte historie-filmsekvenser:**
  - Følger den eksakte originale historien steg-for-steg fra `gameplayw3ds/*.w3d` – inkludert hoppet ned i brønnen på Gral, 2D-svømmetunnelen og dragen med Greven av Gral som løfter Pinky rett opp av brønnen og flyr ham opp til Gral-borgen!
  - [`CutscenePlayer.gd`](godot_project/scripts/ui/CutscenePlayer.gd) spiller automatisk av **7 oppskalerte Pixar-stil 2.5D animerte filmsekvenser** (med autentisk Kaptein Sabeltann i hvit sminke, hatt og uniform, Ken Burns kamera-panorering, sanntids lyspartikler og norsk fortellertekst).
- **Original musikk og lydeffekter:** **92 rene OGG-lydspor og bakgrunnsmusikk** ekstrahert fra spillets originale `.cct`-arkiver for alle biomer (renset for russisk dubbing).

---

## 100 % Original historierekkefølge (fra start til slutt)

| # | Kapittel / Nivå | Historie, 2D-dykk & Animert filmsekvens |
|---:|---|---|
| 1 | **Grusomme Gabriels grotte** (`cave`) | *Filmsekvens 1:* Kisten åpnes og forbannelsen slippes løs! |
| 2 | **Abra Havn** (`abra`) | *Filmsekvens 2:* Miriam av Gral avslører de 3 øyene i krystallkulen |
| 3 | **De Syv Hav – Verdenskartet** (`world_map`) | Seil *Den Sorte Dame* ovenfra + **2D skipsvrak-dykk** (`world_map_underwater`) blant haier & pirajaer |
| 4 | **Gral-fjellet** (`graal_mountain`) | Klatretur med Pelle opp det forheksede fjellet til **brønnen (`actionable_well`)** |
| 5 | **Gral – Undervannsbrønnen (2D)** (`graal_underwater`) | **2D side-scrolling undervanns-svømming** gjennom U-tunnelen med luftmåler og boblesøyle! |
| 6 | **Gral – Bosskamp** (`graal_bosslevel`) | *Filmsekvens 3:* **Dragen med Greven av Gral løfter Pinky rett opp av brønnen og flyr ham opp til borgen** → Bosskamp med sverd & katapult! |
| 7 | **Fata Morgana – Byen & Brønndykk (2D)** (`fatamorgana_city` / `fatamorgana_underwater`) | *Filmsekvens 4:* Ørkenbyen, **2D brønndykk etter kaken (`wellcake`)**, kappkjøring og flygende teppe |
| 8 | **Fata Morgana – Palasset** (`fatamorgana_palace`) | Mørke haller, flisgåte og nøkkeljakten mot palassvokteren |
| 9 | **Fata Morgana – Bosskamp** (`fatamorgana_bosslevel`) | Oppgjøret i ørkenarenaen – låser opp Maga Khans øy |
| 10 | **Maga Khans strand** (`magakhan_beach`) | Landgang, Skalkens kokosnøtter, Malena Pirat og Benjamin |
| 11 | **Maga Khans jungel** (`magakhan_jungle`) | Panterfelle, kjøttetende plante og redning av Langemann |
| 12 | **Maga Khans palass** (`magakhan_palace`) | Storming av festningen og jakten på de 5 hellige gongene |
| 13 | **Maga Khans fangehull & Nøkkeldykk (2D)** (`magakhan_dungeon` / `magakhan_dungeon_underwater`) | Blå flammer, spaker, **2D undervanns-nøkkeldykk med sjøminer (`key2`)** og møtet med Sirikit |
| 14 | **Maga Khans drage – Sluttkamp** (`magakhan_endboss_level`) | *Filmsekvens 5:* Sabeltann mot Maga Khan mens Pinky distraherer dragen |
| 15 | **Tilbake til Gabriels grotte** (`cave_end`) | Siste kamp gjennom skjelettvaktene til skattkammeret |
| 16 | **Grusomme Gabriels spøkelse – Finale** (`cave_end_bosslevel`) | *Filmsekvens 6:* Finalen mot Grusomme Gabriels gjenferd og vokterstatuene |
| 17 | **Forbannelsen er brutt! (Outro)** (`outro`) | *Filmsekvens 7:* Seiersseilas mot solnedgangen → fritt spill, Skattejakt-øya & Skipsvrak-dykk |

---

## Kontroller

| Tast / Mus | Handling |
|---|---|
| `W A S D` / Piltaster | Beveg Pinky / styr *Den Sorte Dame* |
| `Shift` | Løp |
| `Mellomrom (Space)` | Hopp / avfyr bredsider / neste replikk i filmsekvenser |
| `Venstreklikk` / `F` | Angrip |
| `E` | Snakk med NPC-er / bruk portal / gå i land |
| `L` | Slå av/på lykten i mørke grotter |
| `Høyreklikk + mus` / `Q` `R` | Roter kamera (scrollhjul for zoom) |
| `ESC` | Pause og grafikkvalg (`Medium` / `High` / `Ultra`) / hopp over filmsekvens |

---

## Kom i gang (kjør eller bygg `.exe`)

1. Last ned **Godot 4** (4.3 eller nyere – testet og verifisert i **Godot 4.7.2-stable**) fra [godotengine.org](https://godotengine.org/).
2. Klon dette repoet:
   ```bash
   git clone https://github.com/Darschnid479/KSGGFREMAKE.git
   ```
3. Åpne Godot 4, klikk **Import** og velg `godot_project/project.godot`.
4. Trykk **F5** for å spille direkte – eller gå til **Project → Export** for å kompilere en frittstående **Windows `.exe`**, Linux eller macOS-kjørbar fil.

---

## Prosjektstruktur

```text
KSGGFREMAKE/
├── docs/screenshots/          # 7 ekte 1600x900 skjermbilder fra Godot 4 Forward+
├── godot_project/             # Komplett Godot 4-prosjekt
│   ├── project.godot          # Forward+ PBR, AgX, SSAO, SSIL, Volumetrisk tåke, MSAA 4x
│   ├── scenes/                # MainMenu.tscn & GameLevel.tscn
│   ├── scripts/
│   │   ├── autoload/          # LevelCatalog.gd, GameState.gd (100% historiemotor), AudioManager.gd
│   │   ├── player/            # PinkyController.gd, BoatController.gd, FollowCamera.gd
│   │   ├── world/             # LevelRunner.gd, VisualEnhancer.gd, NpcActor.gd, EnemyActor.gd, m.fl.
│   │   └── ui/                # MainMenu.gd, GameHUD.gd, CutscenePlayer.gd
│   ├── shaders/               # ocean_water, stylized_sky, storm_sky, island_terrain, world_pbr_enhance, ship_wake, cutscene_fx
│   ├── data/gameplay/         # 33 ekstraherte originale nivådata-JSON-er
│   └── assets/
│       ├── cutscenes/         # 7 oppskalerte Pixar-stil 1600x900 animerte historie-sekvenser
│       ├── levels/            # 14 HD PBR .glb-verdener
│       ├── models/            # 22 HD PBR .glb-karaktermodeller
│       ├── ui/                # Live-action/HD HUD-medaljong og preget gull-dublon
│       └── audio/             # 92 originale OGG-lydspor & bakgrunnsmusikk
├── data/                      # Dekompilerte metadata (spawns, skjeletter, heightmaps)
└── tools/                     # Reproduserbar W3D -> 4x HD PBR GLB, pose-fiks & lyd-pipeline
```

> **Merknad:** Dette er et ikke-kommersielt fan- og bevaringsprosjekt laget for å modernisere et eldre Shockwave 3D-spill på dagens maskinvare. Alle rettigheter til *Kaptein Sabeltann* tilhører sine respektive rettighetshavere.
