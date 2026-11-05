# Contributing to Diablo Survivors

Bug fixes, gameplay improvements, compatibility fixes, documentation and tests are welcome.

1. Fork the repository and create a focused branch from its current default branch.
2. Follow the setup and build instructions in `Source_Code/readme.md` (or `readme.md` when using the standalone source copy).
3. Make a focused change. Keep game-specific decoding and rules in adapters/data, with shared gameplay in the runtime.
4. Run `python scripts/check.py --godot PATH_TO_GODOT` and include the result in your pull request. Add meaningful regression coverage for behavior fixes.
5. Open a pull request explaining the problem, the resulting behavior, how you tested it, and any compatibility limits. Include screenshots or short footage for visual changes.

For bug reports, include the client version, operating system, selected source game/edition, reproduction steps and relevant `.local/logs` excerpts. Remove personal paths or sensitive information before posting.

Never submit game archives, extracted artwork/audio, private caches, saves, local configuration, credentials, compiled builds or tool installations. Use synthetic fixtures in tests. Do not download proprietary archives in CI. Preserve existing third-party notices and add notices for new dependencies.

Project-owned contributions are submitted under the MIT license in LICENSE. Submit only work you have the right to contribute; dependencies and third-party assets retain their own terms. The default PyQt6 client has separate GPL/commercial dependency terms described in THIRD_PARTY_NOTICES.md.

When contributing from the complete development checkout, edit the source at the repository root and regenerate `Source_Code` with `python scripts/export_source.py`. Do not maintain the generated copy separately. The standalone source copy can also be built and modified independently.
