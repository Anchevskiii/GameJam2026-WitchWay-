# Witch Way? — It's a Feature, Not a Bug: Halloween Edition

> GameJam BEST x ŠS FERI 2026 — oddajna različica · Ekipa **Bodoči Poljedelci** · Build **v0.2.0**
>
> *Boo, buffer overload.*

## Zagon (za organizatorje)
1. Prenesi repozitorij (**Code → Download ZIP**) ali `git clone https://github.com/Anchevskiii/GameJam2026-WitchWay-.git`.
2. Odpri mapo `Build/`.
3. Dvoklikni `WitchWay.exe` — igra se zažene brez Godota ali dodatnih knjižnic (Windows 10/11, 64-bit). Vsi podatki igre so vgrajeni v .exe.
4. Če Windows SmartScreen prikaže opozorilo (»Windows protected your PC«), klikni **More info → Run anyway** (datoteka ni digitalno podpisana).

## Kontrole
| Tipka | Dejanje |
| --- | --- |
| W / A / S / D ali puščice | Premikanje |
| Shift | Sprint |
| E (drži) | Interakcija / iskanje po pohištvu / odpri |
| Space | BOO! — prestraši pošasti |
| F | Svetilka (vklop/izklop) |
| Q | Glitch mode — sesuj hišo na zahtevo (kupljen naboj) |
| R | Nadeni si masko (če jo imaš) |
| Esc | Premor / nazaj |

## Povezave
- **Dokumentacija:** [Documentation/WitchWay_ItsAFeatureNotABug_Dokumentacija.md](Documentation/WitchWay_ItsAFeatureNotABug_Dokumentacija.md)
- **Windows build:** [Build/WitchWay.exe](Build/WitchWay.exe)
- **Video (30 s):** *(dopolni s povezavo na video)*
- **Repozitorij:** https://github.com/Anchevskiii/GameJam2026-WitchWay-

## Ekipa — Bodoči Poljedelci
- **Jan Ančevski** — programiranje (NPC-ji, zvok, meniji, trgovina, ekonomija sladkarij)
- **Niko Pozderec** — programiranje (generiranje sob, pasti, jumpscari, grafika sob)
- **Klemen Novak** — efekti (grafika, zvok, izgled)

---

## O igri

Ujet si v neskončni, proceduralno generirani hiši strahov. Vsako nadstropje je nova hiša sob, polnih pošasti, pasti in skritih ključev. Tvoj cilj je priti čim globlje — preden te pošasti prestrašijo do konca.

Ne boriš se — **strašiš nazaj**. Vsak »BOO!« preobremeni procesor hiše, in ko se ta sesuje, postanejo napake igre tvoj izhod. *It's not a bug, it's a feature.*

### Kako igrati
1. Začneš v **Living Roomu** — varni sobi brez pošasti, kjer se napredek shrani. Tu pri trgovcu kupiš opremo s sladkarijami.
2. Skozi izhod vstopiš v **nadstropje**. Poišči **ključe** v predalih in omarah (drži **E**) — izhod je zaklenjen, dokler jih ne najdeš vseh.
3. Izogibaj se pošastim, se **skrij** v omaro ali jih **prestraši (Space)**. Vsak strah polni **CPU** hiše.
4. Ko CPU doseže 100 %, se hiša **sesuje (GLITCH)**: luči utripajo, slika se pokvari in **glitch vrata** se odprejo.
5. Ko najdeš zadnji ključ, se hiša **prebudi** — pojavi se **Stalker**, ki hodi skozi stene. Beži do izhoda!
6. Če tvoj **Sanity** pade na 0, se od strahu »poluliš v hlače« in ponoviš nadstropje.

