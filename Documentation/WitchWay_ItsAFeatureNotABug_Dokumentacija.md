# It's a Feature, Not a Bug: Halloween Edition — Dokumentacija

> GameJam BEST x ŠS FERI 2026 · Ekipa: Bodoči Poljedelci · Build: **v0.2.0** (Windows x64)

---

## I. KRATEK POVZETEK

**1. Podatki o ekipi**
- Ime ekipe: Bodoči Poljedelci
- Člani in vloge: 
  - Jan Ančevski – programiranje (NPC-ji, zvok, meniji, trgovina, ekonomija sladkarij)
  - Niko Pozderec – programiranje (generiranje sob, pasti, jumpscari, grafika sob)
  - Klemen Novak – Effekti (grafika, zvok, izgled) 
**2. Ime igre**
- Naslov: Witch Way
- Slogan: Boo, buffer overload

**3. Povzetek koncepta**
Igralec je ujet v neskončni, proceduralno generirani hiši strahov in mora preživeti čim več nadstropij. V vsakem nadstropju poišče ključe, skrite v predalih in omarah, nato pa pobegne skozi izhod, preden ga pošasti prestrašijo do konca. Namesto boja igralec pošasti prestraši nazaj (»BOO!«); vsak strah preobremeni »CPU« hiše. Ko se hiša sesuje (GLITCH), postanejo hrošči igre del igranja: nekateri zidovi so prehodni, vrata se odprejo, luči utripajo – *it's not a bug, it's a feature*.

**4. Ključne mehanike**
- **Sanity (prestrašenost):** pošasti, pasti in jumpscari zmanjšujejo sanity; pri 0 je konec igre.
- **BOO + CPU/GLITCH:** strašenje pošasti polni CPU-števec hiše; ob preobremenitvi se hiša »pokvari« in odpre izhod.
- **Namerni hrošči:** zidovi, skozi katere se da hoditi, »glitchana« vrata in utripajoče sobe.
- **Ključi in iskanje:** zaklenjen izhod, ključi v pohištvu (drži E); zadnji ključ prebudi Stalkerja, ki gre skozi stene.
- **Pasti in skrivanje:** pasti za medvede, škripajoče deske (hrup prikliče pošasti), jumpscare točke; skrivanje v omarah, maska.

**5. Tehnologije in orodja**
Godot 4.3 (GDScript), Git + GitHub, Python (Pillow) za generiranje dela pixel-art grafik, Claude Code (AI asistent za kodo).

**6. Glavni poudarki**
Celotna hiša je proceduralno generirana (BSP-razdelitev v sobe z različnimi temami, pohištvom, pastmi in ključi), težavnost pa raste vsaka tri nadstropja. Tema »it's a feature« ni le okras: sesutje hiše (GLITCH) je glavni način pobega in spremeni pravila igre.

