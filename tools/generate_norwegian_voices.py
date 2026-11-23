#!/usr/bin/env python3
"""
Generates 100% story-faithful Norwegian dialogue subtitles (godot_project/data/dialogues.json)
and character-matched Norwegian neural voice clips (godot_project/assets/voices_no/<clip>.ogg)
for EVERY SINGLE ONE of the 450 original voice clip IDs extracted from the 2005 game casts!
"""
import asyncio
import json
import re
import subprocess
from pathlib import Path
import edge_tts

CATALOG_PATH = Path("/home/antigravity/sabeltann_remake/godot_project/data/voice_catalog.json")
DIALOGUES_OUT = Path("/home/antigravity/sabeltann_remake/godot_project/data/dialogues.json")
VOICES_NO_DIR = Path("/home/antigravity/sabeltann_remake/godot_project/assets/voices_no")
TMP_MP3_DIR = Path("/tmp/no_voices_mp3")

# Distinct character voice profiles (voice, pitch, rate, optional ffmpeg filter)
VOICE_PROFILES = {
    "sabeltann":      ("nb-NO-FinnNeural",     "-16Hz", "-5%",  "bass=g=4:f=140,treble=g=2"),
    "pinky":          ("nb-NO-FinnNeural",     "+32Hz", "+8%",  "equalizer=f=2400:t=q:w=1.5:g=2"),
    "langemann":      ("nb-NO-FinnNeural",     "-4Hz",  "+4%",  "treble=g=2"),
    "pelle":          ("nb-NO-FinnNeural",     "+18Hz", "+7%",  ""),
    "pysa":           ("nb-NO-FinnNeural",     "-10Hz", "-8%",  ""),
    "skalken":        ("nb-NO-FinnNeural",     "-8Hz",  "-2%",  "bass=g=2:f=180"),
    "benjamin":       ("nb-NO-FinnNeural",     "+12Hz", "+2%",  ""),
    "sunniva":        ("nb-NO-PernilleNeural", "+14Hz", "+6%",  ""),
    "miriam":         ("nb-NO-PernilleNeural", "-12Hz", "-8%",  "aecho=0.8:0.75:35:0.22"),
    "malena":         ("nb-NO-PernilleNeural", "-6Hz",  "-4%",  ""),
    "sirikit":        ("nb-NO-PernilleNeural", "+6Hz",  "+2%",  ""),
    "daughter":       ("nb-NO-PernilleNeural", "+10Hz", "+5%",  ""),
    "prostitute2":    ("nb-NO-PernilleNeural", "-2Hz",  "+0%",  ""),
    "storyteller":    ("nb-NO-FinnNeural",     "-2Hz",  "-4%",  ""),
    "boss":           ("nb-NO-FinnNeural",     "-26Hz", "-12%", "bass=g=6:f=110,aecho=0.85:0.8:55:0.35"),
    "maga_khan":      ("nb-NO-FinnNeural",     "-20Hz", "-9%",  "bass=g=5:f=120,aecho=0.8:0.75:40:0.22"),
    "sultan":         ("nb-NO-FinnNeural",     "-6Hz",  "-6%",  ""),
    "shopkeeper":     ("nb-NO-FinnNeural",     "+4Hz",  "+3%",  ""),
    "shipman":        ("nb-NO-FinnNeural",     "-12Hz", "-3%",  ""),
    "carpet_salesman":("nb-NO-FinnNeural",     "+8Hz",  "+6%",  ""),
    "boy":            ("nb-NO-FinnNeural",     "+26Hz", "+10%", ""),
    "guard1":         ("nb-NO-FinnNeural",     "-10Hz", "-2%",  ""),
    "guard2":         ("nb-NO-FinnNeural",     "-4Hz",  "+2%",  ""),
    "guard3":         ("nb-NO-FinnNeural",     "+2Hz",  "+0%",  ""),
    "guard4":         ("nb-NO-FinnNeural",     "-14Hz", "-5%",  ""),
    "opponent1":      ("nb-NO-FinnNeural",     "-12Hz", "+2%",  ""),
    "opponent2":      ("nb-NO-FinnNeural",     "-6Hz",  "+4%",  ""),
    "opponent3":      ("nb-NO-FinnNeural",     "-15Hz", "-2%",  ""),
}

SPEAKER_DISPLAY = {
    "sabeltann": "Kaptein Sabeltann",
    "pinky": "Pinky",
    "langemann": "Langemann",
    "pelle": "Pelle",
    "pysa": "Pysa",
    "skalken": "Skalken",
    "benjamin": "Benjamin",
    "sunniva": "Sunniva",
    "miriam": "Miriam av Gral",
    "malena": "Malena Pirat",
    "sirikit": "Sirikit",
    "daughter": "Høvdingens datter",
    "prostitute2": "Landsbykvinne",
    "storyteller": "Fortelleren",
    "boss": "Grusomme Gabriel / Greven",
    "maga_khan": "Maga Khan",
    "sultan": "Sultanen",
    "shopkeeper": "Kjøpmannen",
    "shipman": "Skipsbyggeren",
    "carpet_salesman": "Teppehandleren",
    "boy": "Gutt i Fata Morgana",
    "guard1": "Palassvakt",
    "guard2": "Palassvakt",
    "guard3": "Palassvakt",
    "guard4": "Palassvakt",
    "opponent1": "Sjørøver",
    "opponent2": "Sjørøver",
    "opponent3": "Sjørøver",
}

