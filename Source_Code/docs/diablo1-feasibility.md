# Diablo I: local edition and asset feasibility

Inspection date: 2026-10-12. Status: archive metadata inspected; importer and asset decoding not implemented or validated.

## Baseline edition

Select your own Diablo I installation folder in the launcher.
Distribution: GOG, English, identified from `goggame-1412601690.info`.
GOG game ID: `1412601690`; build ID: `58186228511251224`.
These identify the inspected installation, not every GOG release.

Both root and DX Diablo executables report product version `1, 0, 9, 2` (1.0.9.2), and file version `2001, 5, 18, 1`. Executable metadata alone does not establish archive equivalence or full importer compatibility. The root and DX executables have different hashes.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| DIABDAT.MPQ | 517501282 | 63FB47D9C76484024C7640D90AB6B7EC5E13F567A7E1A917B6C03A6631D3F2B0 |
| Diablo.exe | 765024 | 66CCAFDD6D33925E00645AFD56E2999FCE3932E198E6DFDE66F055ECE04F227E |
| dx/Diablo.exe | 758272 | D0C18AEF911DF378EB17F5EF6C37BA1E9A331571D878AA5B0BAC492DB4D258C7 |
| Patch_rt.mpq | 593853 | 9FD730CF71EE1402BA74001A343193D25B4C79E29A29051ACADA3BC756A9B169 |
| DRTL_IX86_108_109.mpq | 401981 | 96B00887AC90CC8AF5FFBADB4DF23E2F09DF1A20F414CEF6186B8F4C60C0524B |

`dx/DIABDAT.MPQ` and `hellfire/DIABDAT.MPQ` are symbolic links to `../DIABDAT.MPQ`. Their reported zero-byte link lengths do not mean the game data is empty. Resolve links for detection and deduplicate the shared archive.

## Observed archive structure

Read-only inspection of the main archive header and hash/block tables found:

- Classic MPQ format version 0; 32-byte header; 4096-byte sectors.
- 4096 hash slots; 2911 block entries, with 2910 marked as existing.
- Header archive size 517501258 bytes, 24 bytes smaller than physical file size. Trailing bytes have not been interpreted.
- No `(listfile)` entry found. MPQ hash tables do not recover original filenames; enumeration needs a researched candidate filename catalog, with each candidate checked against the archive.
- Block flags: 1752 entries `0x80010100`, 1148 entries `0x80010000`, 10 entries `0x80000000`, one empty block. Payload handling must account for the flagged storage modes; table inspection does not verify successful payload decoding.

The following paths were confirmed through hash lookup. Sizes are the block table's declared uncompressed sizes, not proof of successful decoding.

| Archive path | Declared bytes | Intended inspection role |
| --- | ---: | --- |
| levels\townData\town.pal | 768 | Town palette |
| levels\l1data\l1.pal | 768 | Cathedral palette |
| levels\l1data\l1.cel | 738836 | Cathedral graphics |
| levels\l1data\l1.til | 1648 | Tile definitions |
| levels\l1data\l1.min | 9060 | Tile composition |
| levels\l1data\l1.sol | 453 | Terrain properties |
| monsters\skelaxe\sklaxw.cl2 | 62686 | Skeleton animation candidate |
| missiles\fireba1.cl2 | 5796 | Fireball effect candidate |
| music\dtowne.wav | 25457728 | Town music candidate |

Two guessed paths were absent: `plrgfx\warrior\wl\wls\wlsas.cl2` and `sfx\misc\item.wav`. This rejects those exact candidate paths, not player graphics or item sounds generally. No actor mappings, frame counts, pivots, or animation directions have yet been validated.

## Optional Hellfire installation

Present archives: `hellfire/hellfire.mpq` (65502336 bytes), `hfmonk.mpq` (37658368), `hfmusic.mpq` (34379360), and `hfvoice.mpq` (37743520). Hellfire executable file version is `1, 0, 1, 0`; product version is `98, 1, 13, 1`. Archive metadata has subsequently been inspected by the administrator app, but Hellfire payloads/campaign compatibility remain unverified. Keep Hellfire a separate optional capability.

