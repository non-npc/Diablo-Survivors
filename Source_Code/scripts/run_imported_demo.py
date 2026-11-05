"""Direct launcher for the latest private imported-resource demo."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if getattr(sys,"frozen",False):ROOT=Path(sys.executable).resolve().parent
sys.path.insert(0,str(ROOT))
from manager.services.runtime import find_godot

def prepare_demo():
    state=ROOT/".local/inspector/last_preparation.json"
    if not state.is_file(): raise RuntimeError("Select your game folder in Run_Inspector.bat first.")
    validation=json.loads(state.read_text(encoding="utf-8")).get("validation",{})
    source=validation.get("runtime_preview_manifest")
    if not source or not Path(source).is_file(): raise RuntimeError("Refresh the asset database in Inspector to generate validated demo resources.")
    manifest=json.loads(Path(source).read_text(encoding="utf-8"))
    manifest["actor"]["clips"]={}
    for clip in validation.get("animations",[]):
        path=Path(validation["output_dir"])/clip["sheet"]
        if not path.is_file(): raise RuntimeError("A demo animation sheet is missing; refresh the Inspector.")
        manifest["actor"]["clips"][clip["state"]]={"sheet":str(path),"frame_width":clip["frame_size"][0],"frame_height":clip["frame_size"][1],"frames_per_direction":clip["frames_per_direction"],"preview_frame_seconds":0.12}
    # Select a complete flat tile using its alpha footprint; no source game map.
    from PIL import Image
    with Image.open(manifest["terrain"]["atlas"]) as atlas:
        complete=[]
        for index in validation.get("terrain",{}).get("floor_candidates",[]):
            left=index%8*128;top=index//8*192+128
            region=atlas.crop((left,top,left+128,top+64))
            if sum(value>0 for value in region.getchannel("A").getdata())==4096: complete.append(index)
        if complete: manifest["terrain"]["tile_index"]=complete[0]
    destination=ROOT/".local/demo/imported-demo.json"
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    return destination

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--smoke-test",action="store_true")
    parser.add_argument("--prepare-only",action="store_true")
    args=parser.parse_args()
    try:
        manifest=prepare_demo()
        if args.prepare_only:
            print(manifest)
            return 0
        command=[find_godot()]
        if args.smoke_test:command.append("--headless")
        command += ["--path",str(ROOT/"runtime"),"res://scenes/import_preview.tscn","--","--preview-manifest",str(manifest)]
        if args.smoke_test:command.append("--smoke-test")
        return subprocess.call(command)
    except (OSError,ValueError,RuntimeError) as error:
        print("GameShift demo:",error,file=sys.stderr)
        return 1

if __name__=="__main__":raise SystemExit(main())
