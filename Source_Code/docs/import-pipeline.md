# Import and catalog pipeline

Administrator: select folder → inventory/deduplicate symlink targets → cache archive identity → inspect tables and known paths/listfiles → add candidate paths → read representative payloads → save draft profile/catalog → verify decoders/mappings before publishing metadata.

End-user target flow: match a published verified edition → load bundled catalog → import/normalize required assets → launch cached manifest. No end-user asset discovery for supported editions. The current manager only identifies the research baseline; a complete end-user importer is pending.

Inspector working imports currently stage named raw resources and provenance/hashes, generate 256-color PAL swatches and validate RIFF/WAVE headers. CEL/CL2 stay raw. Each batch has an index; activation is an atomic rename plus latest pointer. Cancellation rolls back staging and preserves the last batch. Failed entries have diagnostics. Repeat identical selections reuse the unchanged latest batch; per-asset incremental reuse across different selections is planned.

Limits: classic MPQ v0 only; archive tables capped at 64 MiB, individual extraction at 128 MiB, selected batch at 1 GiB. Resource paths reject traversal/absolute paths. Source/cache directories must be separate. Size/mtime only signal changes, not cryptographic integrity; explicit fresh integrity verification should rehash. Native parser crash isolation and broader malformed-format coverage remain future work.

## Automatic administrator preparation

Setting a valid folder triggers archive inspection → known-resource import → edition draft/profile/catalog → SQLite database in a background job. Per-installation directories avoid cross-game cache collisions. Database tables cover installation/version evidence, archives, named/unnamed assets, raw/preview locations, diagnostics, and mapping/dependency storage (no mappings/dependencies are invented). Atomic generation activation preserves the previous database on cancellation/failure. The database and metadata generation is reused when unchanged. Preparation readiness is distinct from playable campaign readiness.

## Identification and previews

Pipeline/identifier 0.3.2 classifies content and generates bounded cached previews during automatic import. Import only working asset categories (images, sprites, audio, terrain and palettes); executable/video/other metadata records stay indexed. Each identified entry records confidence and format-specific properties in SQLite and catalog metadata. Decoder upgrades verify/reuse cached raw payloads and link them into the new batch where supported; archive decompression is unnecessary for unchanged payloads. Normal repeat preparation reuses the active batch/database.

Public catalogs exclude original text excerpts and all raw pixel/audio/terrain payloads. Administrator discovery can read local MPQ browser listfiles; the distributed app ships measured filename/lookup/classification catalogs rather than those third-party lists or game material. Filename identity is distinct from decoding/preview and gameplay mapping verification.

## Representative validation and runtime handoff

Preparation 0.4.1 reuses the identification/raw cache and invokes the Diablo adapter's local validation step. Its own fingerprinted, atomically activated validation directory contains cathedral atlas, five skeleton sheets, a validation report and a generic runtime preview manifest. Generation metadata points to these private files; SQLite mapping/dependency tables record the source relationships. Missing required resources produce an unavailable validation report rather than invented support.

The generic Godot import-preview scene loads external normalized PNGs, validates actor/terrain bounds and displays an authored floor grid and animated actor. No original executable, story map or game script is used. Source distributions contain the generic scene and metadata only, never these imported PNGs.
