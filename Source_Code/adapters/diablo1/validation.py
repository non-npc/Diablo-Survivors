"""Local representative validation and authored mapping rules for Diablo I."""
import hashlib
import json
import math
import shutil
import uuid
from pathlib import Path
from PIL import Image
from adapters.diablo1.terrain import TerrainSet
from inspector.services.recognition import sprite_groups,frame_layout,palette_image

VERSION="0.4.1"
DIRECTIONS=("south","southwest","west","northwest","north","northeast","east","southeast")
MONSTER_STATES={"n":"idle","w":"walk","a":"attack","h":"hit","d":"death","s":"special"}

def animation_mapping(name,info):
    name=name.lower().replace("\\","/")
    stem=Path(name).stem
    if not name.startswith("monsters/") or len(stem)<2 or stem[-1] not in MONSTER_STATES or info.get("group_count")!=8:
        return None
    return {"actor_family":str(Path(name).parent/stem[:-1]),"state":MONSTER_STATES[stem[-1]],"directions":list(DIRECTIONS),"frames_per_direction":info["frames_per_group"],"confidence":"reference naming convention and eight-group structure; gameplay timing unverified"}

def translated_palette(palette,translation=None):
    if len(palette)!=768: raise ValueError("Expected RGB256 palette")
    if translation is None:return palette
    if len(translation)!=256: raise ValueError("Expected 256-entry translation")
    return bytes(palette[translation[i]*3+channel] for i in range(256) for channel in range(3))

def validate_cached(imported,workspace,progress=lambda value,message:None,cancelled=lambda:False):
    from inspector.services.workspace import atomic_json,Cancelled
    entries={a["source_path"].lower().replace("\\","/"):a for a in imported.get("assets",[]) if a["archive"].lower()=="diabdat.mpq"}
    needed=["levels/l1data/l1."+ext for ext in ("cel","min","til","sol")]+["levels/l1data/l1_1.pal","monsters/skelaxe/white.trn"]+["monsters/skelaxe/sklax"+letter+".cl2" for letter in "nwahd"]
    missing=[name for name in needed if name not in entries]
    if missing:return {"status":"unavailable","missing":missing}
    root=Path(imported["output_dir"])
    key=hashlib.sha256(json.dumps({"version":VERSION,"sources":{name:entries[name]["sha256"] for name in needed}},sort_keys=True).encode()).hexdigest()[:20]
    target=Path(workspace)/"validation"/key
    if (target/"report.json").is_file():
        result=json.loads((target/"report.json").read_text(encoding="utf-8"));result["output_dir"]=str(target);return result
    stage=target.parent/(".staging-"+uuid.uuid4().hex)
    stage.mkdir(parents=True)
    try:
        def read(name):return (root/entries[name]["raw_path"]).read_bytes()
        palette=read("levels/l1data/l1_1.pal")
        terrain=TerrainSet(*(read("levels/l1data/l1."+ext) for ext in ("cel","min","til","sol")),palette)
        terrain.atlas().save(stage/"cathedral-atlas.png")
        result={"version":VERSION,"status":"representative validation complete","palette":"levels/l1data/l1_1.pal","translation":"monsters/skelaxe/white.trn","terrain":terrain.summary(),"terrain_preview":"cathedral-atlas.png","animations":[],"ready_for_gameplay":False}
        translated=translated_palette(palette,read("monsters/skelaxe/white.trn"))
        for index,letter in enumerate("nwahd"):
            if cancelled():raise Cancelled()
            name="monsters/skelaxe/sklax"+letter+".cl2"
            data=read(name);groups=sprite_groups(data)
            if len(groups)!=8:raise ValueError("Representative actor does not have eight directions")
            decoded=[];widths=set();heights=[]
            for group in groups:
                row=[]
                for begin,end in group:
                    if cancelled():raise Cancelled()
                    w,h,indices,alpha=frame_layout(data[begin:end],"CL2")
                    widths.add(w);heights.append(h);row.append(palette_image(indices,alpha,w,h,translated))
                decoded.append(row)
            if len(widths)!=1:raise ValueError("Representative animation frame widths differ")
            w=widths.pop();h=max(heights);columns=max(len(g) for g in groups)
            if w*h*columns*8>16*1024*1024:raise ValueError("Animation sheet exceeds limit")
            sheet=Image.new("RGBA",(columns*w,8*h))
            for direction,row in enumerate(decoded):
                for frame,image in enumerate(row):sheet.alpha_composite(image,(frame*w,direction*h+h-image.height))
            filename="skeleton-"+MONSTER_STATES[letter]+".png";sheet.save(stage/filename)
            result["animations"].append({"source_path":name,"state":MONSTER_STATES[letter],"directions":list(DIRECTIONS),"frames_per_direction":[len(g) for g in groups],"frame_size":[w,h],"sheet":filename,"all_frames_decoded":True,"frame_duration":"unverified; authored runtime timing required"})
            progress((index+1)*100//5,"Validated skeleton "+MONSTER_STATES[letter]+" in eight directions")
        floors=[i for i,tile in enumerate(terrain.tiles) if all(not any(terrain.pieces[ref][:-2]) and not terrain.properties[ref]&1 for ref in tile)]
        result["terrain"]["floor_candidates"]=floors
        if not floors: raise ValueError("No flat non-solid terrain tile identified for preview")
        walk=next(a for a in result["animations"] if a["state"]=="walk")
        preview={"schema_version":1,"title":"Imported resource validation", "terrain":{"atlas":str(target/"cathedral-atlas.png"),"cell_width":128,"cell_height":192,"columns":8,"tile_index":floors[0]},"actor":{"sheet":str(target/walk["sheet"]),"frame_width":walk["frame_size"][0],"frame_height":walk["frame_size"][1],"frames_per_direction":walk["frames_per_direction"],"directions":walk["directions"],"preview_frame_seconds":0.12}}
        atomic_json(stage/"runtime-preview.json",preview)
        result["runtime_preview_manifest"]=str(target/"runtime-preview.json")
        atomic_json(stage/"report.json",result)
        if cancelled():raise Cancelled()
        stage.rename(target);result["output_dir"]=str(target);return result
    except Exception:
        if stage.exists():shutil.rmtree(stage)
        raise