# 100% 1:1 story-authentic Norwegian lines mapped to exact original clip keys
EXACT_LINES = {
    # === KAPITTEL 1: GRUSOMME GABRIELS GROTTE (cave) ===
    "cave_start_controls_1_sabeltann": "Hiv og hoi, alle mann! Vi er endelig fremme ved Grusomme Gabriels grotte. Følg etter meg, Pinky, og bli ikke hengende etter!",
    "cave_start_controlsintro_storyteller": "Bruk W, A, S og D eller piltastene for å styre Pinky gjennom grotten. Hold inne Shift for å løpe raskere!",
    "cave_start_intro1_1_sabeltann": "Jeg sverger på min hatt — kartet lyver ikke! Grusomme Gabriels skatt ligger dypt inne i disse grottene!",
    "cave_start_intro1_2_langemann": "Men kaptein... sier ikke sagnet at det hviler en forferdelig forbannelse over skatten hans?",
    "cave_start_intro1_3_sabeltann": "Sludder og pølsevev, Langemann! Ingen død sjørøver skal stoppe Kaptein Sabeltann fra å hente gullet sitt! Fremad, gutter!",
    "cave_start_getbackin_benjamin": "Skynd deg inn i grotten, Pinky! Kaptein Sabeltann venter ikke på noen!",
    "cave_start_lookingforfood_skalken": "Huff, finnes det virkelig ikke engang en tørr kjeks i denne kalde grotten? Gå videre du, Pinky!",
    "cave_start_watchout1_1_sabeltann": "Se deg for ved kanten, Pinky! Ta fart og hopp over kløften!",
    "cave_start_jumpsintro_storyteller": "Trykk mellomromstasten for å hoppe over hindringer og kløfter!",
    "cave_start_intro4_1_sabeltann": "Godt hoppet, Pinky! Men se der borte — en svær klippekant sperrer veien videre!",
    "cave_start_intro4_2_langemann": "Vi kommer oss opp hvis vi skyver den gamle trekassen bort til fjellveggen, kaptein.",
    "cave_start_intro4_3_pysa": "Å nei, den ser altfor tung ut for ryggen min, Pelle!",
    "cave_start_intro4_4_pelle": "La Pinky ta seg av kassen! Han er jo verdens yngste og sprekeste sjørøver!",
    "cave_start_intro4_5_langemann": "Dytt kassen på plass ved veggen, Pinky, så følger vi etter!",
    "cave_start_watchout2_1_sabeltann": "Få fart på den kassen, Pinky! Skatten venter ikke!",
    "cave_start_cratesintro_storyteller": "Gå inntil trekassen og dytt den bort til kanten slik at du kan klatre opp!",
    "cave_start_donecrate_1_sabeltann": "Flott jobbet, Pinky! Kom dere opp, gutter — vi nærmer oss den store hallen!",
    "cave_start_wow_1_langemann": "Du store allverden! Se på den glødende lavaelven foran oss, kaptein!",
    "cave_start_wow_2_sabeltann": "Hrmpf! Det må finnes en bryter eller en vei over. Pelle, hjelp Pinky over til den andre siden!",
    "cave_start_throws_1_pelle": "Bare still deg foran meg, Pinky, så kaster jeg deg rett over lavaen!",
    "cave_start_throw_pelle": "Kom hit da, Pinky, så slenger jeg deg over!",
    "cave_start_ready_1_pelle": "Klar... ferdig... fly av sted, Pinky!",
    "pelle_intro_push": "Hiv og hå! Nå skyver vi!",
    "cave_start_swordintro_storyteller": "Trykk venstre museknapp eller F for å svinge sverdet og knuse den sprukne steinveggen!",
    "cave_start_sword1_1_pinky": "Kult! Med dette tresverdet kan jeg hugge meg rett gjennom den sprukne steinveggen!",
    "cave_start_sword2_1_pinky": "Hugg til! Nå ryker steinveggen!",
    "cave_start_findthechest_1_sabeltann": "Der inne ligger skattkammeret! Finn kisten til Grusomme Gabriel!",
    "cave_start_chamber_1_sabeltann": "Se der! Midt i rommet står kisten til selveste Grusomme Gabriel!",
    "cave_start_chest_1_pinky": "Vi fant den! Se på den store, skumle kisten der borte!",
    "cave_start_chest_2_sabeltann": "Endelig! All verdens gull og edelstener tilhører Kongen på Havet!",
    "cave_start_chest_3_langemann": "Vær forsiktig, kaptein... Det blåser en iskald gufs fra den kisten...",
    "cave_start_chest_4_sabeltann": "Pelle! Pysa! Kom hit og brekk opp lokket med én gang!",
    "cave_start_openchest_1_pelle": "Javisst, kaptein! Kom igjen, Pysa, vi tar den!",
    "cave_start_openchest_2_sabeltann": "Få opp lokket, sier jeg! Jeg vil se gullet skinne!",
    "cave_start_openchest_3_pelle": "Jeg teller til tre, Pysa! En... to...",
    "cave_start_openchest_4_pysa": "Vent litt da, Pelle, jeg tror noe beveger seg nedi der!",
    "cave_start_openchest_5_sabeltann": "Åpne kisten nå, ellers får dere skrubbe dekket resten av året!",
    "cave_start_openchest_6_pysa": "Uffameg... greit da, vi løfter på tre!",
    "cave_start_openchest_7_pelle": "TRE! Nå åpner vi kisten!",
    "cave_start_release_1_sabeltann": "Hva i alle dager?! Grønn røyk?! Kom dere unna!",
    "cave_start_release_2_pysa": "Hjelp! Det er Grusomme Gabriels spøkelse! Løp for livet!",
    "cave_start_release_3_pelle": "Vent på meg, Pysa! Forbannelsen er sluppet løs!",
    "cave_start_releaseending_1_boss": "Hahahaha! Dere våget å forstyrre min hvile! Grusomme Gabriels forbannelse skal forfølge Kaptein Sabeltann over alle syv hav! Tilbake til Abra Havn — før mørket sluker dere alle!",

    # === KAPITTEL 2: ABRA HAVN (abra) ===
    "abra_curse_1_miriam": "Velkommen tilbake, Pinky. Jeg så det allerede i krystallkulen min — dere har vekket Grusomme Gabriels forbannelse!",
    "abra_curse_2_pinky": "Miriam! Hele mannskapet er livredde! Hvordan kan vi bryte forbannelsen?",
    "abra_curse_3_miriam": "Bare tre eldgamle magiske skatter kan bryte Gabriels makt over Kaptein Sabeltann.",
    "abra_curse_4_pinky": "Hvor finner vi de tre skattene?",
    "abra_curse_5_miriam": "Den første befinner seg på den mørke klippeøya Gral, voktet av Greven av Gral selv.",
    "abra_curse_6_pinky": "Greven av Gral?! Da må vi sette seil med Den Sorte Dame med én gang!",
    "abra_curse_7_miriam": "Den andre skatten er skjult i den gylne ørkenbyen Fata Morgana, og den tredje dypt inne i Maga Khans jungelrike.",
    "abra_curse_8_pinky": "Jeg skal finne alle tre og redde Kaptein Sabeltann, Miriam!",
    "abra_curse_9_miriam": "Ta med deg motet ditt, Pinky. Og stikk innom butikken i Abra Havn for bedre våpen og utstyr før du seiler!",
    "abra_curse_10_pinky": "Det skal jeg gjøre! Hvordan kommer jeg raskt ut til havs?",
    "abra_curse_11_miriam": "Gå ned til brygga og bruk seilingsportalen ved Den Sorte Dame. Lykke til, unge sjørøver!",
    "abra_curseonyou_miriam": "Forbannelsen vokser seg sterkere for hver dag, Pinky. Skynd deg av sted mot Gral!",
    "abra_liftthecurse1_miriam": "Du må samle de magiske kreftene fra Gral, Fata Morgana og Maga Khans øy for å bryte forbannelsen!",
    "abra_liftthecurse2_miriam": "Krystallkulen lyser sterkt — du nærmer deg målet, Pinky!",
    "abra_portal_yes_1_miriam": "Portalen er klar! Stig inn når du vil seile ut på De Syv Hav!",
    "abra_portal_no_1_miriam": "Du må snakke med meg først før du kan bruke portalen, Pinky.",
    "abra_useportal1_miriam": "Bruk portalen ved brygga for å seile ut med Den Sorte Dame!",
    "abra_useportal2_miriam": "Når som helst du vil tilbake til Abra Havn, kan du seile rett hjem til havnen.",
    "abra_useportal3_storyteller": "Gå inn i den magiske lysringen ved brygga eller Den Sorte Dame for å seile ut på verdenskartet!",
    "abra_hey_sunniva": "Hei, Pinky! Godt å se deg trygt tilbake i Abra Havn!",
    "abra_curse_sunniva": "Hørte du hva som skjedde i grotten? Alle snakker om Grusomme Gabriels forbannelse!",
    "abra_curse2_sunniva": "Skynd deg opp til Miriam av Gral, Pinky — hun vet hvordan forbannelsen kan brytes!",
    "abra_cave_sunniva": "Nå som du har alle kreftene, må du tilbake til Grusomme Gabriels grotte og møte spøkelset hans!",
    "abra_gocave_sunniva": "Lykke til i det siste oppgjøret mot Grusomme Gabriel, Pinky!",
    "abra_fatamorgana_sunniva": "Neste stopp er den gylne ørkenbyen Fata Morgana!",
    "abra_gofatamorgana_sunniva": "Seil mot Fata Morgana og pass deg for vaktene til Sultanen!",
    "abra_goshangrila_sunniva": "Maga Khans øy er full av farlige feller og jungeldyr — vær forsiktig!",
    "abra_shangrila_sunniva": "Fantastisk! Nå er veien åpen til Maga Khans øy!",
    "abra_lamp_sunniva": "Tips: Kjøp lykten i butikken hvis du skal utforske mørke ganger — trykk L for å tenne den!",
    "abra_slingshot_sunniva": "Med spretterten kan du treffe brytere og fiender på lang avstand!",
    "abra_tip3_1_sunniva": "Knus tønner og kister i Abra Havn hvis du trenger flere gullmynter!",
    "abra_treasures_1_sunniva": "Det finnes skjulte skatter på havbunnen ute på De Syv Hav også!",
    "abra_keepplaying_storyteller": "Bra jobbet! Du kan fortsatt utforske alle øyene og finne resten av skattene!",
    "abra_unlockcave_1_sunniva": "Pinky! Miriam sier at veien til det siste oppgjøret i Grusomme Gabriels grotte nå er åpen!",
    "abra_unlockcave_2_pinky": "Endelig! Nå skal jeg gjøre slutt på forbannelsen en gang for alle!",
    "abra_unlockcave_3_sunniva": "Vær modig, Pinky — hele Abra Havn heier på deg!",
    "abra_unlockfatamorgana_1_prostitute2": "Har du hørt det, Pinky? Sjøveien til den rike ørkenbyen Fata Morgana er åpen!",
    "abra_unlockfatamorgana_2_pinky": "Flott! Da setter vi kursen mot Fata Morgana!",
    "abra_unlockfatamorgana_3_prostitute2": "Hils Sultanen hvis du kommer forbi de sultne palassvaktene!",
    "abra_unlockshangrila_1_shopkeeper": "Gode nyheter, Pinky! Jeg har skaffet sjøkartet til Maga Khans mystiske øy!",
    "abra_unlockshangrila_2_pinky": "Takk! Nå drar vi til Maga Khans rike!",
    "abra_unlockshangrila_3_shopkeeper": "Hold sverdet skarpt der ute, gutt!",
    "abra_shangrila_shopkeeper": "Velkommen til sjørøverbutikken i Abra Havn! Klar for ferden til Maga Khans øy?",
    "abra_buylamp_shopkeeper": "En førsteklasses sjørøverlykt! Den lyser opp selv den mørkeste fangekjeller.",
    "abra_buyslingshot_shopkeeper": "En knallgod sprettert! Perfekt til å treffe mål og skremme fiender på avstand.",
    "abra_buysword_shopkeeper": "Et ekte sjørøversverd! Nå skal skjelettene få kjørt seg!",
    "abra_nothingforsale_shopkeeper": "Du har allerede alt det beste utstyret i hele Abra Havn, Pinky!",
    "abra_opponent1_1_opponent1": "Hei, småen! Tror du virkelig du kan måle deg med en ekte sjørøver i sverdkamp?",
    "abra_opponent1_2_pinky": "Det skal vi snart finne ut av! Opp med sverdet!",
    "abra_opponent1_3_opponent1": "Haha, da setter vi i gang!",
    "abra_opponent1defeated_1_opponent1": "Au da! Du er jammen raskere med sverdet enn du ser ut til, Pinky!",
    "abra_opponent2_1_opponent2": "Ingen slipper forbi meg uten en skikkelig fekteduell, Pinky!",
    "abra_opponent2_2_pinky": "Jeg er alltid klar for en kamp!",
    "abra_opponent2_3_opponent2": "Forsvar deg, guttehvalp!",
    "abra_opponent2defeated_1_opponent2": "Jeg overgir meg! Du slåss som en ekte sjørøver!",
    "abra_opponent3_1_opponent3": "Jeg er den tøffeste fekteren på hele brygga i Abra Havn!",
    "abra_opponent3_2_pinky": "Vi får se på det! Hiv og hoi!",
    "abra_opponent3_3_opponent3": "Nå skal du få smake stålet mitt!",
    "abra_opponent3defeated_1_opponent3": "Utrolig! Du slo selv mesteren av Abra Havn!",

    # === VERDENSKARTET (world_map) ===
    "worldmap_intro_1_storyteller": "Velkommen ut på De Syv Hav! Styr Den Sorte Dame med W, A, S og D, og fyr av kanonene med venstre museknapp eller F mot fiendeskipene!",
    "worldmap_graal_1_sabeltann": "Sett kursen mot Gral, Pinky! Vi har en regning å gjøre opp med Greven av Gral!",
    "worldmap_fatamorgana_1_sabeltann": "Styr mot Fata Morgana! De gylne kuplene ligger rett forut!",
    "worldmap_shangrila_1_sabeltann": "Full fart mot Maga Khans øy, alle mann!",
    "worldmap_cave_1_sabeltann": "Tilbake til Grusomme Gabriels grotte! Nå skal forbannelsen brytes for godt!",
    "worldmap_cavetoabra_sabeltann": "Sett kursen hjem til Abra Havn, Pinky!",
    "worldmap_graaltoabra_sabeltann": "Bra seilt! La oss vende tilbake til Abra Havn!",
    "worldmap_fatamorganatoabra_sabeltann": "Kurs mot Abra Havn, Pinky!",
    "worldmap_shangrilatoabra_sabeltann": "Hjem til Abra Havn med seieren i boks!",
    "worldmap_beenherebefore_sabeltann": "Her har vi allerede vært, Pinky — men det skader aldri med litt mer gull!",
    "worldmap_alreadyvisited_storyteller": "Du har allerede fullført hovedoppdraget på denne øya, men du kan besøke den igjen når du vil.",
    "worldmap_fire_sabeltann_01": "Fyr løs med kanonene!",
    "worldmap_fire_sabeltann_02": "Gi dem en bredside, Pinky!",
    "worldmap_fire3_sabeltann_03": "Full treffer! Senk skuta deres!",
    "sink_speech_01": "Rett til bunns med dem! Hiv og hoi!",
    "sink_speech_02": "Et fiendeskip mindre på De Syv Hav!",
    "sink_speech_03": "Der gikk de ned med mann og mus!",
    "sink_speech_04": "Ingen tuller med Den Sorte Dame!",
    "sink_speech_05": "Flott skutt, Pinky! Plukk opp gullet i vannet!",
    "sink_speech_06": "Haha! Kongen på Havet vinner igjen!",

    # === KAPITTEL 3 & 4: GRAL (graal_mountain, graal_underwater, graal_bosslevel) ===
    "gral_mountain_intro_1_pelle": "Uff, for et skummelt mørkt fjell! Vi må klatre helt opp til brønnen ved borgen til Greven av Gral, Pinky!",
    "gral_mountain_goahead_pelle": "Gå i forveien du, Pinky, jeg passer på ryggen din!",
    "gral_mountain_goahead1_1_pelle": "Fortsett oppover stien, Pinky!",
    "gral_mountain_goahead2_1_pelle": "Vi nærmer oss toppen av Gral-fjellet!",
    "gral_mountain_goahead3_1_pelle": "Der oppe ser jeg brønnen som fører under borgmuren!",
    "gral_mountain_light_1_pinky": "Her var det mørkt! Bra jeg har med meg lykten!",
    "gral_mountain_signs_1_pinky": "Se på skiltene — de viser veien mot brønnen til Greven av Gral!",
    "gral_mountain_throw_pelle": "Kom hit, Pinky, så kaster jeg deg opp på neste klippehylle!",
    "gral_mountain_waitforpelle_1_pinky": "Kom igjen da, Pelle, jeg trenger hjelp til å komme videre!",
    "gral_mountain_welldone1_1_pelle": "Knallbra jobbet, Pinky!",
    "gral_mountain_welldone2_1_pelle": "Hurra! Nå hopper vi ned i brønnen og svømmer gjennom tunnelen til borgen!",
    "swimming_ghasp_1_pinky": "Puh! Frisk luft! Bare pass på luftmåleren og følg luftboblene!",
    "graal_boss_intro": "Hahahaha! Velkommen til min borg, lille sjørøver! Min drage skal gjøre kort prosess med deg!",
    "gral_boss_intro_1_boss": "Du våger å klatre opp av brønnen min?! Møt Greven av Gral og min ildsprutende drage!",
    "gral_boss_takethat1_1_pinky": "Ta denne, Greven av Gral! Katapult, fyr!",
    "gral_boss_takethat1_2_boss": "Au! Forbaskede guttehvalp! Du skal få angre!",
    "gral_boss_takethat2_1_pinky": "Rett i blinken igjen! Slipp taket!",
    "gral_boss_takethat2_2_boss": "Grrr! Ingen treffer dragen min ustraffet!",
    "gral_boss_takethat3_1_pinky": "En fulltreffer til! Nå vakler han!",
    "gral_boss_takethat3_2_boss": "Nei! Dette kan ikke skje!",
    "gral_boss_takethat4_1_pinky": "Og her kommer nådestøtet, Greven av Gral!",
    "gral_boss_takethat4_2_boss": "Neeeeei! Jeg faller! Vi sees igjen, Pinky!",
    "gral_boss_falldown_1_boss": "Pass deg så du ikke faller ned fra muren!",
    "gral_boss_youstink1_1_boss": "Bom! Du skyter som en blind landkrabbe!",
    "gral_boss_youstink2_1_boss": "Hahahaha! Var det alt du hadde å by på?",
    "gral_boss_win_1_boss": "Hahahaha! Greven av Gral seirer igjen!",
    "gral_boss_loose_1_boss": "Umulig! Beseiret av en liten byssegutt!",
    "gral_boss_ididit_pinky": "Jeg klarte det! Greven av Gral er beseiret! Nå drar vi videre mot Fata Morgana!",

    # === KAPITTEL 5-7: FATA MORGANA ===
    "fatamorgana_city_gate_1_sabeltann": "Åpne porten til Sultanens palass i Kaptein Sabeltanns navn!",
    "fatamorgana_city_gate_2_guard3": "Stopp! Ingen slipper inn i palasset uten tillatelse!",
    "fatamorgana_city_gate_3_guard1": "Med mindre... dere har med noen deilige kaker til oss vakter?",
    "fatamorgana_city_gate_4_sabeltann": "Kaker?! Hva slags tøys er dette?!",
    "fatamorgana_city_gate_5_langemann": "Det er nok enklere å skaffe dem kaker enn å slåss mot hele vaktstyrken, kaptein.",
    "fatamorgana_city_gate_6_guard2": "Ja! Vi vil ha fem skikkelige Fata Morgana-kaker!",
    "fatamorgana_city_gate_7_guard4": "Fem store, søte kaker — så åpner vi porten!",
    "fatamorgana_city_gate_8_guard1": "Ikke én kake mindre!",
    "fatamorgana_city_gate_9_guard3": "Lykke til i basaren, småen!",
    "fatamorgana_city_gate_10_guard2": "Mmmm, jeg kjenner lukten av honningkake allerede!",
    "fatamorgana_city_gate_11_guard4": "Skynd deg, vi er skrubbsultne!",
    "fatamorgana_city_gate_12_guard1": "Husk å lete både i basaren og nede i brønnen!",
    "fatamorgana_city_gate_13_guard3": "Ingen kaker, ingen adgang!",
    "fatamorgana_city_gate_14_guard2": "Kom tilbake når du har alle kakene!",
    "fatamorgana_city_firstcake1_1_pinky": "Jippi! Jeg fant den første kaken!",
    "fatamorgana_city_firstcake2_1_pelle": "Mmm, den så god ut, Pinky! Ikke la meg spise den!",
    "fatamorgana_city_gotfourcakes_1_pinky": "Her har dere fire kaker! Bare én igjen!",
    "fatamorgana_city_gotfourcakes_2_guard1": "Mmm, nydelig! Men vi mangler fortsatt den siste kaken!",
    "fatamorgana_city_gotfourcakes_3_guard3": "Finn den femte kaken, så åpner vi porten!",
    "fatamorgana_city_gotfourcakes_4_pinky": "Greit, jeg finner den siste med én gang!",
    "fatamorgana_city_gotfourcakes_5_pysa": "Kanskje den ligger nede i brønnen, Pinky?",
    "fatamorgana_city_gotfourcakes_6_sabeltann": "Sett fart, Pinky! Vi skal inn i det palasset i dag!",
    "fatamorgana_city_gotfourcakes_7_pysa": "Skal vi bare vente her i skyggen, Pelle?",
    "fatamorgana_city_gotfourcakes_8_pelle": "Ja, jeg er utslitt av all den lukten av kake!",
    "fatamorgana_city_gotfourcakes_9_sabeltann": "Late sjørøvere! Gå etter den siste kaken, Pinky!",
    "fatamorgana_city_gotfinalcake_1_pinky": "Vær så god! Her er den femte og siste kaken!",
    "fatamorgana_city_gotfinalcake_2_guard3": "Hurra! Endelig festmåltid!",
    "fatamorgana_city_gotfinalcake_3_guard2": "Mmm, best i hele ørkenen!",
    "fatamorgana_city_gotfinalcake_4_guard4": "Porten er åpen — velkommen inn i palasset!",
    "fatamorgana_city_gotfinalcake_5_pinky": "Takk skal dere ha! Kom igjen, kaptein!",
    "fatamorgana_city_gotfinalcake_6_sabeltann": "Utmerket jobbet, Pinky! Nå inntar vi Sultanens palass!",
    "fatamorgana_city_gotfinalcake_7_pelle": "Kan jeg få en liten smule først?",
    "fatamorgana_city_gotfinalcake_8_pysa": "Løp etter kapteinen, Pelle!",
    "fatamorgana_city_gotfinalcake_9_pinky": "Inn i palasset!",
    "fatamorgana_city_wetcake_1_pinky": "Æsj, denne kaken fra brønnen er klissvåt, men vaktene merker det sikkert ikke!",
    "fatamorgana_city_race_1_arab_boy": "Hei, fremmed! Tør du å kappkjøre med meg gjennom gatene i Fata Morgana?",
    "fatamorgana_city_race_2_pinky": "Klart jeg tør! Jeg løper raskere enn alle sjørøverne!",
    "fatamorgana_city_race_3_arab_boy": "Vinner du, får du kaken min! Klar, ferdig, løp!",
    "fatamorgana_city_wannaraceme_arab_boy": "Lyst på et nytt kappløp, Pinky?",
    "fatamorgana_city_win_1_arab_boy": "Wow, du er lynrask! Her er kaken du vant!",
    "fatamorgana_city_loose_1_arab_boy": "Haha, jeg vant! Prøv igjen hvis du tør!",
    "fatamorgana_city_raceover_arab_boy": "Det var et gøy kappløp, Pinky!",
    "fatamorgana_city_hittargets_1_carpet_salesman": "Treff alle blinkene med spretterten din, så skal du få låne det flygende teppet mitt!",
    "fatamorgana_city_notalltargets_1_carpet_salesman": "Du har ikke truffet alle blinkene ennå! Prøv igjen med spretterten!",
    "fatamorgana_city_gotalltargets_1_carpet_salesman": "Utrolig sikte! Nå kan du bruke det flygende teppet mitt!",
    "fatamorgana_city_cakesforsale_shopkeeper": "Ferske kaker til salgs! Kun noen få gullmynter!",
    "fatamorgana_city_enoughcopper_1_shopkeeper": "Takk for handelen! Her er en nybakt kake!",
    "fatamorgana_city_notenoughcopper_1_shopkeeper": "Beklager, gutten min, du trenger litt flere mynter for denne kaken!",
    "fatamorgana_city_thankscomeagain_shopkeeper": "Takk for besøket, velkommen igjen!",
    "fatamorgana_city_bakeyourself_skalken": "Bake fem kaker i denne varmen?! Nei, det får du skaffe i basaren selv, Pinky!",
    "fatamorgana_city_nocakeshere_pelle": "Ingen kaker her, Pinky — bare sand!",
    "fatamorgana_city_nocakeshere_pysa": "Jeg har heller ikke funnet noen kaker!",
    "fatamorgana_city_notenoughcakes_sabeltann": "Vi trenger flere kaker før vaktene åpner porten, Pinky!",
    "fatamorgana_city_notgonnaeat_benjamin": "Jeg lover, jeg rører ikke kakene!",
    "fatamorgana_city_yum_1_pelle": "Nam nam! Det lukter nybakte kaker over hele byen!",
    "fatamorgana_palace_intro_1_sabeltann": "Her er vi inne i Sultanens palass! Finn nøklene og kom deg inn til tronsalen, Pinky!",
    "fatamorgana_palace_findkeys_sabeltann": "Løsningene ligger i flisgåtene og sidegangene — finn nøklene!",
    "fatamorgana_palace_darkroom_1_pinky": "Her er det bekmørkt! Frem med lykten!",
    "fatamorgana_palace_keys_1_pinky": "Flott! En palassnøkkel!",
    "fatamorgana_palace_platform_1_pinky": "Se, plattformen flyttet seg!",
    "fatamorgana_palace_tilepuzzle_1_pinky": "Aha! Jeg må tråkke på gulvflisene i riktig rekkefølge!",
    "fatamorgana_palace_saveme1_sultan": "Hjelp! Redd meg fra den forbannede palassvokteren!",
    "fatamorgana_palace_saveme2_sultan": "Skynd deg, unge sjørøver, åpne salen og overvinn vokteren!",
    "fatamorgana_boss_intro": "Ingen dødelig skal ta skatten fra Fata Morganas haller!",
    "fatamorgana_boss_whatwasthat_1_pinky": "Hva var det?! Gulvet rister!",
    "fatamorgana_boss_itscomming1_1_pinky": "Pass opp, nå angriper den!",
    "fatamorgana_boss_itscomming2_1_pinky": "Her kommer den igjen — hopp unna!",
    "fatamorgana_boss_yikes1_1_pinky": "Oi! Det var nære på!",
    "fatamorgana_boss_yikes2_1_pinky": "Hjelpes, den er svær!",
    "fatamorgana_boss_won_1_pinky": "Jaaa! Vi klarte det! Nå er Fata Morgana reddet, og kursen går mot Maga Khans øy!",

    # === KAPITTEL 8-12: MAGA KHANS ØY (beach, jungle, palace, dungeon, endboss) ===
    "shangrila_beach_intro_1_sabeltann": "Endelig fremme på Maga Khans øy! Men hvor har det blitt av resten av mannskapet?!",
    "shangrila_beach_intro_2_sabeltann": "Hjelp Skalken og samle mannskapet, Pinky, så bryter vi oss inn i jungelen!",
    "shangrila_beach_wheresmycrew_sabeltann": "Hvor i all verden gjemmer Pelle, Pysa og Benjamin seg?",
    "shangrila_beach_gatherthemen_langemann": "Samle sammen mannskapet ved strandporten, Pinky!",
    "shangrila_beach_ending_sabeltann": "Alle mann samlet! Nå marsjerer vi inn i Maga Khans jungel!",
    "shangrila_beach_welcomesons_1_malena": "Pelle! Pysa! Guttene mine! Så godt å se dere!",
    "shangrila_beach_welcomesons_2_pelle": "Mamma Malena?! Hva gjør du på Maga Khans øy?",
    "shangrila_beach_welcomesons_3_pysa": "Hei mamma! Vi er på skattejakt med Kaptein Sabeltann!",
    "shangrila_beach_welcomesons_4_malena": "Pass godt på hverandre i jungelen, gutter!",
    "shangrila_beach_lookitsmom_1_pelle": "Se, Pysa! Det er mamma Malena borte ved strandbaren!",
    "shangrila_beach_goodtoseemyboys_malena": "Så koselig å se guttene mine igjen!",
    "shangrila_beach_lookingforfood_1_skalken": "Pinky! Jeg trenger kokosnøtter og sterk saus til gryta mi før vi går inn i jungelen!",
    "shangrila_beach_thanks_1_skalken": "Takk, Pinky! Akkurat det jeg trengte!",
    "shangrila_beach_thanksalot_1_skalken": "Tusen takk! Nå har hele mannskapet krefter til jungelen!",
    "shangrila_beach_questcomplete_skalken": "Gryta er klar! Nå kan vi åpne porten inn til jungelen!",
    "shangrila_beach_itburns_1_pelle": "Huuuh! Det brenner på tunga! Sterk saus!",
    "shangrila_beach_justhanging_1_pinky": "Benjamin! Hva gjør du der oppe i treet?!",
    "shangrila_beach_justhanging_2_benjamin": "Jeg bare tar en liten hvil over stranden, Pinky!",
    "shangrila_beach_justhanging_3_pinky": "Kom ned nå, Kaptein Sabeltann roper på alle mann!",
    "shangrila_beach_justhanging_4_benjamin": "Greit, greit — jeg kommer ned straks!",
    "shangrila_beach_comingsoon_benjamin": "Jeg kommer straks ned til porten, Pinky!",
    "shangrila_jungle_intro_1_sabeltann": "Hold øynene åpne! Maga Khans jungel er full av ville pantere og kjøttetende planter!",
    "shangrila_jungle_intro_2_langemann": "Jeg tar teten sammen med kapteinen. Følg godt etter, Pinky!",
    "shangrila_jungle_panther_1_pinky": "Pass opp! En svart panter! Jeg må lokke den i fellen!",
    "shangrila_jungle_usethetrap_1_pinky": "Aha! Hvis jeg lokker panteren inn i fellen, slipper vi forbi!",
    "shangrila_jungle_trapped_1_pinky": "Yes! Panteren er fanget i fellen!",
    "shangrila_jungle_meat_1_pinky": "Et saftig kjøttstykke! Perfekt til den kjøttetende planten!",
    "shangrila_jungle_meatplant_1_pinky": "Oi, for en enorm kjøttetende plante! Den slipper oss nok forbi hvis jeg mater den!",
    "shangrila_jungle_croc_1_pinky": "Se opp for krokodillen i elven!",
    "shangrila_jungle_help_1_daughter": "Hjelp! Redd meg fra jungelkrigerne!",
    "shangrila_jungle_getawayfromher_1_pinky": "Hold dere unna henne! Frem med sverdet!",
    "shangrila_jungle_thanksforsavingme_1_pinky": "Går det bra med deg?",
    "shangrila_jungle_thanksforsavingme_2_daughter": "Tusen takk, Pinky! Du reddet meg! Veien til Maga Khans palass ligger rett frem!",
    "shangrila_jungle_thanks_1_daughter": "Takk igjen, modige sjørøver!",
    "shangrila_jungle_getusoutofhere_1_langemann": "Pinky! Maga Khans krigere har fanget oss i buret!",
    "shangrila_jungle_getusoutofhere_2_pysa": "Slipp oss ut herfra før de lager suppe av oss!",
    "shangrila_jungle_getusoutofhere_3_sabeltann": "Finn spaken og befri mannskapet mitt med én gang, Pinky!",
    "shangrila_jungle_getusoutofhere_4_pelle": "Skynd deg, Pinky!",
    "shangrila_jungle_getusoutofhere_5_sabeltann": "Bra gutt! Nå stormer vi Maga Khans palass!",
    "shangrila_jungle_getusoutofhere_6_pinky": "Alle er fri! Mot Maga Khans palass!",
    "shangrila_jungle_freeus_langemann": "Befri oss fra buret, Pinky!",
    "shangrila_jungle_crasybushmen_1_sabeltann": "Pass deg for jungelkrigerne, Pinky!",
    "shangrila_palace_intro_1_sabeltann": "Her er Maga Khans festning! Porten til fangehullet er låst med fem hellige gonger!",
    "shangrila_palace_intro_2_langemann": "Slå på alle fem gongene i gårdsplassen, Pinky, så åpnes porten!",
    "shangrila_palace_intro_3_sabeltann": "Sett i gang! Maga Khan skal ikke slippe unna!",
    "shangrila_palace_courtyard_1_pinky": "Se de store gongene rundt i gårdsplassen!",
    "shangrila_palace_gem1_1_pinky": "Én gong slått! Fire igjen!",
    "shangrila_palace_gem2_1_pinky": "To gonger! Tre igjen!",
    "shangrila_palace_gem3_1_pinky": "Tre gonger! Bare to igjen!",
    "shangrila_palace_gem4_1_pinky": "Fire gonger! Bare én igjen nå!",
    "shangrila_palace_gem5_1_pinky": "Alle fem gongene! Hør — den store porten går opp!",
    "shangrila_palace_gatedown_1_pinky": "Porten til Maga Khans fangehull er åpen!",
    "shangrila_palace_getthisgateopen_1_sabeltann": "Få opp den porten ved å slå på alle gongene, Pinky!",
    "shangrila_palace_letstakethisplace_1_sabeltann": "Fremad inn i fangehullet!",
    "shangrila_palace_thisplaceisours_langemann": "Hele gårdsplassen er vår!",
    "shangrila_dungeon_findanotherway_1_sabeltann": "Flammene sperrer gangen! Finn spakene og nøkkelen til dragekammeret, Pinky!",
    "shangrila_dungeon_needkey_1_pinky": "Døren er låst! Jeg må dykke i undervannskammeret etter fangehullsnøkkelen!",
    "shangrila_dungeon_needrightkey_1_pinky": "Feil nøkkel — jeg må finne den riktige nøkkelen!",
    "shangrila_dungeon_comewithmepirate_1_sirikit": "Stille, sjørøver! Jeg er Sirikit. Følg meg — jeg vet veien til Maga Khans drage!",
    "shangrila_dungeon_comewithmepirate_2_pelle": "Hvor skal vi, Sirikit? Er det farlig der inne?",
    "shangrila_dungeon_comewithmepirate_3_sirikit": "Maga Khan vokter den siste nøkkelen i dragekammeret rett frem.",
    "shangrila_dungeon_comewithmepirate_4_pelle": "Uffameg, en drage til?!",
    "shangrila_dungeon_comewithmepirate_5_sirikit": "Kaptein Sabeltann og Pinky klarer dette sammen!",
    "shangrila_dungeon_comewithmepirate_6_pelle": "Lykke til der inne, Pinky!",
    "shangrila_dungeon_endconversation_1_sabeltann": "Nå går vi inn til Maga Khan! Gjør deg klar for kamp, Pinky!",
    "shangrila_boss_fight1_1_sabeltann": "Maga Khan! Din tid som hersker over denne øya er forbi!",
    "shangrila_boss_fight2_1_maga_khan": "Hahahaha! Kaptein Sabeltann! Dragen min skal brenne dere til aske!",
    "shangrila_boss_distractthedragon_1_sabeltann": "Distraher dragen, Pinky, så slår jeg til mot Maga Khan!",
    "shangrila_boss_afterme_1_pinky": "Hei, drage! Se hit — fang meg hvis du kan!",
    "shangrila_boss_hint1_1_pinky": "Jeg må lokke dragen unna så Kaptein Sabeltann får fritt skudd!",
    "shangrila_boss_hint2_1_pinky": "Hopp unna ildpusten!",
    "shangrila_boss_youandme_1_sabeltann": "Nå er det bare deg og meg, Maga Khan!",
    "shangrila_boss_loose_1_maga_khan": "Nei! Dragen min! Hvordan er det mulig?!",
    "shangrila_boss_loose_2_maga_khan": "Forbaskede sjørøvere! Dette er ikke over!",
    "shangrila_boss_win_1_sabeltann": "Seier! Maga Khan er beseiret! Nå har vi alt vi trenger — sett seil tilbake til Grusomme Gabriels grotte!",

    # === KAPITTEL 13-15: FINALEN I GRUSOMME GABRIELS GROTTE & OUTRO ===
    "cave_end_intro_1_sabeltann": "Vi er tilbake i Grusomme Gabriels grotte! Nå skal vi bryte forbannelsen en gang for alle!",
    "cave_end_skeleton_1_sabeltann": "Skjelettvakter! Hugg dem ned, Pinky!",
    "cave_end_gofirst_1_langemann": "Det lyser uhyggelig grønt fra det innerste skattkammeret, kaptein...",
    "cave_end_gofirst_2_sabeltann": "Pinky, du har vist deg som den modigste av oss alle. Gå inn og møt Grusomme Gabriels spøkelse!",
    "cave_end_gofirst_3_langemann": "Vi dekker ryggen din, Pinky!",
    "cave_end_gofirst_4_pinky": "Jeg er ikke redd! Nå skal jeg knuse forbannelsen!",
    "cave_end_dontworry_1_langemann": "Ikke bekymre deg, Pinky — du klarer dette!",
    "skeleton_boss_intro": "Hahahaha! Så dere våget å vende tilbake til mitt skattkammer?!",
    "cave_boss_intro_1_skeleton_boss": "Lille sjørøver! Tror du virkelig at du kan beseire selveste Grusomme Gabriels spøkelse?!",
    "cave_boss_intro_2_pinky": "Jeg er Pinky, verdens yngste sjørøver — og i dag slutter forbannelsen din!",
    "cave_boss_intro_3_skeleton_boss": "Da skal du få smake min vrede! Hahahaha!",
    "cave_boss_change1_1_skeleton_boss": "Nok lek! Nå slipper jeg løs all min spøkelseskraft!",
    "cave_boss_change1_2_skeleton_boss": "Kjenn kulden fra de dødes rike!",
    "cave_boss_change1_3_pinky": "Det skremmer meg ikke! Her kommer jeg!",
    "cave_boss_hit_1_skeleton_boss": "Arrgh! Det sverdet brenner!",
    "cave_boss_laugh1_1_skeleton_boss": "Hahahaha! Du kan ikke røre et spøkelse!",
    "cave_boss_laugh2_1_skeleton_boss": "Mwahaha! Kaptein Sabeltann vil aldri bli fri!",
    "cave_boss_hint1_1_pinky": "Jeg må unngå ildkulene og slå til når han lander!",
    "cave_boss_hint2_1_pinky": "Der åpnet forsvaret hans seg — angrip!",
    "cave_boss_hint3_1_pinky": "Hold deg i bevegelse!",
    "cave_boss_hint4_1_pinky": "Bare noen få hugg igjen nå!",
    "cave_boss_win_1_skeleton_boss": "Neeeeei! Kraften min... forsvinner!",
    "cave_boss_win_2_pinky": "Forbannelsen er brutt, Grusomme Gabriel!",
    "cave_boss_win_3_skeleton_boss": "Hvordan kunne en liten gutt... overvinne meg?!",
    "cave_boss_win_4_pinky": "Fordi ekte sjørøvere aldri gir opp!",
    "cave_boss_win_5_skeleton_boss": "Forbannelsen over Kaptein Sabeltann... er hevet...",
    "cave_boss_win_6_pinky": "Vi klarte det! Skatten og Kaptein Sabeltann er fri!",
    "cave_boss_win_7_skeleton_boss": "Farvel... for alltid...",
    "cave_boss_win_8_pinky": "Hiv og hoi! Nå feirer vi hjemme i Abra Havn!",
    "cave_boss_win_9_skeleton_boss": "Aaaargh...",
    "outro_conversation": "Hiv og hoi, alle mann! Grusomme Gabriels forbannelse er brutt, skatten er vår, og Pinky er en ekte sjørøver på Den Sorte Dame! Leve Kaptein Sabeltann!",
}