**7. Uporaba AI in zunanjih virov**
- Ocenjeni delež AI: **85 %** – odstotek pomeni delež napisane kode, ki jo je predlagal AI-asistent in so jo člani pregledali, preizkusili in prilagodili.
- AI-generirano: velik del GDScript kode (Claude Code), Python skripte za generiranje nekaterih sprite-ov (npr. jumpscare obrazi, pošasti, predmeti).
- Prevzeto z interneta: notranja oprema »Modern Interiors (free)« – LimeZu (limezu.itch.io/moderninteriors, nekomercialna licenca); pisava Press Start 2P (SIL OFL); zvočni učinki – [https://pixabay.com/](https://pixabay.com/ "https://pixabay.com/").

**8. Status izdelka**
- Deluje: meni, nastavitve, prilagoditev lika, Living Room s trgovino, neskončna generirana nadstropja, NPC-ji, pasti, jumpscari, ključi, Stalker, GLITCH, shranjevanje napredka.
- Build: **v0.2.0** za Windows (x64) – `Build/WitchWay.exe`.
- Omejitve: ravnotežje težavnosti na visokih nadstropjih ni do konca preizkušeno, ni glasbe v ozadju (le ambient zvoki).

---

## II. RAZŠIRJENI DEL

### 1. Razvojni proces
- **Načrtovanje:** začeli smo z Game Design dokumentom (README) – sanity, CPU overload, »feature« hrošči in varna soba (Living Room). Ideje smo nato prilagajali sproti po igranju.
- **Delitev dela:** vsak član je delal na svoji veji (`feature/...`) – npr. `feature/room-design` (sobe, pasti, jumpscari), `feature/entity-scare-mechanics` (pošasti), `feature/main-menu-settings` (meniji), `feature/candy-economy-shop` (trgovina). Veje smo prek Pull Requestov združevali v `dev`, stabilne verzije pa v `main` (release v0.1.0).
- **Orodja v treh dneh:** Godot 4.3, GitHub (PR-ji, veje), Claude Code za pisanje in razhroščevanje kode, avtomatski testi v Godotu (skripte, ki zaženejo igro in preverijo mehanike), Python/Pillow za grafiko.

### 2. Podrobnosti o mehanikah

**Cilj:** preživeti čim več nadstropij hiše strahov. Vsako nadstropje ima izhod (»glitch vrata«); ko ga dosežeš, greš naprej. Vmes se vrneš v **Living Room** – varno sobo brez pošasti, kjer se napredek shrani.

**Kontrole**

| Tipka | Akcija |
|---|---|
| W A S D / puščice | premikanje |
| Shift | tek |
| E (drži) | iskanje po pohištvu, interakcija |
| Space | BOO! – prestraši pošasti |
| F | svetilka (vklop/izklop) |
| R | nadeni si masko (če jo imaš) |
| Q | Glitch naboj (kupljen v trgovini) |
| Esc | pavza |

**Sistemi**
- **Sanity:** zmanjšajo ga pošasti, ki te ujamejo, pasti, jumpscari in temni GLITCH-način. Sladkarije (ki jih izpustijo prestrašeni otroci) ga povrnejo. Pri 0 se igralec »polula v hlače« in mora ponoviti nadstropje.
- **CPU overload / GLITCH:** ko prestrašiš pošast (BOO), se CPU hiše napolni. Pri 100 % se hiša sesuje: luči utripajo, slika se »pokvari« (shader), izhod se odpre. Na zabavah (party nadstropja) en dober strah povzroči paniko več gostov naenkrat.
- **Ključi:** od določenega nadstropja je izhod zaklenjen. Ključi so skriti v predalih in omarah; iskanje traja nekaj sekund (drži E). Nekateri predali skrivajo sladkarije ali jumpscare.
- **Stalker:** ko najdeš zadnji ključ, se »hiša prebudi« – pojavi se Stalker, ki hodi skozi stene in te lovi. BOO ga za trenutek omami.
- **Pasti:** past za medvede (te za nekaj časa ujame in boli), škripajoče deske (glasne – pošasti pridejo pogledat), jumpscare točke (obraz čez zaslon + nova pošast v bližini).
- **Pošasti (NPC-ji):** duh, buča, vampir, volkodlak, čarovnica, netopir … Vsaka ima svoje podatke (hitrost, doseg, ali lovi). Stanja: mirovanje/tavanje, preiskovanje hrupa, lov, prežanje v kotu, skrivanje. Slišijo hrup (pasti, deske) in pridejo preverit.
- **Trgovina in sladkarije:** sladkarije so valuta. V Living Roomu in na avtomatih v nadstropjih kupiš maske, glitch naboje, svetilko in nadgradnje (npr. hitrejše iskanje).
- **Težavnost:** vsaka tri nadstropja je nova stopnja – več pošasti, več pasti in ključev, temnejše sobe.

**Tema v igranju:** »It's not a bug, it's a feature« je jedro igre – za pobeg moraš hišo namerno pokvariti (CPU overload), nekateri zidovi so namerno »buggy« in prehodni, glitch vrata pa so dobesedno napaka, ki postane izhod. Halloween je prisoten skozi pošasti, otroke v kostumih, sladkarije in hišo strahov.

### 3. Tehnična izvedba

**Struktura projekta**
```text
_autoloads/   globalni singletoni: EventBus (signali), GameManager (stanje, sanity, CPU, ključi, trgovina),
              SaveManager (JSON shranjevanje), AudioManager, Narrator
scenes/       main.tscn (UI + svet v SubViewportu), igralec, NPC-ji, sobe, UI scene
scripts/
  generators/ house_generator.gd – proceduralno generiranje nadstropij
  levels/     room.gd – izgradnja sobe iz ASCII postavitve
  actors/     igralec, NPC-ji, otroci, Stalker
  objects/    vrata, predali, pasti, skrivališča, trgovec
  ui/         HUD, meniji, jumpscare, trgovina
data/npcs/    .tres podatki za vsako pošast (NpcData resource)
assets/       sprite-i, zvoki, shaderji, pisave
```

**Pomembni sistemi**
- **Proceduralno generiranje:** `HouseGenerator` z BSP (binary space partitioning) razdeli nadstropje v sobe, jih poveže s hodniki in vrati, nato vsaki sobi dodeli temo (kuhinja, spalnica, knjižnica …), pohištvo, pošasti, pasti in ključe. Rezultat je ASCII-mreža z legendo, ki jo `Room` pretvori v ploščice, kolizije in objekte.
- **Stene in prehodni zidovi:** običajni zidovi (X) imajo teksturo in kolizijo; »buggy« zidovi (F) izgledajo pokvarjeno, a so prehodni. Robovi sten se rišejo s kodo (`WallOutlines`), ker so ploščice s 4 sosedi puščale luknje v T- in L-stikih.
- **Svetloba:** `CanvasModulate` zatemni sceno, igralec nosi `PointLight2D`, stene imajo `LightOccluder2D` za sence.
- **Signali (EventBus):** sistemi se ne kličejo neposredno, ampak prek signalov (`noise_made`, `jumpscare_requested`, `keys_changed`, `house_awakened` …), zato so pasti, pošasti in UI ločeni.
- **NPC AI:** končni avtomat stanj v `npc.gd`; hrup (`noise_made`) sproži preiskovanje, Stalker uporablja lastno logiko sledenja/tavanja.

**Izzivi in rešitve**
- *Nemogoči nivoji* (izhod se zapre, preden ga dosežeš) → čas odprtja vrat je odvisen od razdalje do izhoda.
- *Okrasje v stenah* → široki predmeti se ne postavljajo v kote sob.
- *Manjkajoči koti sten* → robovi sten se rišejo programsko.
- *Združevanje dela več ljudi* → veje + PR-ji + avtomatski testi, ki po združitvi preverijo, da mehanike še delujejo.

### 4. Vizualni in zvočni del
- **Slog:** 2D pixel art, pogled od zgoraj (3/4 pogled za stene in pohištvo), temno vzdušje s svetilko.
- **Grafika:** notranja oprema – LimeZu Modern Interiors (free, prevzeto). Pošasti, igralec, jumpscare obrazi, predmeti – Napisane z AI.
- **Shaderji:** glitch efekt ob sesutju hiše, vidno polje (FOV), veter za drevesa – napisani v projektu.
- **Animacije:** hoja s »stumble« animacijo, tweeni za jumpscare (bliskavica, tresenje), utripanje luči.
- **Zvok:** zvočni učinki (krik, škripanje, smeh, srčni utrip, ambient odmevi) – ustvarijen s pomočjo AI. Ločen avdio bus za oddaljene, pridušene zvoke iz drugih sob.

### 5. Namestitev in zagon igre (Windows)
1. Prenesi repozitorij: na GitHubu **Code → Download ZIP** (ali `git clone https://github.com/Anchevskiii/GameJam2026-WitchWay-.git`).
2. Razpakiraj ZIP in odpri mapo **`Build/`**.
3. Dvoklikni **`WitchWay.exe`**. Druge datoteke niso potrebne – vsi podatki igre (`.pck`) so vgrajeni v .exe.
4. Če Windows SmartScreen opozori (»Windows protected your PC«), klikni **More info → Run anyway** (datoteka ni digitalno podpisana).
5. Dodatni runtime-i niso potrebni. Igra potrebuje grafično kartico s podporo za Vulkan ali OpenGL 3.3.

**Podatki o buildu**

| | |
|---|---|
| Verzija | v0.2.0 |
| Platforma | Windows 64-bit (x86_64) |
| Datoteka | `Build/WitchWay.exe` (~99 MB, en sam .exe) |
| Pogon | Godot 4.3-stable (uradna Windows predloga za izvoz) |
| Izvorna koda | veja `dev`, commit `8864a01` |
| Shranjevanje | napredek se shrani v `%APPDATA%\Godot\app_userdata\Witch Way?\` |

**Zagon iz izvorne kode:** namesti Godot 4.3, odpri `project.godot` (ali zaženi `open_project.bat`), pritisni F5.

### 6. Uporaba AI in zunanjih virov
- **Orodja:** Claude Code (Anthropic).
- **Naloge:** pisanje in refaktoriranje GDScript kode, razhroščevanje (npr. koti sten, pravičnost časa vrat), avtomatski testi, Python skripte za generiranje sprite-ov, del besedil.
- **Preverjanje:** vsako spremembo smo zagnali in odigrali, avtomatski testi pa so preverili mehanike (npr. 400 generiranih nadstropij brez napak). Spremembe so šle skozi PR pregled preden so bile združene.
- **Zunanji asseti:**
  - Modern Interiors (free) – LimeZu – https://limezu.itch.io/moderninteriors – nekomercialna uporaba.
  - Press Start 2P – CodeMan38 – SIL Open Font License (`assets/fonts/OFL.txt`).
  - Zvočni učinki – ustvarjeni s pomočjo AI.
- **Ocena deleža AI:** 85 %.

### 7. Testiranje
Poleg ročnega igranja smo napisali testne scene v Godotu, ki zaženejo igro in avtomatsko preverijo mehanike (pasti, ključi, Stalker, GLITCH, sladkarije, menije). Generator smo preizkusili na 400 naključnih nadstropjih (vsa so rešljiva, s pravim številom ključev in pasti). Odpravili smo npr. nemogoče nivoje, okras v stenah, manjkajoče kote sten. Naučili smo se, da je treba teste posodabljati, ko se dizajn spremeni.

### 8. Načrti za naprej
- Več vrst pošasti in jumpscarov, glasba v ozadju.
- Zemljevid nadstropja, več »feature« hroščev (npr. teleportacija skozi napačno teksturo).
- Lastna grafika namesto brezplačnega paketa (za morebitno komercialno izdajo).
- Boljše ravnotežje težavnosti na visokih nadstropjih.

---

## III. Demo video
30-sekundni posnetek igranja (1080 × 1920, 9:16, mp4): `WitchWay_ItsAFeatureNotABug_Video.mp4` [DOPOLNI: povezava].
