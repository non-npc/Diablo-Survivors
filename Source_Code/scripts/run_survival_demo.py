import argparse
import json
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if getattr(sys,"frozen",False):ROOT=Path(sys.executable).resolve().parent
sys.path.insert(0,str(ROOT))
from manager.services.runtime import find_godot
from manager.services.catalog import validate_document

UPGRADES=json.loads((ROOT/"runtime/resources/upgrades.json").read_text(encoding="utf-8"))

def challenges(arena):
    thresholds=[75,175,300] if arena=="tristram" else [100,250,400]
    return [{"id":f"skeleton-{target}","title":f"Defeat {target} skeletons","enemy":"skeleton","target":target} for target in thresholds]

def configuration():
    return {"powerups_enabled":True,"challenges":challenges("cathedral"),"rare_events":{"check_seconds":30,"spawn_chance":0.08,"portal_chance":0.01},"duration_seconds":480,"seed":20261012,"arena_width":2200,"arena_height":1800,"player":{"health":100,"speed":220,"damage":20,"cooldown":0.6,"attack_range":100,"attack_targets":3,"pickup_radius":90},"enemy":{"health":14,"speed":62,"contact_damage":7},"director":{"wave_seconds":30,"spawn_interval":1.2,"max_enemies":300},"upgrades":UPGRADES}

def prepare_survival(synthetic=False,arena="cathedral",progress=lambda message:None):
    if synthetic:return ROOT/"runtime/resources/survival_demo.json"
    state=ROOT/".local/inspector/last_preparation.json"
    if not state.is_file():raise RuntimeError("Choose your game folder in Inspector first, or use --synthetic.")
    prepared=json.loads(state.read_text());validation=prepared.get("validation",{})
    if not validation.get("runtime_preview_manifest"):raise RuntimeError("Refresh the Inspector's asset database first.")
    from adapters.diablo1.survival_demo import build_player
    from scripts.run_imported_demo import prepare_demo
    terrain=json.loads(prepare_demo().read_text())["terrain"]
    player=build_player(prepared["database_path"],ROOT/".local/demo/warrior")
    enemy={"clips":{}}
    for clip in validation["animations"]:
        enemy["clips"][clip["state"]]={"sheet":str(Path(validation["output_dir"])/clip["sheet"]),"frame_width":clip["frame_size"][0],"frame_height":clip["frame_size"][1],"frames_per_direction":clip["frames_per_direction"],"frame_seconds":0.09,"loop":clip["state"] in ("idle","walk")}
    manifest={"game_id":"diablo1","available_classes":["warrior","rogue","sorcerer"],"default_class":"warrior","schema_version":1,"title":"Cathedral Survival","profile_id":"diablo1-gog-survival-demo","player_visual":player,"enemy_visual":enemy,"terrain":terrain,"configuration":configuration(),"save_path":str(ROOT/".local/demo/progress/diablo1-v2.json")}
    from adapters.diablo1.audio import build_audio
    manifest["audio"]=build_audio(prepared["database_path"],ROOT/".local/demo/audio")
    from adapters.diablo1.cow import build_cow
    manifest["cow_visual"]=build_cow(prepared["database_path"],ROOT/".local/demo/cows")
    from adapters.diablo1.ui import build_ui
    from adapters.diablo1.effects import build_effects
    manifest["impact_effects"]=build_effects(prepared["database_path"],ROOT/".local/demo/effects")
    from adapters.diablo1.spells import build_spells
    manifest["spell_effects"]=build_spells(prepared["database_path"],ROOT/".local/demo/spells")
    manifest["ui"]=build_ui(prepared["database_path"],ROOT/".local/demo/ui")
    manifest["class_visuals"]={key:build_player(prepared["database_path"],ROOT/".local/demo/classes"/key,key) for key in ("warrior","rogue","sorcerer")}
    from adapters.diablo1.town import build_town
    town_map=build_town(prepared["database_path"],ROOT/".local/demo/maps/tristram")
    manifest["default_arena"]=arena
    from adapters.diablo1.zones import build_zones,zone_catalog
    from adapters.diablo1.monsters import build_monsters,zone_challenges
    maps=build_zones(prepared["database_path"],ROOT/".local/demo/maps/zones",progress=progress)
    monsters=build_monsters(prepared["database_path"],ROOT/".local/demo/monsters",zone_catalog(),progress=progress)
    manifest["enemy_visuals"]=monsters["visuals"]
    manifest["audio"]["sounds"].update(monsters["sounds"])
    manifest["arenas"]={}
    for zone in zone_catalog():
        key=zone["id"];data=town_map if key=="tristram" else maps[key]
        depth=zone.get("floor",1)
        manifest["arenas"][key]={"title":zone["title"],"map":data,"arena_width":data.get("arena_width",6144),"arena_height":data.get("arena_height",3584),"challenges":challenges(key),"enemy":{"health":14+depth*2,"speed":62+depth*1.5,"contact_damage":7+depth//3},"source_zone":zone,"enemy_roster":monsters["rosters"][key],"enemy_definitions":monsters["definitions"],"boss":monsters["bosses"].get(key,"")}
        manifest["arenas"][key]["challenges"]=zone_challenges(monsters["rosters"][key],monsters["definitions"],monsters["bosses"].get(key))
        if key in ("cathedral","tristram"):
            manifest["arenas"][key]["challenges"]+=challenges(key)
    if arena=="tristram":
        from adapters.diablo1.town import build_town
        manifest["map"]=town_map
        manifest.pop("terrain",None)
        manifest["title"]="Tristram Survival"
        manifest["configuration"].update(arena_width=6144,arena_height=3584)
    manifest["configuration"]["challenges"]=challenges(arena)
    validate_document(manifest,"survival_manifest.schema.json")
    path=ROOT/(".local/demo/tristram-survival.json" if arena=="tristram" else ".local/demo/survival.json");path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(manifest,indent=2)+"\n")
    return path

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--treasure-demo",action="store_true",help="Force one goblin and its portal for playtesting")
    parser.add_argument("--cow-event",action="store_true",help="Start the cow event directly for playtesting")
    from adapters.diablo1.zones import zone_catalog
    parser.add_argument("--arena",choices=[zone["id"] for zone in zone_catalog()],default="cathedral")
    parser.add_argument("--synthetic",action="store_true")
    parser.add_argument("--smoke-test",action="store_true")
    parser.add_argument("--prepare-only",action="store_true")
    args=parser.parse_args()
    try:
        manifest=prepare_survival(args.synthetic,args.arena)
        if args.prepare_only:print(manifest);return 0
        command=[find_godot()]
        if args.smoke_test:command.append("--headless")
        command += ["--path",str(ROOT/"runtime"),"res://scenes/survival.tscn","--","--survival-manifest",str(manifest)]
        if args.smoke_test:command.append("--smoke-test")
        if args.cow_event:command.append("--cow-event")
        if args.treasure_demo:command.append("--treasure-demo")
        if args.smoke_test:
            result=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=30)
            print(result.stdout,end="");print(result.stderr,end="",file=sys.stderr)
            if "SCRIPT ERROR" in result.stdout+result.stderr or "GAMESHIFT_SURVIVAL_OK" not in result.stdout:return 1
            return result.returncode
        return subprocess.call(command)
    except (OSError,RuntimeError,ValueError,subprocess.TimeoutExpired) as error:print("GameShift:",error,file=sys.stderr);return 1

if __name__=="__main__":raise SystemExit(main())
