"""Prepare local Warrior sheets for an authored survival campaign."""
import hashlib
import json
import math
import sqlite3
from pathlib import Path
from PIL import Image
from inspector.services.recognition import sprite_groups,frame_layout,palette_image

PLAYER_FILES={"idle":"plrgfx/warrior/wls/wlsas.cl2","walk":"plrgfx/warrior/wls/wlsaw.cl2","attack":"plrgfx/warrior/wls/wlsat.cl2","hit":"plrgfx/warrior/wls/wlsht.cl2","death":"plrgfx/warrior/wln/wlndt.cl2"}

def build_player(database,folder,class_id="warrior"):
    files=PLAYER_FILES
    if class_id!="warrior":
        prefix="plrgfx/rogue/rlb/rlb" if class_id=="rogue" else "plrgfx/sorceror/sln/sln"
        death="plrgfx/rogue/rln/rlndt.cl2" if class_id=="rogue" else prefix+"dt.cl2"
        # Magic fm/lm/qm sheets bake elemental auras into the character itself.
        # Use the neutral attack gesture; firebolt rendering is handled separately.
        files={state:prefix+suffix+".cl2" for state,suffix in {"idle":"as","walk":"aw","attack":"at","hit":"ht"}.items()}
        files["death"]=death
    with sqlite3.connect(database) as connection:
        entries={name.replace("\\","/"): {"raw":raw,"sha256":sha} for name,raw,sha in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    names=list(files.values())+["levels/l1data/l1_1.pal"]
    missing=[n for n in names if n not in entries]
    if missing:raise RuntimeError("Missing cached Warrior assets: "+str(missing))
    key=hashlib.sha256(json.dumps({"decoder":"survival-warrior-2","inputs":{n:entries[n]["sha256"] for n in names}},sort_keys=True).encode()).hexdigest()[:16]
    target=Path(folder)/key
    meta=target/"player.json"
    if meta.is_file():return json.loads(meta.read_text())
    target.mkdir(parents=True,exist_ok=True)
    palette=Path(entries[names[-1]]["raw"]).read_bytes()
    result={"clips":{},"provenance":files}
    for state,name in files.items():
        data=Path(entries[name]["raw"]).read_bytes();groups=sprite_groups(data)
        if len(groups) not in (1,8):raise ValueError("Unsupported Warrior direction count")
        decoded=[];heights=[];widths=[]
        for group in groups:
            row=[]
            for begin,end in group:
                w,h,indices,alpha=frame_layout(data[begin:end],"CL2")
                widths.append(w);heights.append(h);row.append(palette_image(indices,alpha,w,h,palette))
            decoded.append(row)
        width=max(widths);height=max(heights);columns=max(len(row) for row in decoded)
        sheet=Image.new("RGBA",(width*columns,height*len(groups)))
        for direction,row in enumerate(decoded):
            for i,image in enumerate(row):sheet.alpha_composite(image,(i*width+(width-image.width)//2,direction*height+height-image.height))
        path=target/("warrior-"+state+".png");sheet.save(path)
        result["clips"][state]={"sheet":str(path.resolve()),"frame_width":width,"frame_height":height,"frames_per_direction":[len(row) for row in decoded],"frame_seconds":0.075 if state=="walk" else 0.035 if state=="attack" else 0.09,"loop":state in ("idle","walk")}
    meta.write_text(json.dumps(result,indent=2)+"\n")
    return result