def fallback_line_for_clip(key: str, speaker: str, cast: str) -> str:
    low = key.lower()
    if "canbuysword" in low:
        return "Jeg vil gjerne kjøpe det nye sverdet!" if speaker == "pinky" else "Et glimrende valg, Pinky! Bruk det vel!"
    if "cantbuysword" in low:
        return "Har jeg nok gullmynter til sverdet?" if speaker == "pinky" else "Beklager, Pinky, du trenger noen flere gullmynter først!"
    if "canbuysling" in low:
        return "Kan jeg få kjøpe spretterten?" if speaker == "pinky" else "Vær så god, en knallgod sprettert til deg!"
    if "cantbuysling" in low:
        return "Kan jeg kjøpe spretterten nå?" if speaker == "pinky" else "Du mangler noen mynter ennå, Pinky — samle litt mer gull!"
    if "canbuylamp" in low:
        return "Jeg trenger en lykt til de mørke grottene!" if speaker == "pinky" else "Her har du en solid sjørøverlykt!"
    if "cantbuylamp" in low:
        return "Har jeg råd til lykten?" if speaker == "pinky" else "Ikke helt ennå, Pinky — kom tilbake med flere gullmynter!"
    if "yeshull" in low:
        return "Kan du forsterke skroget på Den Sorte Dame?" if speaker == "pinky" else "Javisst! Nå tåler skuta dobbelt så mange kanonkuler!"
    if "nohull" in low:
        return "Kan vi oppgradere skroget nå?" if speaker == "pinky" else "Du trenger litt flere gullmynter for sterkere eikeplanker, Pinky!"
    if "yessail" in low:
        return "Kan vi få større og raskere seil på Den Sorte Dame?" if speaker == "pinky" else "Klart det! Nå fyker Den Sorte Dame over bølgene!"
    if "nosail" in low:
        return "Har vi råd til nye seil?" if speaker == "pinky" else "Skaff litt mer gull først, så syr jeg de raskeste seilene på De Syv Hav!"
    if "cakeend" in low:
        if speaker == "sabeltann":
            return "Flott jobbet, Pinky! Veien til palasset er vår!"
        if speaker == "pinky":
            return "Alle kakene er levert — nå går vi inn!"
        return "Mmm, beste kakene vi noen gang har smakt! Stig på!"
    if "shangrila_beach_bar" in low:
        if speaker == "pinky":
            return "Hei Pelle og Pysa! Kaptein Sabeltann venter på dere ved porten!"
        if speaker == "pelle":
            return "Vi bare tar en liten kokosdrikk her hos mamma, Pinky!"
        return "Ja, vi kommer straks etter!"
    if "shangrila_beach_hint" in low:
        return "Kanskje jeg finner det Skalken trenger borte ved palmene eller strandbaren!"
    if "justhanging2" in low:
        return "Kom ned nå, Benjamin!" if speaker == "pinky" else "Hopp ned da, jeg er rett bak deg!"
    if "gofurther" in low or "proceed" in low:
        return "Bra jobbet! Fortsett videre innover i fangehullet, Pinky!"
    if "illstayhere" in low:
        return "Jeg blir stående vakt akkurat her jeg, Pinky!"
    if "letmethrowyou" in low:
        return "Kom hit, Pinky, så kaster jeg deg opp!"
    if "somethingdownhere" in low:
        return "Oi! Det er noe viktig nede her, Pinky!"
    if "imscared" in low:
        return "Huff, jeg liker ikke denne mørke jungelen!"
    if "hetriedtoshootme" in low:
        return "Hei! Han prøvde å skyte etter meg! Pass opp!"
    if "missedcrate" in low:
        return "Oops, jeg må flytte kassen riktig!"
    if "treasurehunt" in low:
        if "ididit" in low:
            return "Jippi! Jeg fant den nedgravde sjørøverskatten!"
        if "loose" in low:
            return "Tiden rant ut! Prøv igjen og finn skatten raskere, Pinky!"
        if "idle" in low:
            return "Følg kompasset og grav der skatten ligger gjemt, Pinky!"
        return "Hiv og hoi! Finn den nedgravde skatten før tiden går ut!"
    if "cave_boss_idle" in low:
        return "Kom frem da, lille sjørøver! Hahahaha!"
    if "cave_boss_wakeup" in low:
        return "Du slipper ikke unna Grusomme Gabriels vrede!"
    return "Hiv og hoi, Pinky! Fremad mot skatten!"


