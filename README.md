# Witch Way? — It's a Feature, Not a Bug: Halloween Edition

> GameJam 2026 — oddajna različica

## Zagon (za organizatorje)
1. Prenesi repozitorij (ali `git clone https://github.com/Anchevskiii/GameJam2026-WitchWay-.git`).
2. Odpri mapo `Build/`.
3. Dvoklikni `WitchWay.exe` — igra se zažene brez Godota ali dodatnih knjižnic (Windows 10/11, 64-bit).

## Kontrole
| Tipka | Dejanje |
| --- | --- |
| W / A / S / D ali puščice | Premikanje |
| E | Interakcija / iskanje / odpri |
| F | Svetilka (flashlight) |
| Space | Prestraši (scare) |
| Shift | Sprint |
| Q | Glitch mode (crash hiše na zahtevo) |
| R | Nosi masko |
| Esc | Premor / nazaj |

## Povezave
- **Dokumentacija:** `Documentation/WitchWay_ItsAFeatureNotABug_Dokumentacija.md`
- **Video:** *(placeholder — dopolni s povezavo na 30s video)*
- **Repozitorij:** https://github.com/Anchevskiii/GameJam2026-WitchWay-

## Struktura repozitorija
```text
README.md           — ta datoteka (zagon, kontrole, povezave)
Build/              — Windows .exe (WitchWay.exe, samostojen)
Documentation/      — dokumentacija ekipe
... (koren)         — izvorni Godot 4.3 projekt (assets/, scenes/, scripts/, project.godot)
```

---

## 1. O igri

Ujet si v neskončni, proceduralno generirani hiši strahov. Vsako nadstropje je nova hiša sob, polnih pošasti, pasti in skritih ključev. Tvoj cilj je priti čim globlje — preden te pošasti prestrašijo do konca.

Ne boriš se — **strašiš nazaj**. Vsak »BOO!« preobremeni procesor hiše, in ko se ta sesuje, postanejo napake igre tvoj izhod. *It's not a bug, it's a feature.*

---

## 2. Kako igrati
1. Začneš v **Living Roomu** — varni sobi brez pošasti, kjer se napredek shrani. Tu pri trgovcu kupiš opremo s sladkarijami.
2. Skozi izhod vstopiš v **nadstropje**. Poišči **ključe** v predalih in omarah (drži **E**) — izhod je zaklenjen, dokler jih ne najdeš vseh.
3. Izogibaj se pošastim, se **skrij** v omaro ali jih **prestraši (Space)**. Vsak strah polni **CPU** hiše.
4. Ko CPU doseže 100 %, se hiša **sesuje (GLITCH)**: luči utripajo, slika se pokvari in **glitch vrata** se odprejo.
5. Ko najdeš zadnji ključ, se hiša **prebudi** — pojavi se **Stalker**, ki hodi skozi stene. Beži do izhoda!
6. Če tvoj **Sanity** pade na 0, se od strahu »poluliš v hlače« in ponoviš nadstropje.

---

## 3. Glavne mehanike
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

## 4. Tehnologija in arhitektura

- **Pogon:** Godot 4.3, izključno GDScript.
- **Proceduralno generiranje:** `HouseGenerator` z BSP razdeli nadstropje v sobe, jih poveže z vrati in vsaki dodeli temo (kuhinja, spalnica, knjižnica …), pohištvo, pošasti, pasti in ključe. Rezultat je ASCII-mreža, ki jo `Room` pretvori v ploščice, kolizije in objekte.
- **Svetloba:** `CanvasModulate` zatemni sceno, igralec nosi `PointLight2D`, stene imajo `LightOccluder2D`.
- **EventBus:** sistemi komunicirajo prek signalov (`noise_made`, `jumpscare_requested`, `keys_changed`, `house_awakened` …).
- **Shranjevanje:** JSON datoteka v uporabniški mapi (najvišji doseženi nivo, nastavitve, ime in izgled lika).

### 4.1 Struktura projekta
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
  actors/           — NPC-ji (pošasti), otroci, Stalker
  components/       — igralec (player_controller.gd), animacija hoje, interakcije
  generators/       — house_generator.gd (proceduralna nadstropja)
  levels/           — room.gd (gradnja sobe), wall_outlines.gd
  objects/          — vrata, predali, pasti, skrivališča, maske, trgovec
  fx/               — glitch efekti, dread, lažni zidovi
  ui/               — HUD, meniji, jumpscare, trgovina
```

### 4.2 Viri in licence
- **Modern Interiors (free)** — LimeZu — https://limezu.itch.io/moderninteriors — samo nekomercialna uporaba.
- **Press Start 2P** — CodeMan38 — SIL Open Font License (`assets/fonts/OFL.txt`).
- Zvočni učinki in del grafik (pošasti, jumpscare obrazi, predmeti) so ustvarjeni s pomočjo AI. Podrobnosti o uporabi AI so v dokumentaciji.

---

## 5. Navodila za razvijalce (Developer Quickstart & Workflow)

### 5.1 Namestitev in prvi zagon (60 sekund)
1. **Kloniraj repozitorij:**
   ```powershell
   git clone https://github.com/Anchevskiii/GameJam2026-WitchWay-.git
   cd GameJam2026-WitchWay-
   ```
2. **Zaženi namestitev okolja:**
   * Dvakrat klikni na `setup.bat` (ali v terminalu poženi `.\setup.ps1`).
   * Skripta samodejno prenese in nastavi prenosno različico **Godot 4.3** v `.tools/godot/`.
3. **Odpri projekt v Godot urejevalniku:**
   * Dvakrat klikni na `open_project.bat`. Odpre se Godot urejevalnik neposredno v tem projektu.

### 5.2 Hitro testiranje med razvojem
- **F5:** Zaženi celotno igro (vstopna scena `scenes/main.tscn`).
- **F6:** Zaženi samo trenutno odprto sceno (npr. testiranje samo igralca `player.tscn` ali posamezne sobe).
- **Urejevalnik kode:** Lahko uporabljaš vgrajeni urejevalnik v Godotu ali katero koli zunanje orodje (Antigravity IDE, VS Code, Cursor).

### 5.3 Pravila sodelovanja za ekipo (3 razvijalci)
Zaradi narave Godot scen (`.tscn`), ki se ob sočasnem urejanju hitro zapletejo v Git konfliktih, dosledno upoštevamo:
1. **Pravilo 1 razvijalec na 1 sceno:**
   - **Dev 1 (Igralec & Sanity):** `scenes/actors/player.tscn` in `scripts/components/sanity_component.gd`.
   - **Dev 2 (Generator sob & Bug mehanike):** `scenes/levels/dungeon_level.tscn` in `scripts/generators/`.
   - **Dev 3 (UI, Zvok & Asseti):** `scenes/ui/hud.tscn`, zvoki v `_autoloads/audio_manager.gd`.
2. **Git Feature Branches:**
   ```powershell
   git checkout main
   git pull
   git checkout -b feature/ime-funkcionalnosti
   # ... razvijaj ...
   git add .
   git commit -m "Opis narejenega"
   git push -u origin feature/ime-funkcionalnosti
   ```
