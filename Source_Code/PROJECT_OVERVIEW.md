# Diablo Survivors

Diablo Survivors is a local survival game that uses graphics and audio from an original game you have installed. Choose **Diablo I** or **classic Diablo II**, select its folder, and play an authored survival campaign. You only need the game you choose. Original game assets stay on your computer and are excluded from the source/release package.

The current development build runs on Windows using Python, PyQt6, SQLite, Pillow and Godot **4.6.2**.

**Diablo II compatibility:** Diablo II and Diablo II: Lord of Destruction work with the original CD versions. Battle.net versions have not been tested.

**v0.23 beta:** default player and enemy ranged attack distances are halved, and projectiles stop at their attack-distance limit. Long reach now increases both targeting and projectile travel by 10% per tier. Firebolt, Bone Spear and Firestorm retain their original imported spell sprites.

## Start the app

Double-click **Run_Diablo_Survivors.bat**.

On first launch:

1. Choose Diablo I or Diablo II (Classic).
2. Click **Browse…** and select that game's installation folder.
3. Click **Use this game and Play**. The app identifies the installation, builds its local asset cache/database, and opens the main menu.
4. Choose an unlocked character, area and difficulty, then click **Play**.

The choice and folder are remembered. Later launches reuse the cache. Click **Change game** in the main menu, or run **Choose_Game.bat**, to choose another game or folder. Selecting Diablo II automatically detects Lord of Destruction; having both games installed is optional.

For a fresh source checkout:

```powershell
python -m pip install -r requirements-dev.txt
python scripts/setup_stormlib.py
```

Install Godot 4.6.2 and set `GODOT_BIN` to its executable, or select the executable in `Run_Manager.bat` → Settings. This machine's configured Godot path lives in ignored `.local/tooling.json` and is not distributed. MPQ extraction uses StormLib 9.40.

## Features

- First-run source-game selection, editable installation folders and remembered preferences.
- Diablo I sprite/audio import, original Tristram geometry, dungeon tiles, region enemy rosters and original sound associations.
- Classic Diablo II layered DCC animations composed using COF draw order, DC6 skill icons, DT1 floor tiles and original WAV audio.
- Five playable Diablo II class unlocks without LoD; seven with LoD. The character menu scrolls and shows class sprites.
- Automatic targeting, movement while attacking, damage variation, critical hits, floating damage numbers and enemy deaths.
- Run upgrades with tiers, maximum ranks, class-based options, extra attacks, more targets, larger attack areas and longer boosts.
- Persistent gold, progressive-cost permanent upgrades, saved selections, achievements and completion records.
- Easy, Hard and Legendary modes for every area, with sequential difficulty/area unlocks and completion badges.
- Maps wrap at opposite edges: right to left and top to bottom. Nearby enemies, attacks and collectibles stay close across a boundary; terrain repeats around the camera.
- Settings in the main menu and pause menu: music on/off, music volume, SFX volume, and damage screen shake on/off. Preferences persist in `settings.json` beside progress. Original regional soundtracks loop for each map; maps in the same region share a track. D2 music requires `d2music.mpq` in the selected installation.
- Sequential enemy challenges, separate one-time rewards per area/difficulty and repeat-completion records.
- Rare treasure goblins, loot rewards and the special cow-hunt portal event.
- Glowing walk-over collectibles, nearby-collectible minimap, neon particles and mist during timed boosts.
- Health colors that shift from green through yellow/orange to red, plus red damage flashes.
- Pause, character sheet, end-of-run rewards and an explicit Reset Progress confirmation.
- Local caches and bundled asset/version indexes. Source installations are read only.

## Supported source games

| Source | Playable classes | Assets |
|---|---|---|
| Diablo I | Warrior, Rogue, Sorcerer | Locally imported CEL/CL2 sprites, tiles/maps, interface art and audio |
| Classic Diablo II | Barbarian, Amazon, Paladin, Necromancer, Sorceress | DCC/COF actors, DT1 floors, DC6 icons and audio |
| Classic Diablo II + Lord of Destruction | All five above, plus Assassin and Druid | Expansion assets override base assets where appropriate |

**Diablo II: Resurrected, including Infernal Edition, is not supported.** Select a classic installation containing `d2data.mpq`, `d2char.mpq` and `d2sfx.mpq`. LoD is detected from `d2exp.mpq`; `patch_d2.mpq` takes precedence when present.

Bundled metadata records the original classic base installation (Game.exe product version `1.0.0.1`) and the locally validated LoD `1.0.7.0` installation, including archive fingerprints and internal asset paths. LoD's seven classes have been decoded and launched locally. A separate base-only import has also been tested with expansion archives excluded. Other classic patch layouts may resolve through the shared formats, but their fingerprints are recorded as compatible rather than claiming a verified edition match.

Versions tested during development:

