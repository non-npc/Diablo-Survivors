import argparse,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from adapters.diablo2.importer import prepare
from manager.services.game_sources import settings
from manager.services.runtime import find_godot

def main():
    parser=argparse.ArgumentParser(description="Classic Diablo II survival playtest")
    parser.add_argument("--game-dir",default="");parser.add_argument("--base-only",action="store_true");parser.add_argument("--prepare-only",action="store_true");parser.add_argument("--smoke-test",action="store_true");args=parser.parse_args()
    folder=args.game_dir or settings().get("games",{}).get("diablo2",{}).get("folder","")
    if not folder:parser.error("Select a Diablo II folder with Choose_Game.bat, or provide --game-dir.")
    manifest=prepare(folder,workspace=ROOT/".local/diablo2-base-test" if args.base_only else None,progress=print,include_expansion=not args.base_only)
    if args.prepare_only:print(manifest);return 0
    command=[find_godot()]+(["--headless"] if args.smoke_test else [])+["--path",str(ROOT/"runtime"),"res://scenes/survival.tscn","--","--survival-manifest",str(manifest)]
    if args.smoke_test:command.append("--smoke-test")
    return subprocess.call(command)
if __name__=="__main__":raise SystemExit(main())
