"""User-selected source games; paths are preferences, never fixed installations."""
import json
from pathlib import Path
from manager.services.paths import ROOT
from inspector.services.workspace import atomic_json
from manager.services.music import prepare_music
SETTINGS=ROOT/".local/launcher/settings.json"
GAMES={"diablo1":"Diablo I","diablo2":"Diablo II (Classic)","diablo2_lod":"Diablo II + Lord of Destruction"}
def settings(path=SETTINGS):
    try:
        value=json.loads(Path(path).read_text())
        return value if isinstance(value,dict) else {}
    except (OSError,ValueError):return {}
def save_choice(game_id,folder,path=SETTINGS):
    if game_id not in GAMES:raise ValueError("Unknown source game")
    document=settings(path);document.setdefault("games",{})[game_id]={"folder":str(Path(folder).resolve())};document["active_game"]=game_id
    atomic_json(path,document)
def prepare_source(game_id,folder,progress=lambda message:None):
    folder=Path(folder).resolve()
    if game_id in ("diablo2","diablo2_lod"):
        if game_id=="diablo2_lod" and not any(p.name.lower()=="d2exp.mpq" for p in folder.iterdir()):raise ValueError("Select a Lord of Destruction installation containing d2exp.mpq.")
        from adapters.diablo2.importer import prepare
        return prepare_music(prepare(folder,progress=progress,include_expansion=game_id=="diablo2_lod"),folder,"diablo2")
    if game_id!="diablo1":raise ValueError("Unknown source game")
    if not folder.is_dir() or not any(p.name.lower()=="diabdat.mpq" for p in folder.iterdir()):raise ValueError("Select your Diablo I folder containing DIABDAT.MPQ.")
    cache_path=ROOT/".local/launcher/diablo1-preparation.json"
    archives={str(p.resolve()):[p.stat().st_size,p.stat().st_mtime_ns] for p in folder.rglob("*") if p.is_file() and p.suffix.lower()==".mpq"}
    source_files=[ROOT/"scripts/run_survival_demo.py",ROOT/"runtime/resources/upgrades.json",ROOT/"runtime/resources/zones.json"]+list((ROOT/"adapters/diablo1").glob("*.py"))
    import sys
    if getattr(sys,"frozen",False):source_files=[ROOT/"build_info.json"]
    fingerprint={"folder":str(folder),"archives":archives,"builders":{str(p):p.stat().st_mtime_ns for p in source_files}}
    try:
        cached=json.loads(cache_path.read_text())
        if cached.get("fingerprint")==fingerprint and Path(cached.get("manifest_path","")).is_file():return prepare_music(Path(cached["manifest_path"]),folder,game_id)
    except (OSError,ValueError):pass
    from inspector.services.preparation import prepare_installation
    prepared=prepare_installation(folder,ROOT/".local/inspector",progress=lambda value,message:progress(message))
    if prepared.get("profile",{}).get("game_id","diablo1")!="diablo1":raise ValueError("This installation does not match a Diablo I profile.")
    from scripts.run_survival_demo import prepare_survival
    manifest=prepare_survival(progress=progress)
    atomic_json(cache_path,{"fingerprint":fingerprint,"manifest_path":str(manifest)})
    return prepare_music(manifest,folder,game_id)
