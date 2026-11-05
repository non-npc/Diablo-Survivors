# Asset format feasibility matrix

| Adapter | Research / local evidence | Current implementation |
| --- | --- | --- |
| Diablo I GOG English | See diablo1-feasibility.md; classic MPQ v0, CEL/CL2, PAL, terrain and WAV candidates | Header/tables, path lookup and raw payload extraction; PAL swatches, WAV headers. Full sprite/terrain decoding pending. |
| Diablo I earlier retail/CD | No local edition inspected | Unverified; separate fingerprints/catalogs required. |
| Hellfire | Archive inventory and metadata; names mostly unknown | Classic MPQ inspection only; campaign support unverified. |
| Diablo II classic/LoD | No local edition inspected; spec names MPQ/DC6/DCC/COF/DS1/DT1 research targets | No adapter or format support claimed. |
| Warcraft I | No local edition inspected; actual edition resource formats require research | No adapter or format support claimed. |
| Warcraft II | No local edition inspected; actual edition archive/palette/sprite layouts require research | No adapter or format support claimed. |

This is an explicit preliminary report for uninspected games, not a promise of extraction support. Record exact editions, sample coverage, dependencies/licenses and unknowns before each importer milestone. Warcraft III remains outside v1.

## Verified GOG local recognition update

All 3967 entries across the eight inspected archive paths now have matching names. Types in the current database: 1485 audio, 130 standard images, 2008 sprites, 81 terrain resources, 195 palettes/translation tables, 30 text, 26 other metadata and 12 videos. Some unimported categories are extension-classified, not content-decoded.

Content inspection validates RIFF/WAVE headers and audio properties, uses Pillow for standard PCX/GIF/image signatures, parses RGB256 palettes/TRN tables, reads CEL/CL2 frame/group offset structures and supported clipped RLE geometry, and identifies TIL/MIN/SOL/DUN terrain structures. CEL groups may interleave tables and pixels; CL2 commonly collects directional tables first. Palette-index zero remains opaque when an opaque run encodes it. Pixel data is decoded bottom-up.

Local previews: 1921 sprites, 130 standard images, 49 palette swatches and 50 terrain previews/ID visualizations. Two sprite resources have unresolved layout diagnostics (`monsters/darkmage/dmagew.cl2`, `monsters/unrav/unravw.cel`). Additional sprites lack automatic width rules. Preview colors use candidate palettes; translation/actor mappings and full terrain composition/collision remain unverified.

## Cathedral terrain and representative actor validation

Validation 0.4.1 decodes all 1119 referenced cathedral CEL primitives in six encodings, validates 453 MIN pieces against 453 SOL entries, checks 206 TIL records, and composes a complete local tile atlas. TIL piece references are zero-based; MIN CEL references are one-based. Shapes are raw/RLE squares, left/right triangles and left/right trapezoids, decoded bottom-up with original padding. The atlas has been visually checked. Raw SOL bits are preserved; no original navigation behavior or patched property corrections are promised. Other terrain families remain unverified.

Gameplay cathedral palettes use the `l1_1`–`l1_4` variants; the representative preview explicitly selects `l1_1.pal`. A white skeleton uses the local `white.trn` lookup while retaining opaque/transparent run alpha. Five skeleton files fully decoded: idle 96, walk 64, attack 104, hit 48 and death 136 frames across eight directions each (448 total). Animation roles use the documented `n/w/a/h/d/s` monster convention. Timing remains unverified; preview speed is authored.

Primary format references: https://github.com/diasurgical/devilutionX/blob/master/Source/levels/dun_tile.hpp, https://github.com/diasurgical/devilutionX/blob/master/Source/levels/dun_tile_data.cpp, https://github.com/diasurgical/devilutionX/blob/master/Source/engine/palette.cpp, https://github.com/diasurgical/devilutionX/blob/master/Source/engine/direction.hpp and https://github.com/diasurgical/devilutionX/blob/master/Source/monster.cpp. These were used for format facts, not copied game behavior/source/assets.
