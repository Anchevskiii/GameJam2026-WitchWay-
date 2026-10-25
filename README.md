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

## 1. Povzetek projekta (Game Design Document)
**Ime igre:** It's a Feature, Not a Bug: Halloween Edition  
**Zvrst:** 2D Top-Down Procedural Horror Dungeon Crawler  
**Tema:** Noč čarovnic (Halloween) + "Bug kot mehanika"  
**Pogon:** Godot 4.3 (GDScript)

Igra je neskončen (endless replayability) proceduralno generiran "dungeon crawler". Igralec prevzame vlogo protagonista, ki obišče hišo strahov in ugotovi, da iz nje ni izhoda. Prostori (sobe, nadstropja, kleti, podstrešja) se generirajo sproti. Namesto klasičnega boja je glavni poudarek na preživetju, obvladovanju strahu in iskanju "hroščev" (bugs), ki omogočajo napredovanje.

---

## 2. Igralne mehanike in pravila

### 2.1 Sanity Bar (Sistem prestrašenosti)
- **Delovanje:** Igralec ima vrstico "Sanity", ki se polni ob strašljivih dogodkih in stiku z entitetami.
- **Fail State (Game Over):** Če Sanity bar preseže limit, se igralec od prevelikega strahu "polula v hlače". Posledično je izključen iz hiše strahov.
- **Kaznovanje:** Ob Game Over situaciji igralec ne izgubi celotnega napredka, temveč se vrne na začetek istega (najtežjega osvojenega) nivoja.
- **Tutorial / Začetek:** Igra se začne v mali začetni sobi, kjer igralec spozna mehaniko premikanja, odpiranja omar in delovanja Sanity bara. Sosednje sobe so na začetku zatemnjene.

### 2.2 CPU Overload Bar (Bug as a Feature - Stalni hrošč)
- **Delovanje:** Tekom igranja se polni skriti ali vidni "CPU Overload" status.
- **Glitch Mode:** Ko ta bar doseže kritično mejo, se trenutni dungeon "pokvari". Luči začnejo utripati (flickering), sobe se pogreznejo v popolno temo.
- **Skrite nevarnosti:** V tem načinu se pojavijo nevidne pasti, ovire in entitete, ki se prikažejo le za kratek trenutek (flicker). Če igralec v temi stopi na napačno mesto, dobi ogromen skok v prestrašenosti.

### 2.3 The "Feature" Bug (Cilj vsakega nivoja)
- Glavni cilj igralca ni le preživeti, temveč najti namerno programsko napako v generirani sobi in jo izkoristiti (exploit).
- **Primeri hroščev:**
  - *Hitbox clipping:* Zid, ki izgleda trden, vendar se da skozenj iti.
  - *Zlomljena vrata:* Vrata, skozi katera igralec načeloma ne bi smel, a ga "bug" spusti naprej.
- **Namen hrošča:** Ta "bug" pogosto ne vodi direktno do cilja, temveč igralcu omogoči dostop do ključnega predmeta ali zaklenjene sobe, ki je nujna za dokončanje nivoja.

### 2.4 "Living Room" (Safe Zone)
- Med posameznimi dungeoni/nivoji igralec preide v varno sobo ("Living Room" - besedna igra na "dead/living").
- V tej sobi ni entitet in prestrašenosti. Služi kot checkpoint (točka shranjevanja) in kraj za oddih.

---

## 3. Entitete, objekti in cilji (Objectives)

### 3.1 Entitete (Halloween strašila)
Po hiši patruljirajo ali se naključno pojavljajo različne entitete, ki želijo prestrašiti igralca:
- **Zombiji** (počasni, vztrajni)
- **Duhovi** (grejo lahko skozi določene stene)
- **Jack-o'-lanterns** (izrezljane buče, ki lahko eksplodirajo v smeh)
- **Čarovnice in Nune** (ustvarjajo specifične zvoke in imajo unikatne jumpscare mehanike)

### 3.2 Okoljski "Jumpscares" (Aktivnosti)
Hiša je živa in poskuša igralca prestrašiti preko objektov:
- Luč nenadoma pade na tla in se razbije.
- Omara se z glasnim pokom prevrne.
- Ventilacijski jašek zapiska in v igralca pihne zrak.
- Nenadna ugasnitev luči v posamezni sobi ob spremljavi glasnega zvoka.

### 3.3 Cilji (Objectives) v sobi
Igralec mora pred prehodom v naslednji dungeon poiskati ključne predmete in interaktivne objekte. Na voljo so predmeti, kot so:
- **Zemljevid (Map):** Odkrije dele proceduralno generirane hiše.
- **Ključ:** Oklene specifična vrata.
- **Svetilka / Lanterna (Flashlight/Lantern):** Nujna za osvetlitev temnih sob in preživetje "Glitch Mode-a".

---

## 4. Tehnologija, Arhitektura in Podatkovni model

Projekt uporablja izključno Godot 4.3+ in GDScript. Ne uporablja se C#.[cite: 1]