### Glavne mehanike
- **Sanity** — zmanjšajo ga pošasti, pasti, jumpscari in temni GLITCH. Sladkarije (izpustijo jih prestrašeni otroci) ga povrnejo.
- **CPU overload / GLITCH** — strašenje polni CPU hiše; ob sesutju se odpre izhod. Na zabavah (party nadstropja) en dober strah povzroči paniko več gostov naenkrat.
- **Namerni hrošči** — nekateri zidovi izgledajo pokvarjeno in so prehodni; glitch vrata so dobesedno napaka, ki postane izhod.
- **Ključi in iskanje** — ključi so skriti v pohištvu; nekateri predali skrivajo sladkarije ali jumpscare.
- **Pasti** — past za medvede (te ujame), škripajoče deske (hrup prikliče pošasti), jumpscare točke (obraz čez zaslon + nova pošast).
- **Pošasti** — duh, buča, vampir, volkodlak, čarovnica, netopir … Tavajo, preiskujejo hrup, lovijo, prežijo v kotih in se skrivajo.
- **Stalker** — pojavi se po zadnjem ključu, gre skozi stene; BOO ga za trenutek omami.
- **Trgovina in sladkarije** — sladkarije so valuta: maske, glitch naboji, svetilka in nadgradnje (npr. hitrejše iskanje). Avtomati za sladkarije so tudi v nadstropjih.
- **Težavnost** — vsaka tri nadstropja nova stopnja: več pošasti, pasti in ključev, temnejše sobe.
- **Prilagoditev lika** — v glavnem meniju izbereš izgled svojega lika.

---

## Tehnologija

- **Pogon:** Godot 4.3, izključno GDScript.
- **Proceduralno generiranje:** `HouseGenerator` z BSP razdeli nadstropje v sobe, jih poveže z vrati in vsaki dodeli temo (kuhinja, spalnica, knjižnica …), pohištvo, pošasti, pasti in ključe. Rezultat je ASCII-mreža, ki jo `Room` pretvori v ploščice, kolizije in objekte.
- **Svetloba:** `CanvasModulate` zatemni sceno, igralec nosi `PointLight2D`, stene imajo `LightOccluder2D`.
- **EventBus:** sistemi komunicirajo prek signalov (`noise_made`, `jumpscare_requested`, `keys_changed`, `house_awakened` …).
- **Shranjevanje:** JSON datoteka v uporabniški mapi (najvišji doseženi nivo, nastavitve, ime in izgled lika).

### Struktura repozitorija
```text
README.md           — ta datoteka (zagon, kontrole, povezave)
Build/              — Windows build (WitchWay.exe, samostojen)
Documentation/      — dokumentacija ekipe
project.godot       — Godot 4.3 projekt (izvorna koda v korenu)
_autoloads/         — singletoni: EventBus, GameManager, SaveManager, AudioManager, Narrator
assets/             — sprite-i, zvoki, shaderji, pisave
data/npcs/          — podatki o pošastih (.tres, NpcData)
scenes/             — main.tscn, igralec, NPC-ji, sobe, objekti, UI
scripts/
  actors/           — igralec, NPC-ji, otroci, Stalker
  generators/       — house_generator.gd (proceduralna nadstropja)
  levels/           — room.gd (gradnja sobe), wall_outlines.gd
  objects/          — vrata, predali, pasti, skrivališča, maske, trgovec
  fx/               — glitch efekti, dread, lažni zidovi
  ui/               — HUD, meniji, jumpscare, trgovina
```

### Viri in licence
- **Modern Interiors (free)** — LimeZu — https://limezu.itch.io/moderninteriors — samo nekomercialna uporaba.
- **Press Start 2P** — CodeMan38 — SIL Open Font License (`assets/fonts/OFL.txt`).
- Zvočni učinki in del grafik (pošasti, jumpscare obrazi, predmeti) so ustvarjeni s pomočjo AI. Podrobnosti o uporabi AI so v dokumentaciji.

---

## Za razvijalce

### Namestitev in prvi zagon
1. **Kloniraj repozitorij:**
   ```powershell
   git clone https://github.com/Anchevskiii/GameJam2026-WitchWay-.git
   cd GameJam2026-WitchWay-
   ```
2. **Zaženi namestitev okolja:** dvakrat klikni `setup.bat` (ali `.\setup.ps1`). Skripta prenese prenosni **Godot 4.3** v `.tools/godot/`.
3. **Odpri projekt:** dvakrat klikni `open_project.bat`.

### Testiranje in izvoz
- **F5** zažene celotno igro (`scenes/main.tscn`), **F6** samo odprto sceno.
- **Izvoz za Windows:** Project → Export → *Windows Desktop* (nastavitve so v `export_presets.cfg`, izvozi v `Build/WitchWay.exe`). Potrebne so Godot 4.3 export predloge.

### Delo v ekipi
- Vsaka funkcionalnost na svoji veji `feature/...`, nato Pull Request v `dev`; stabilne verzije gredo v `main`.
- Godot scene (`.tscn`) se težko združujejo — ena scena naenkrat na enega razvijalca.