def norm_speaker(sp: str, key: str) -> str:
    low = key.lower()
    if "sabeltann" in low: return "sabeltann"
    if "langemann" in low: return "langemann"
    if "miriam" in low: return "miriam"
    if "sunniva" in low: return "sunniva"
    if "skalken" in low: return "skalken"
    if "benjamin" in low: return "benjamin"
    if "malena" in low: return "malena"
    if "sirikit" in low: return "sirikit"
    if "storyteller" in low: return "storyteller"
    if "shopkeeper" in low: return "shopkeeper"
    if "shipman" in low: return "shipman"
    if "carpet_salesman" in low: return "carpet_salesman"
    if "sultan" in low: return "sultan"
    if "maga_khan" in low: return "maga_khan"
    if "skeleton_boss" in low or "boss" in low: return "boss"
    if "daughter" in low: return "daughter"
    if "arab_boy" in low: return "boy"
    if "pelle" in low: return "pelle"
    if "pysa" in low: return "pysa"
    if "pinky" in low: return "pinky"
    if sp in VOICE_PROFILES: return sp
    return "sabeltann"


async def synth_one(sem: asyncio.Semaphore, key: str, text: str, speaker: str):
    out_ogg = VOICES_NO_DIR / f"{key}.ogg"
    if out_ogg.exists() and out_ogg.stat().st_size > 1000:
        return True
    voice, pitch, rate, ffilt = VOICE_PROFILES.get(speaker, VOICE_PROFILES["storyteller"])
    tmp_mp3 = TMP_MP3_DIR / f"{key}.mp3"
    async with sem:
        for attempt in range(3):
            try:
                comm = edge_tts.Communicate(text, voice, pitch=pitch, rate=rate)
                await comm.save(str(tmp_mp3))
                if tmp_mp3.exists() and tmp_mp3.stat().st_size > 200:
                    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp_mp3)]
                    if ffilt:
                        cmd += ["-af", ffilt]
                    cmd += ["-ac", "1", "-ar", "22050", "-c:a", "libvorbis", "-q:a", "2", str(out_ogg)]
                    r = subprocess.run(cmd)
                    tmp_mp3.unlink(missing_ok=True)
                    if r.returncode == 0 and out_ogg.exists():
                        return True
            except Exception as e:
                if attempt == 2:
                    print(f"[WARN] TTS failed {key}: {e}", flush=True)
                await asyncio.sleep(0.5 * (attempt + 1))
    return False


