# Runtime checks

`python scripts/check.py` imports the Godot project and runs the main scene with `-- --smoke-test`. It checks manifest loading, movement and arena bounds, then exits with a smoke-test success marker. Invalid manifests fail with a nonzero exit code. Combat and wave checks belong to M1.
