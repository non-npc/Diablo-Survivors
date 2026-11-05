# Build and contribute to Diablo Survivors

This is a clean source snapshot of the Diablo Survivors client. It contains Python launcher/importer code, Godot runtime code, synthetic demo assets, metadata, tests and build scripts. It excludes game installations, imported assets, saves, local settings, installed tools, compiled releases and optional third-party audio.

## Requirements

- Windows x64 for the portable Windows client build.
- Python 3.12 or newer, 64-bit (development has used Python 3.14).
- Godot 4.6.2 stable and the matching Windows x64 export template.
- Internet access for Python packages and the pinned Godot/StormLib setup downloads.
- Your own Diablo I or classic Diablo II installation to play with original graphics/audio. Synthetic checks do not require a game installation. Diablo II: Resurrected is unsupported.

Run the commands below in PowerShell from this folder, the one containing `requirements-dev.txt`. Use a writable directory.

## Set up and run from source

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe scripts/setup_godot.py
.\.venv\Scripts\python.exe scripts/setup_stormlib.py
```

The setup scripts download checksum-verified Godot 4.6.2 and StormLib 9.40 into `.tools`. To use an existing Godot installation, skip its setup command and set `GODOT_BIN` to its executable.

```powershell
$env:GODOT_BIN = (Resolve-Path '.tools/godot-4.6.2/Godot_v4.6.2-stable_win64_console.exe').Path
.\.venv\Scripts\python.exe scripts/run_diablo_survivors.py
```

Choose your installed game folder in the launcher. The first import takes longer. Settings, caches and progress are created under `.local`; game installations are read only. The optional external goblin/hit sounds are omitted from this source copy; the game runs without those files.

## Check your changes

```powershell
.\.venv\Scripts\python.exe scripts/check.py --godot $env:GODOT_BIN
```

This validates metadata, runs Python tests and exercises Godot gameplay and launcher smoke tests using synthetic fixtures. For a quick Python-only check, run `.\.venv\Scripts\python.exe -m pytest -q`.

## Build the portable Windows client

In Godot 4.6.2, install the matching export templates through **Editor > Manage Export Templates**. Locate `windows_release_x86_64.exe` in the installed templates. Then run:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-build.txt
.\.venv\Scripts\python.exe scripts/build_windows_release.py --godot $env:GODOT_BIN --template "$env:APPDATA/Godot/export_templates/4.6.2.stable/windows_release_x86_64.exe"
```

Alternatively run `Build_Windows_Release.bat --godot PATH_TO_GODOT --template PATH_TO_TEMPLATE`. The batch file creates its own build environment and installs build dependencies.

Output is in `build_release`: launch `Diablo Survivors.exe`. A versioned Windows x64 ZIP is also created there. Keep the entire extracted folder together. Python, Qt and the Godot runtime are bundled; players do not install development tools. The build checks the actual Qt launcher startup. Intermediate files are in `.local/windows-build`. Previous releases are backed up there. Test the built client against your own installed games before publishing it.

The separate `scripts/sfx_release.py` workflow is for the maintainer's multipart WinRAR distribution and expects an existing `github_final` release layout. It is not needed to build the portable client from this source copy.

## Submit improvements

Read [CONTRIBUTING.md](CONTRIBUTING.md). Fork the upstream repository, make a focused branch, run the checks, and submit a pull request with the problem, your fix and validation results. Keep imported assets and `.local`, `.tools`, `.venv`, and build outputs out of commits.

## Licenses

Project-owned source is MIT licensed; see [LICENSE](LICENSE). Preserve [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and dependency license texts. PyQt6's default GPL build has separate requirements for a combined client distribution; MIT does not replace those terms. Proprietary game resources and optional third-party audio are not licensed by this project.

The complete checkout includes a generated `Source_Code` directory. To refresh it after root source changes, run `python scripts/export_source.py`. The exporter refuses to overwrite an existing snapshot so local edits cannot be lost; move or rename the previous snapshot first.
