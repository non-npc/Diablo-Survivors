"""Cache original regional soundtracks from the selected installation."""
import json
import io
import wave
from pathlib import Path
from adapters.base.mpq import ClassicMPQ,StormArchive
from inspector.services.workspace import atomic_json

def prepare_music(manifest_path,folder,game_id):
    path=Path(manifest_path).resolve();document=json.loads(path.read_text(encoding="utf-8"))
    folder=Path(folder);output=path.parent/"music";output.mkdir(exist_ok=True)
    files={p.name.lower():p for p in folder.iterdir() if p.is_file()}
    if game_id=="diablo1":
        archives=[files["diabdat.mpq"]]
        tracks={"menu":"music/dintro.wav","town":"music/dtowne.wav","cathedral":"music/dlvla.wav","catacombs":"music/dlvlb.wav","caves":"music/dlvlc.wav","hell":"music/dlvld.wav"}
    else:
        archives=[files[name] for name in ["patch_d2.mpq","d2xmusic.mpq","d2exp.mpq","d2music.mpq"] if name in files]
        tracks={"town":"data/global/music/act1/tristram.wav","cathedral":"data/global/music/act1/crypt.wav","catacombs":"data/global/music/act1/monastery.wav","caves":"data/global/music/act1/caves.wav","hell":"data/global/music/act4/diablo.wav"}
        tracks.update({"act1":"data/global/music/act1/wild.wav","act2":"data/global/music/act2/desert.wav","act2-sewer":"data/global/music/act2/sewer.wav","act2-harem":"data/global/music/act2/harem.wav","act2-tomb":"data/global/music/act2/tombs.wav","act3":"data/global/music/act3/jungle.wav","act3-kurast":"data/global/music/act3/kurast.wav","act4":"data/global/music/act4/mesa.wav","act5":"data/global/music/expansion/siege.wav"})
        tracks["menu"]="data/global/music/introedit.wav" if any(ClassicMPQ(p).lookup("data/global/music/introedit.wav") for p in archives) else "data/global/music/common/options.wav"
    fingerprint={str(p):[p.stat().st_size,p.stat().st_mtime_ns] for p in archives}
    area_keys=list(document["arenas"])
    if document.get("music_version")==4 and document.get("music_areas")==area_keys and document.get("music_fingerprint")==fingerprint and all(Path(track["path"]).is_absolute() and Path(track["path"]).is_file() for track in document.get("music",{}).values()):return path
    cached={}
    for archive_path in archives:
        table=ClassicMPQ(archive_path);archive=StormArchive(archive_path)
        try:
            for region,name in tracks.items():
                if region in cached or not table.lookup(name):continue
                destination=output/(region+".wav")
                payload=archive.read(name)
                # Repack PCM into a canonical WAV header for Godot's runtime loader.
                with wave.open(io.BytesIO(payload),'rb') as source:
                    params=source.getparams();samples=source.readframes(source.getnframes())
                with wave.open(str(destination),'wb') as target:
                    target.setparams(params);target.writeframes(samples)
                cached[region]={"path":str(destination),"source_path":name,"archive":archive_path.name}
        finally:archive.close()
    document["music"]={}
    for key in document["arenas"]:
        region="town" if key=="tristram" else "hell" if key.startswith(("hell","lazarus")) else "caves" if key.startswith(("caves","poisoned")) else "catacombs" if key.startswith(("catacombs","bone")) else "cathedral"
        area=document["arenas"][key]
        if game_id=="diablo2" and area.get("act"):
            act=area["act"];title=area["title"].lower();region="act"+str(act)
            if act==1:
                region="caves" if any(word in title for word in ["cave","den","pit","hole","passage"]) else "cathedral" if any(word in title for word in ["crypt","mausoleum"]) else "catacombs" if any(word in title for word in ["jail","cathedral","catacomb","barracks","cloister"]) else "town" if "tristram" in title else "act1"
            elif act==2:region="act2-sewer" if "sewer" in title else "act2-harem" if any(word in title for word in ["harem","cellar"]) else "act2-tomb" if any(word in title for word in ["tomb","temple","dead","duriel"]) else "act2"
            elif act==3 and int(area.get("original_level_id",0))>=79:region="act3-kurast"
            elif act==4 and int(area.get("original_level_id",0))==108:region="hell"
        if region in cached:document["music"][key]=cached[region]
        elif game_id=="diablo2":
            # Some installations omit expansion music media. Keep those areas musical.
            fallback=next((name for name in ["act"+str(area.get("act",1)),"hell" if area.get("act")==5 else "town","act4","act1","cathedral"] if name in cached),None)
            if fallback:document["music"][key]={**cached[fallback],"fallback_for":region}
    if "town" in cached:document["music"]["cow"]=cached["town"]
    if "menu" in cached:document["music"]["menu"]=cached["menu"]
    document["music_version"]=4;document["music_fingerprint"]=fingerprint;document["music_areas"]=area_keys;atomic_json(path,document)
    return path
