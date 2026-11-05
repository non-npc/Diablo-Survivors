import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from manager.services.runtime import find_godot, demo_arguments, GODOT_VERSION

def run(command, env):
    print("Checking:", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=90, encoding="utf-8", errors="replace")
    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)
    if "SCRIPT ERROR" in result.stdout + result.stderr or "Parse Error" in result.stdout + result.stderr:
        raise SystemExit("Godot reported script errors")
    return result.stdout

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="")
    args = parser.parse_args()
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", PYTHONIOENCODING="utf-8")
    binary = find_godot(args.godot)
    version = run([binary, "--version"], env).strip()
    if not version.startswith(GODOT_VERSION + ".stable"):
        raise SystemExit(f"Expected Godot {GODOT_VERSION}, got {version}")
    with tempfile.TemporaryDirectory(prefix="gameshift-check-") as folder:
        env["GAMESHIFT_DATA_DIR"] = folder
        # Keep Godot editor settings and user logs inside this isolated check run.
        for variable, child in [("APPDATA", "appdata"), ("LOCALAPPDATA", "localappdata")]:
            location = Path(folder) / child
            location.mkdir()
            env[variable] = str(location)
        run([sys.executable, "scripts/validate_assets.py"], env)
        run([sys.executable, "-m", "pytest", "-q"], env)
        run([sys.executable, "-m", "inspector.app", "--smoke-test", "--workspace", str(Path(folder) / "inspector")], env)
        run([binary, "--headless", "--path", str(ROOT / "runtime"), "--editor", "--import"], env)
        output = run([binary] + demo_arguments(True), env)
        if "GAMESHIFT_SMOKE_OK" not in output:
            raise SystemExit("Runtime smoke marker missing")
        # Verify generic imported-image playback with entirely original fixtures.
        import json
        from PIL import Image
        fixture = Path(folder)
        Image.new("RGBA", (32, 192), (70, 190, 140, 255)).save(fixture / "actor.png")
        Image.new("RGBA", (128, 192), (70, 80, 90, 255)).save(fixture / "terrain.png")
        manifest = {"schema_version":1,"actor":{"sheet":str(fixture/"actor.png"),"frame_width":16,"frame_height":24,"frames_per_direction":[2]*8,"preview_frame_seconds":0.12},"terrain":{"atlas":str(fixture/"terrain.png"),"cell_width":128,"cell_height":192,"columns":1,"tile_index":0}}
        path = fixture / "preview.json"
        path.write_text(json.dumps(manifest))
        preview_command = [binary,"--headless","--path",str(ROOT/"runtime"),"res://scenes/import_preview.tscn","--","--preview-manifest",str(path),"--smoke-test"]
        output = run(preview_command, env)
        if "GAMESHIFT_IMPORT_PREVIEW_OK" not in output: raise SystemExit("Imported preview marker missing")
        manifest["actor"]["frames_per_direction"] = [3]*8
        path.write_text(json.dumps(manifest))
        invalid = subprocess.run(preview_command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=30)
        if invalid.returncode == 0 or "Sprite frames exceed texture bounds" not in invalid.stderr+invalid.stdout:
            raise SystemExit("Invalid sprite bounds were not rejected")
        print("Invalid imported sprite bounds correctly rejected.")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/survival_rules.gd"],env)
        if "GAMESHIFT_SURVIVAL_RULES_OK" not in output:raise SystemExit("Survival rules marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/town_rules.gd"],env)
        if "GAMESHIFT_TOWN_RULES_OK" not in output:raise SystemExit("Town rules marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/progression_scene.gd","--","--test-progress",str(fixture/"progress.json")],env)
        if "GAMESHIFT_PROGRESSION_SCENE_OK" not in output:raise SystemExit("Progression scene marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/rare_events.gd","--","--test-progress",str(fixture/"events.json")],env)
        if "GAMESHIFT_RARE_EVENTS_OK" not in output:raise SystemExit("Rare event marker missing")
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/tier_upgrades.gd"],env)
        if "GAMESHIFT_TIERS_PROGRESSION_OK" not in output:raise SystemExit("Tier/progression marker missing")
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/menu_rules.gd","--","--test-progress",str(fixture/"menu.json")],env)
        if "GAMESHIFT_MAIN_MENU_OK" not in output:raise SystemExit("Main menu marker missing")
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/save_preferences.gd","--","--test-progress",str(fixture/"preferences.json")],env)
        if "GAMESHIFT_SAVE_PREFERENCES_OK" not in output:raise SystemExit("Save preferences marker missing")
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/difficulty_rules.gd","--","--test-progress",str(fixture/"difficulties.json")],env)
        if "GAMESHIFT_DIFFICULTY_RULES_OK" not in output:raise SystemExit("Difficulty rules marker missing")
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/diablo2_classes.gd"],env)
        if "GAMESHIFT_DIABLO2_CLASSES_OK" not in output:raise SystemExit("Diablo II class rules marker missing")
        import wave
        audio_fixture=fixture/"original-tone.wav"
        with wave.open(str(audio_fixture),"wb") as tone:
            tone.setnchannels(1);tone.setsampwidth(2);tone.setframerate(22050);tone.writeframes(bytes(44100))
        output=run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/audio_rules.gd","--","--test-wave",str(audio_fixture)],env)
        if "GAMESHIFT_AUDIO_RULES_OK" not in output:raise SystemExit("Combat audio marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/monster_rules.gd"],env)
        if "GAMESHIFT_MONSTER_RULES_OK" not in output:raise SystemExit("Enemy behavior marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/powerup_rules.gd"],env)
        if "GAMESHIFT_POWERUPS_OK" not in output:raise SystemExit("Powerup rules marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/wrap_rules.gd"],env)
        if "GAMESHIFT_WRAP_OK" not in output:raise SystemExit("Map wrapping marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/ally_rules.gd"],env)
        if "GAMESHIFT_ALLIES_OK" not in output:raise SystemExit("Ally behavior marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/settings_rules.gd"],env)
        if "GAMESHIFT_SETTINGS_OK" not in output:raise SystemExit("Settings marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/orb_harvest.gd"],env)
        if "GAMESHIFT_ORB_HARVEST_OK" not in output:raise SystemExit("Orb harvest marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/projectile_upgrades.gd"],env)
        if "GAMESHIFT_PROJECTILE_UPGRADES_OK" not in output:raise SystemExit("Projectile upgrades marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/completion_rules.gd","--","--test-progress",str(Path(folder)/"completion/progress.json")],env)
        if "GAMESHIFT_COMPLETION_OK" not in output:raise SystemExit("Completion marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/magic_particles.gd"],env)
        assert "MAGIC_PARTICLES_OK" in output
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/caster_spell_rules.gd"],env)
        assert "CASTER_SPELLS_OK" in output
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/ranged_rules.gd"],env)
        if "GAMESHIFT_RANGED_RULES_OK" not in output:raise SystemExit("Ranged behavior marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/surge_rules.gd"],env)
        if "GAMESHIFT_SURGES_OK" not in output:raise SystemExit("Surge pacing marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/reroll_rules.gd"],env)
        if "GAMESHIFT_REROLLS_OK" not in output:raise SystemExit("Upgrade reroll marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/game_speed_rules.gd"],env)
        if "GAME_SPEED_OK" not in output:raise SystemExit("Gameplay speed marker missing")
        output = run([binary,"--headless","--path",str(ROOT/"runtime"),"--script","res://tests/class_shop_rules.gd"],env)
        if "GAMESHIFT_CLASS_SHOP_OK" not in output:raise SystemExit("Class shop marker missing")
        output = run([sys.executable,"scripts/run_survival_demo.py","--synthetic","--smoke-test"],env)
        if "GAMESHIFT_SURVIVAL_OK" not in output:raise SystemExit("Survival smoke marker missing")
        output = run([sys.executable, "-m", "manager.app", "--launch-smoke", "--godot", binary], env)
        if "GAMESHIFT_MANAGER_OK" not in output:
            raise SystemExit("Manager smoke marker missing")
    print("All project checks passed.")

if __name__ == "__main__":
    main()
