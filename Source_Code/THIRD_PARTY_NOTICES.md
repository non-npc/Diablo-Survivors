# Third-party dependencies

Project-owned source code, documentation and original demo resources are licensed under MIT (see LICENSE). Third-party components retain their own licenses and notices; the project's MIT license does not relicense them or any game assets.

The default Python client uses the GPL build of PyQt6. A combined client distribution using that build remains subject to its applicable GPL obligations; the MIT license for project-owned code does not make the bundled client MIT-only. PyQt6 also offers a commercial license. The GPL text is retained in docs/licenses/GPL-3.0.txt. Check the licenses of the dependency versions you distribute.

| Dependency | Version used | License / source |
| --- | --- | --- |
| Python | 3.14.0 locally; minimum 3.12 | PSF-2.0; https://www.python.org/ |
| PyQt6 | 6.10.0 | GPL-3.0-only or commercial; https://www.riverbankcomputing.com/software/pyqt/ |
| Qt (PyQt6 wheel) | installed wheel dependency | Qt's applicable component licenses; https://www.qt.io/licensing/ |
| Pillow | 12.0.0 | MIT-CMU; https://github.com/python-pillow/Pillow |
| jsonschema | 4.26.0 | MIT; https://github.com/python-jsonschema/jsonschema |
| pytest | 9.1.1, development only | MIT; https://github.com/pytest-dev/pytest |
| Godot | 4.6.2, external executable | MIT and bundled third-party notices; https://godotengine.org/license/ |
| StormLib | 9.40, external native library | MIT; https://github.com/ladislav-zezula/StormLib/tree/v9.40 |

StormLib's complete MIT notice is in `docs/licenses/StormLib-MIT.txt`. The official Windows DLL ZIP SHA-256 is `b2c9635e7b63edee1bd7c82e7dc180d739f3accb2b8994804c7774e464ce89ae`, matched to the official GitHub release asset digest during local setup. Setup verifies this hash. Native binaries remain in `.tools/` and are excluded from source packages.

Dependency transitive components are not bundled by the source packager; their own installers/licenses apply. Review all applicable notices when adding a binary distribution. DevilutionX was consulted as a format reference; its code/assets are not included. No Blizzard art, audio, game data or binaries are included in the source package. Metadata paths/hashes identify user-provided resources; extraction remains local.

Format research also consulted diasurgical/clx-conversion-tools (Unlicense) and MPQ Editor's documented listfile workflow. No converter code or proprietary palette files were copied into the project. Raw Diablo/Hellfire MPQ Editor listfile downloads remain in ignored local research/tool folders; shipped catalogs are generated from filename matches and structural metadata verified against the user's own archives. Original text/pixel/audio content is excluded from public metadata.


## Diablerie format decoder references

DCC/COF/DC6/DT1 decoding in adapters/diablo2/formats.py adapts the format algorithms from [Diablerie](https://github.com/mofr/Diablerie), Copyright (c) 2019 Alexander Egorov, MIT License. The complete license is preserved in adapters/diablo2/DIABLERIE_LICENSE.txt. The adapter contains format-decoding code, not original Diablo II executable code or game assets.

## Treasure goblin audio

The goblin OGG audio files in `extras/goblin/` were supplied from [Wowhead — Pet Treasure Goblin Clickable 1](https://www.wowhead.com/sound=40316/pet-treasure-goblin-clickable-1). These third-party audio files are separate from the project's MIT-licensed source code and are an exception to the game-audio exclusion stated above. This attribution does not assign them a redistribution license.
