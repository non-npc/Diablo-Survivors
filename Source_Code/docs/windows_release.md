# Windows 10 x64 release build

Run `Build_Windows_Release.bat` from the project folder. It creates an isolated build environment in `.tools/release-python`, installs `requirements-build.txt`, and assembles `build_release`. Every successful build also creates a versioned Windows x64 ZIP inside `build_release`. The ZIP contains the complete app in a `Diablo Survivors` folder, excluding caches, saves and other distribution ZIPs at the root. Required nested archives, including Python's `_internal/base_library.zip`, are preserved and verified. The older `--zip` option is still accepted but is no longer necessary.

Prerequisites on the build computer:

- Windows and 64-bit Python 3.12 or later.
- Godot **4.6.2** editor (`--godot PATH` or `GODOT_BIN`).
- Matching Godot **4.6.2 export templates**, installed through Godot's Manage Export Templates window. Alternatively supply `--template PATH` to `windows_release_x86_64.exe`.
- StormLib **9.40 x64** in `.tools/stormlib-9.40/x64/StormLib.dll`, or supply `--stormlib PATH`.

Example:

```bat
Build_Windows_Release.bat --godot "PATH_TO_GODOT" --zip
```

The build stages and imports a clean Godot project, exports an executable and PCK, freezes the Python importer with PyInstaller, and copies compatibility metadata, extra audio and license notices. It never includes local game archives, imported caches or player saves. Build logs and intermediate files stay in `.local/windows-build`.

An existing release is moved to `.local/windows-build/previous-release`, or a timestamped sibling when that backup already exists. This preserves the previous output and any saves users placed inside it. Developer documentation is excluded from the playable release; required dependency license texts are included in `licenses`.

Players launch `Diablo Survivors.exe`, choose their game installation and import assets. Python, Qt and the game runtime are bundled. Caches, launcher preferences and saves live in `.local` inside the installed folder, which must be writable. Keep the whole extracted folder together.

Before publishing, test on Windows 10 x64 with no development tools: fresh D1/base D2/LoD imports, cached startup, change game, shop persistence, progress reset, audio, Legendary progression and rewards. Building successfully is not proof of Windows 10 compatibility. This build is unsigned. Check redistribution permissions for the supplied extra audio before publication.
