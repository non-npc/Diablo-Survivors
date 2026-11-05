# Validation

`python scripts/check.py` validates schemas/catalogs, runs pytest with synthetic MPQs, checks inspector startup, imports Godot resources headlessly, runs deterministic movement smoke, and verifies the manager launches the headless runtime successfully. Test data lives in temporary directories. No proprietary archive is downloaded by tests or CI.

Synthetic tests cover MPQ table bounds/name lookup, unsafe resource paths, hash reuse, cancellation, staged import rollback, palette extraction/preview, same-selection cache reuse, draft profiles, database persistence/version rejection, identity mismatch and manifest constraints.

Private local verification additionally scans the user's GOG installation and extracts selected named resources to ignored `.local/`. This is evidence for those resources only. Windows has been tested locally; Linux/macOS CI is configured, not yet executed. M1 combat/performance, ten-minute manual runs and all importer capability gates remain pending.

Recognition regressions additionally cover misleading file extensions, PCX decoding, WAV codec/duration, CEL/CL2 run lengths and opaque index-zero alpha, contiguous/interleaved directional headers, truncated runs, malformed offset tables, terrain record/grid identification, cached Qt previews/type filters and exclusion of original text from exported catalogs.

Validation tests cover square/RLE/triangle/trapezoid pixels and padding, opaque color-index zero, malformed terrain references, MIN/TIL/SOL bounds, palette translation without alpha changes and scope of animation naming rules. Godot checks additionally load original synthetic external PNGs, validate eight-direction sheet/terrain bounds and reject invalid sprite rectangles. Private local headless validation also passed with the real normalized skeleton and cathedral atlas.