## Extraction and normalization plan

Evaluate StormLib as the MPQ reader, pin a tested revision, review dependencies, and retain its MIT notice if used. No parser dependency was installed during this inspection.

Research CEL and CL2 decoding, palette selection, direction/state organization, sprite widths, frame origins, terrain composition and collision. DevilutionX's CEL loader explicitly accepts external width information: do not assume sprite dimensions can always be inferred from frame bytes. Use source as technical reference only; review licensing before reusing any code.

First validate bounded reads and representative sprite/palette/audio samples in memory; then implement local cache normalization with provenance and staging rollback. Do not copy proprietary samples into the repository. Do not execute the original executables or change the installation. Establish patch archive purpose and precedence before overlaying assets.

## Edition compatibility policy

- Current GOG English baseline: metadata and representative filename presence inspected only; full import/playability unverified.
- Earlier retail/CD and other non-GOG editions: planned, unverified; no support claim.
- Other languages, shareware, modified archives and other GOG builds: unverified.
- Hellfire: inventoried optional extension, unverified.

Track distribution, language, executable version, archive sizes/hashes, adapter version and actual decode coverage separately. Compare new editions against this baseline and maintain edition-specific catalogs/overrides when required. Unknown hashes should trigger inspection and diagnostics, not automatic claims of compatibility or a requirement that all valid editions match this one file.

## References

- StormLib repository and license: https://github.com/ladislav-zezula/StormLib and https://github.com/ladislav-zezula/StormLib/blob/master/LICENSE
- DevilutionX CEL loader: https://github.com/diasurgical/devilutionX/blob/master/Source/engine/load_cel.cpp
- DevilutionX archive requirements: https://devilutionx.com/mpq

Local evidence takes precedence over candidate format assumptions. These references do not establish support for the inspected installation.

## Administrator inspector validation (2026-10-12)

The implemented inspector reads classic MPQ tables and uses official StormLib 9.40 for payloads. Local validation inspected eight distinct archive paths (including separate root/DX patch files), imported 39 named resources with zero extraction errors, generated PAL swatches and validated WAV headers. Nine named main-archive resources were extracted; complete CEL/CL2 rendering, terrain assembly, patch precedence and playable campaign support remain pending. Imports remain in ignored `.local/inspector/`; no payload is included in source packages. Repeating the identical import reused its existing batch without decoding.

**Executable version evidence:** Windows display strings and numeric `VS_FIXEDFILEINFO` can differ. The root Diablo executable's fixed product version is 1.0.9.2; the DX executable's fixed product version is 1.0.10.2, despite both display strings reporting `1, 0, 9, 2`. Hellfire fixed file/product fields are 1.0.0.0 / 97.5.23.1, whereas the earlier display strings are `1, 0, 1, 0` / `98, 1, 13, 1`. The inspector records both forms. These differences must not silently relabel archive compatibility: distribution/build and exact archive fingerprints are the baseline identity.

## MPQ browser research and measured full catalog

MPQ Editor's documented Diablo/Hellfire candidate lists were downloaded for local administrator research and matched against the actual archives. All 2910 main archive blocks and all 3967 total entries have names. Measured metadata-only catalogs now ship for the main archive and full GOG installation; original listfile downloads stay in ignored local research/tool folders.

Real payload identification/import now covers 3900 working resources. Content inspection yields 1485 WAV audio resources, 130 PCX/GIF images, CEL/CL2 sprite metadata/previews, RGB palettes/TRN translations and terrain structures. There are 1921 sprite previews and two unresolved sprite-layout diagnostics. This replaces the initial nine-path discovery limit, but does not establish complete gameplay animation/terrain/mapping support.

Technical references: MPQ Editor filename-list behavior (https://github.com/OpenDiablo2/MpqViewer/blob/master/main.go), MPQ filename discovery documentation (https://zezula.net/cz/mpq/namebreak.html), and Unlicense graphics conversion formats (https://github.com/diasurgical/clx-conversion-tools). Reference code from d1-graphics-tool was inspected but not copied or shipped.