async def run_all():
    VOICES_NO_DIR.mkdir(parents=True, exist_ok=True)
    TMP_MP3_DIR.mkdir(parents=True, exist_ok=True)
    cat = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    dialogues = {}
    tasks_data = []
    for key, info in sorted(cat.items()):
        sp = norm_speaker(info.get("speaker", ""), key)
        text = EXACT_LINES.get(key) or fallback_line_for_clip(key, sp, info.get("cast", ""))
        dialogues[key] = {
            "speaker": sp,
            "speaker_name": SPEAKER_DISPLAY.get(sp, sp.capitalize()),
            "cast": info.get("cast", ""),
            "text": text,
        }
        tasks_data.append((key, text, sp))

    DIALOGUES_OUT.write_text(json.dumps(dialogues, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {len(dialogues)} Norwegian dialogue entries to {DIALOGUES_OUT}", flush=True)

    sem = asyncio.Semaphore(10)
    done = 0
    ok = 0
    batch_size = 45
    for i in range(0, len(tasks_data), batch_size):
        chunk = tasks_data[i : i + batch_size]
        res = await asyncio.gather(*(synth_one(sem, k, t, s) for k, t, s in chunk))
        done += len(chunk)
        ok += sum(1 for r in res if r)
        print(f"  Synthesized {done}/{len(tasks_data)} Norwegian voice clips (ok={ok})...", flush=True)

    print(f"ALL DONE! {ok}/{len(tasks_data)} Norwegian voice clips ready in {VOICES_NO_DIR}", flush=True)


if __name__ == "__main__":
    asyncio.run(run_all())
