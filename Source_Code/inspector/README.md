# Game Inspector & Profile Studio

Run `Run_Inspector.bat` at project root or `python -m inspector.app`. Use the Archives & assets tab to inspect MPQ metadata and preview known resources; Edition profile to edit/save a draft; Local imports to extract selected named files. See the root README for the complete workflow.

Service code is under `services/`, UI under `ui/`, synthetic regression tests under `tests/`. Output defaults to ignored `.local/inspector/`. `--scan --import-known --folder PATH` performs the same inspection/import services without a GUI. The main Diablo archive lacks a listfile, so its catalog is currently incomplete. Do not label drafts fully verified just because extraction succeeds.

Selecting/pasting a valid game directory automatically starts background preparation after a short debounce. The app builds a per-installation SQLite database, saves the edition profile/catalog and imports known resources. Explicit refresh remains available. Use `--prepare --folder PATH` for the same complete workflow without a GUI. Cached inspection, imports and databases are reused when unchanged; unnamed blocks remain in the database.

## Smart resource recognition

The Archives & assets tab now has type filters and format/dimension/frame/duration columns. Preview selected images, palette swatches, CEL/CL2 frames or dungeon tile-ID grids from the local cache. Use the frame slider or Animate for the first sprite group. Width 0 uses validated clip-header geometry; supply an explicit width for manual research when a file lacks it. Play audio uses the locally imported file. Audio never starts automatically.

The database records type, format, confidence and identification JSON (dimensions, group/frame counts, audio codec/channels/rate/duration, terrain records and diagnostics). File extensions alone are weaker evidence than signatures or valid structures. Sprite palettes are provisional preview associations; actor timing, translations/equipment mappings and full terrain assembly are not yet complete.

Complete measured GOG Diablo/Hellfire filename catalogs ship under `catalogs/`. Initial research used the MPQ Editor Diablo/Hellfire listfiles locally; raw third-party lists remain outside the source package. Unsupported entries remain available as raw files with diagnostics.

## Palette, direction and terrain validation

Palette and TRN selectors redraw from cached raw files, preserving encoded alpha. The direction selector previews a selected group; fully normalized representative skeleton sheets provide all frames in all eight directions. No archive read is needed for cached redraws.

The cathedral bundle now composes actual CEL primitives into MIN pieces and TIL tiles rather than a tile-ID visualization. Select its TIL resource to scrub the 206 tile previews. Local imports also offers the Godot resource preview. Outputs live under the installation's `validation/<fingerprint>/`, remain private, and are reused unchanged.