**Osnove Godota za ta projekt:**[cite: 1]
- **TileMapLayer:** Uporablja se za proceduralno risanje tal, sten in sob.[cite: 1]
- **Lighting:** Z uporabo `CanvasModulate` se celotna scena zatemni, `PointLight2D` (ki ga nosi igralec) in `LightOccluder2D` (na stenah) pa ustvarjata vidno polje in sence.
- **Fizika in Interakcije:** `CharacterBody2D` se uporablja za igralca (Top-Down premikanje), `Area2D` pa za cone interakcij (iskanje hroščev, odpiranje omar).

**Struktura direktorijev:**[cite: 1, 2]
```text
res://
├── _autoloads/                  # Globalne skripte (Singletons), ki tečejo v ozadju
│   ├── event_bus.gd             # Centralni signali (npr. player_scared, bug_triggered)
│   ├── game_manager.gd          # Stanje igre (trenutni level, CPU overload, game over)
│   ├── save_manager.gd          # Shranjevanje napredka v JSON
│   └── audio_manager.gd         # Globalno predvajanje zvokov in jumpscarov
├── assets/                      # Vsi grafični in zvočni viri
│   ├── audio/
│   │   ├── music/               # Ambientalna glasba za dungeon in Living Room
│   │   └── sfx/                 # Jumpscare zvoki (padec omare, pok luči, pihanje zraka)
│   ├── sprites/
│   │   ├── player/              # Animacije igralca (hoja, strah, "polulane hlače")
│   │   ├── entities/            # Zombiji, duhovi, čarovnice, nune, jack-o'-lanterns
│   │   ├── environment/         # Tileseti za stene, tla, vrata, klet, podstrešje
│   │   ├── objects/             # Omare, predali, luči, zračniki
│   │   └── items/               # Ikone za ključ, mapo, svetilko (lantern/flashlight)
│   └── shaders/                 # Shader za "CPU Overload" glitch in flickering efekt
├── data/                        # Godot Resources (.tres) - podatkovni model
│   ├── entities/                # Konfiguracije pošasti (npr. zombie_stats.tres)
│   ├── items/                   # Podatki o predmetih (npr. key_data.tres, map_data.tres)
│   └── levels/                  # Pravila generiranja (npr. level_1_config.tres)
├── scenes/                      # Sestavljene Godot scene (.tscn)
│   ├── main.tscn                # Glavna vstopna scena, ki združuje UI in trenutni nivo
│   ├── actors/
│   │   ├── player.tscn          # Igralec + PointLight2D (svetilka) + kamera
│   │   └── base_entity.tscn     # Osnova za strašila (duhovi, zombiji)
│   ├── levels/
│   │   ├── tutorial_room.tscn   # Začetna mala soba za učenje mehanik
│   │   ├── living_room.tscn     # Safe camp med nivoji (shranjevanje, mir)
│   │   └── dungeon_level.tscn   # Glavna scena s TileMapLayer za proceduralni labirint
│   ├── objects/
│   │   ├── interactables/       # Omare, predali, vrata (stvari, ki jih igralec odpira)
│   │   ├── traps_scares/        # Padajoča luč, omara, ki pade, ventil za zrak
│   │   └── bugs/                # Namerni hrošči (lažni zid brez hitboxa, glitch vrata)
│   └── ui/
│       ├── hud.tscn             # Sanity Bar, CPU Overload Bar, inventar (ključ/mapa)
│       ├── main_menu.tscn       # Začetni zaslon
│       └── game_over.tscn       # Zaslon ob izgonu iz hiše ("polulane hlače")
└── scripts/                     # Modularna logika in skripte (.gd)
	├── components/              # Komponente, ki jih pripnemo na druge objekte
	│   ├── sanity_component.gd  # Računanje strahu na igralcu
	│   ├── scare_source.gd      # Skripta na pošastih/pasteh, ki oddaja strah
	│   └── interactable.gd      # Osnovna logika za interakcijo (tipka E)
	├── generators/
	│   ├── room_generator.gd    # Algoritem za sprotno generiranje sob in hodnikov
	│   └── bug_spawner.gd       # Logika, ki v vsak nivo vstavi obvezen "Feature Bug"
	└── resources/               # Definicije za Custom Resources (.gd za .tres datoteke)
		├── entity_data.gd
		└── level_config.gd
```

**Podatkovni model (Kratek pregled):**[cite: 1, 2]
- **Shranjevanje napredka (Save System):** Uporablja se preprosta `.json` datoteka (shranjena na lokalni disk ob vstopu v *Living Room*), ki beleži le najvišji doseženi nivo in nastavitve igralca.[cite: 1, 2]
- **Podatki o entitetah in nivojih:** Konfiguracije zombijev, duhov in parametrov za generiranje sob (koliko sob, kateri hrošč) se shranjujejo preko vgrajenih **Godot Resources (`.tres`)** datotek.[cite: 1, 2] Te omogočajo hitro nastavljanje v Godotovem inšpektorju brez uporabe zunanjih baz podatkov.[cite: 1, 2]

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