| Game | Local version | Validation |
| --- | --- | --- |
| Diablo I, GOG English | Executable product version `1.0.9.2` | Asset import, graphics/audio, and survival runtime tested. |
| Diablo II, classic English | Original base executable product version `1.0.0.1` | Installation inspected and representative assets decoded; base-only import/runtime also tested with expansion archives excluded from the current installation. |
| Diablo II: Lord of Destruction, English | Executable product version `1.0.7.0` (1.07) | Full import, graphics/audio, and all seven playable classes tested locally. |

The Diablo II content currently uses **Diablo Survivors's shared authored survival areas**, Skeleton/Zombie/Fallen melee enemies plus Skeleton Archer, lightning Skeleton Mage, Fallen Shaman and Quill Rat ranged enemies, and distinct starter kits for all seven classes. This is an adaptation using original assets, not a recreation of Diablo II's campaign, complete bestiary or full class skill trees. Diablo I's more developed scenery/collision maps remain specific to its asset pack.

## Class unlocks

Diablo I starts with Warrior. Rogue unlocks at 500 lifetime kills; Sorcerer unlocks after completing Easy in a normal area.

Diablo II unlocks are:

| Class | Unlock requirement | Starter kit |
|---|---|---|
| Barbarian | Available immediately | Weapon cleave |
| Amazon | 500 lifetime kills | Piercing arrows |
| Sorceress | Complete Easy in a normal area | Firebolt |
| Paladin | Complete Hard in any area | Cleave and regeneration |
| Necromancer | 1,000 lifetime kills | Bone Spear and a skeletal ally |
| Assassin | 2,000 lifetime kills; LoD installed | Twin strikes |
| Druid | Complete Legendary in any area; LoD installed | Firestorm and regeneration |

These are Diablo Survivors survival kits. Assassin and Druid are omitted when LoD is absent, rather than shown as classes the installation cannot supply. Installing LoD later changes the archive fingerprint and prepares the additional class assets automatically on the next launch.

## Areas and difficulties

The Diablo I campaign contains 22 authored areas corresponding to its 16 dungeon floors, town and additional quest/bonus layouts. Diablo II uses its own Acts and combat areas; see the current bestiary coverage below.

| Difficulty | Duration | Completion unlocks |
|---|---:|---|
| Easy | 8 minutes | Hard in the same area |
| Hard | 12 minutes | Legendary in the same area |
| Legendary | 16 minutes | Easy in the next area |

You may replay any unlocked mode. Completing a mode again does not skip ahead. Area rows show rounded Easy/Hard/Legendary badges with checkmarks for completions. Titles beyond the next locked area remain concealed. The last played character, area and difficulty are restored at startup.

Hard and Legendary increase base enemy health, damage, speed and spawn pressure. Enemy challenge targets increase by 1.75× and 2.75× respectively; single named-boss objectives stay at one kill. The last minute's countdown becomes red and pulses. Death ends the current run and keeps permanent progress; Legendary is not a permanent-death mode.

## Challenges, gold and upgrades

Only the active challenge appears during play. Completing it reveals the next milestone. Newly completed challenges award **one gold each at run expiry**. Claims are separate for each area and difficulty, and a claimed challenge never pays again on replay. Repeat completions still contribute to records. Run-end rewards also include the configured survival/kill/loot earnings.

Spend saved gold in **Permanent shop**. Its Movement, Defense, General and Class tabs offer progressively more expensive ranks. Purchases are saved immediately, logged with their resulting rank/cost/balance, and apply to the next run. Upgrades chosen during a run are temporary and expire with that run; they are separate from shop purchases.

Timed Speed and XP Magnet pickups last at least 35 seconds. Lasting power run upgrades extend their duration. Healing pickups restore health immediately. Pickups respawn after 45 seconds at a different location. Their particles stay anchored to the item while the camera moves. Purple bars show active boost names and remaining time.

The rare cow hunt remains a separate **eight-minute** event. Its 500-cow challenge and bonus rewards are recorded separately from normal-area difficulty progression.

## Controls

| Control | Action |
|---|---|
| WASD / arrow keys | Move |
| Automatic | Target and attack enemies |
| Space / Esc | Pause / resume |
| 1–3 | Choose a run upgrade |
| C | Open / close character sheet |
| M | Mute / unmute sounds |
| E | Enter a nearby cow portal |
| R | Restart where available |

## How importing and caching work

The distributed project contains **metadata and decoder code**, not extracted proprietary artwork or sounds. Reviewed profiles and path indexes live in `profiles/` and `catalogs/`. Users do not need to discover internal filenames or manually map frames.

When a folder is selected, its archive layout/version is identified and the known assets required by the selected pack are decoded into a private cache. Diablo II resolves patch archives before expansion archives, then base archives; COF component order and sprite anchors are preserved. WAV samples are repacked into canonical PCM RIFF files for Godot playback. Original source hashes and paths are retained for provenance.

SQLite records the asset inventory and imported resources. Cache generations depend on source file fingerprints and decoder version, so changing or expanding an installation prepares a new generation. Unchanged launches reuse the existing manifest and decoded images/audio; no archive enumeration or image decoding is repeated on a warm launch.

