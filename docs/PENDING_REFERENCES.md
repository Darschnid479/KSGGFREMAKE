# Midlertidige flater som venter på originalreferanse (KSGGFREMAKE)

Følgende flater i spillet har detaljer som enten er **uleselige i 2007-kildematerialet** eller **kun finnes på russisk**
i den tilgjengelige 2007-ISO-en. I tråd med kravet om å **ikke gjette** og **ikke telle midlertidige originalteksturer
som ferdige erstatninger**, er disse beholdt midlertidig i best dokumenterte form inntil norsk/høyoppløst originalreferanse foreligger.

Totalt antall flater som venter på referanse: **`7`** (av `622` materialflater totalt).

| GLB-fil | Materialnavn | Hva som mangler |
|---|---|---|
| `levels/abra.glb` | `abramainbuildingscombinedabramiddlecitylightingmap` | Små butikkskilt i teksturatlaset har russisk/lavoppløst tekst ('Торговая лавка' / 'Весёлая устрица'); norsk originalreferanse mangler. |
| `levels/abra.glb` | `shopsigncombinedabramiddlecitylightingmap` | ISO-kilde har russisk butikkskilttekst ('Все для пирата'); norsk originaltekst for skiltet i Abra Havn mangler referanse. |
| `levels/abra.glb` | `abramainbuildingsbrightcombinedabrafloatingobjectsLightingMap` | Lysvariant av abramainbuildings med små russiske/lavoppløste skiltdetaljer; norsk originalreferanse mangler. |
| `levels/abra.glb` | `objectsshop` | Tettpakket lavoppløst butikkhylle-atlas (små etiketter og hyller ikke lesbare i 2007-originalen). |
| `levels/abra.glb` | `shipobjects` | Tettpakket lavoppløst skipsutstyrs-atlas (små gjenstander uleselige i 2007-originalen). |
| `levels/fatamorgana_city.glb` | `abramainbuildingscombinedobjectsLightingMap` | Små butikkskilt i teksturatlaset har russisk/lavoppløst tekst ('Торговая лавка' / 'Весёлая устрица'); norsk originalreferanse mangler. |
| `levels/fatamorgana_city.glb` | `shopobjcompletemap` | Tettpakket lavoppløst basarhylle-atlas i Fata Morgana (små varer uleselige i 2007-originalen). |

### Merknad om verdenskartets sjøkart-titler (`world_map.glb`)
- De fem sjøkarttitlene i den russiske 2007-ISO-en (`textabra.TIFF`, `textfatamorgana.TIFF`, `titlegraal.TIFF`, `titleshangrila.TIFF`, `titleskjebnegrotten.TIFF`) inneholdt kyrillisk tekst (*Абра*, *Фата-Моргана*, *Грель*, *Шангри-Ла*, *Пещера*).
- Disse er byttet ut i kjøretid (`VisualEnhancer.gd`) med nyskrevne bue-kalligrafiske norske karttitler (`Abra Havn`, `Fata Morgana`, `Gral`, `Shangri-La`, `Skjebnegrotten`) basert på selve originalfilnavnene og originalens typografiske bue- og glød-stil. Dersom skanning/skjermbilde av den norske 2007-utgavens eksakte kartskrift skaffes senere, kan `godot_project/assets/ui/map_text*.png` oppdateres direkte uten å endre 3D-meshene.