The first preparation takes longer than later launches. Diablo Survivors never modifies the original game installation.

## Saves, databases and cache locations

All paths below are relative to the project directory:

| Location | Contents |
|---|---|
| `.local/launcher/settings.json` | Selected game and remembered installation folders |
| `.local/demo/progress/diablo1-v2.json` | Diablo I survival progress |
| `.local/demo/progress/diablo2-v2.json` | Diablo II / LoD survival progress |
| `.local/inspector/last_preparation.json` | Pointer to the current Diablo I inspector preparation/database |
| `.local/inspector/games/<id>/generations/<id>/assets.sqlite3` | Diablo I asset database |
| `.local/diablo2/active.json` | Current Diablo II manifest/database pointer and identity |
| `.local/diablo2/generations/<id>/assets.sqlite3` | Diablo II asset inventory and provenance |
| `.local/demo/`, `.local/diablo2/generations/<id>/` | Private decoded images, audio and runtime manifests |

Progress is separate for Diablo I and Diablo II. Base Diablo II and LoD share the Diablo II progress file. The source-game choice is remembered independently of gameplay progress.

**Reset Progress** appears above Exit. It asks **“Reset game progress?”** with Yes and No. Yes clears the selected game's gold, permanent upgrades, character/area/difficulty unlocks, challenges, achievements, records and last-played selections. The starting character and Cathedral/Easy selection are restored. No preserves the save. Other source-game progress and the remembered installation folders are retained.

Development currently uses fresh version-2 profiles; old-save migration is not included.

## Administrator tools and other run files

- `Run_Inspector.bat`: existing administrator archive/profile browser and Diablo I import workflow.
- `Run_Manager.bat`: development library/settings UI and Godot path configuration.
- `Run_Survival_Demo.bat`: direct Diablo I survival entry point, bypassing source selection.
- `Run_Diablo2_Survival.bat`: direct Diablo II playtest using the folder saved by the source picker.
- `Run_Tristram_Survival.bat`: direct Diablo I town playtest.
- `Run_Treasure_Event_Demo.bat`, `Run_Cow_Level_Demo.bat`: focused event playtests.
- `Run_Synthetic_Survival.bat`: asset-free survival fixture.
- `Run_Demo.bat`, `Run_Imported_Demo.bat`: earlier movement/import fixtures.

Use **Run_Diablo_Survivors.bat** for the current player flow. The source picker handles Diablo II preparation directly; the older administrator Inspector UI is not the Diablo II launch path.

## Development and packaging

```powershell
python scripts/check.py
python scripts/package_release.py
```

The checks cover schema validation, synthetic format decoding, source selection preferences, gameplay, class unlocks, difficulty timers, save/reload, shop purchases, reset behavior, audio and rendering integration. Real-installation checks additionally launch imported character sheets and confirm base/LoD class availability.

The source archive is `dist/diablo-survivors-source.zip`. Private `.local/` imports and caches, `.tools/` dependencies, and generated `level_props/` selection sheets are excluded. Import the selected game again on a new machine.

Code is organized under `manager/`, `inspector/`, `adapters/base/`, `adapters/diablo1/`, `adapters/diablo2/`, `runtime/`, `profiles/`, `catalogs/`, `schemas/`, `scripts/` and `tests/`. See `docs/architecture.md` and `docs/gameplay-design.md` for design details.

See `THIRD_PARTY_NOTICES.md` for decoder/library credits, including the MIT-licensed Diablerie format references. No original game assets are redistributed.

## Current bestiary coverage

| Pack | Enemy profiles | Survival areas |
| --- | ---: | ---: |
| Diablo I | 95 | 22 |
| Diablo II | 236 | 101 |
| Diablo II + Lord of Destruction | 309 | 124 |

Enemy profile counts include variants, bosses and named uniques, rather than distinct sprite families.

D2 now uses its own original area names and Acts. D1 retains 95 enemy profiles across 22 survival areas. Base D2 has 236 profiles and 101 combat areas across Acts I–IV; LoD has 309 profiles and 124 combat areas across Acts I–V. These include 31/46 mapped named uniques respectively, with area-specific challenges and original graphics/audio. Act V 1.07 roster corrections are explicitly authored native-family assignments; original special AI and full map geometry are not reproduced. See [docs/bestiary.md](docs/bestiary.md) for the complete roster and limits. Reset Progress selects the first area of the chosen source game (Cathedral for D1, Blood Moor for D2).


## Source code and contributions

A clean, independently buildable source snapshot is available in [Source_Code](Source_Code/readme.md), including Windows client build instructions. Bug fixes and improvements are welcome through pull requests; see [CONTRIBUTING.md](CONTRIBUTING.md). Project-owned code is licensed under [MIT](LICENSE). Dependencies retain their own terms, including PyQt6's GPL/commercial licensing; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
