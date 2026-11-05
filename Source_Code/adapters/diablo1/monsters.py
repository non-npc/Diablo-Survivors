"""Original base-game enemy metadata, private decoded animation cache and zone rosters."""
import hashlib,json,math,sqlite3,struct
from pathlib import Path
from PIL import Image
from inspector.services.recognition import sprite_groups,frame_layout,palette_image
from manager.services.paths import ROOT
def metadata():return json.loads((ROOT/"catalogs/diablo1/monster_metadata.json").read_text())
def build_monsters(database,folder,zones,progress=lambda message:None):
    document=metadata();rows=document["monsters"]
    with sqlite3.connect(database) as c:
        entries={n.replace("\\","/"):(Path(p),sha) for n,p,sha in c.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    rosters={};needed={};bosses={}
    for zone in zones:
        key=zone["id"];floor=zone.get("floor",1)
        if zone.get("quest_map"):
            raw=entries[zone["quest_map"]][0].read_bytes();w,h=struct.unpack_from("<HH",raw)
            values=struct.unpack_from("<"+"H"*(w*h*4),raw,4+w*h*10)
            ids=sorted({document["dun_conversion"][v-1] for v in values if v and v<=len(document["dun_conversion"])})
        elif floor==16:ids=[96,108]
        else:ids=[r["index"] for r in rows if r["available"] in ("MAT_ALWAYS","MAT_RETAIL") and r["min_floor"]<=floor<=r["max_floor"]]
        roster=[]
        for index in ids:
            row=rows[index]
            if all(row["graphics"].replace("%c",suffix) in entries for suffix in "nwahd"):
                needed[row["id"]]=row;roster.append(row["id"])
        if not roster:raise ValueError("No verified enemy assets for "+key)
        rosters[key]=roster
        boss_index=50 if key=="skeleton-king" else 110 if floor==16 else 51 if floor==2 else None
        if boss_index is not None:
            boss=rows[boss_index];needed[boss["id"]]=boss;bosses[key]=boss["id"]
        if key=="lazarus":
            for base,name,translation in [(108,"Archbishop Lazarus","general"),(103,"Red Vex","redv"),(103,"Black Jade","blkjd")]:
                row=rows[base].copy();row["id"]=name.lower().replace(" ","-");row["name"]=name
                row["translation"]="monsters/monsters/"+translation+".trn";row["boss"]=True
                if row["translation"] not in entries:raise ValueError("Missing unique enemy translation: "+row["translation"])
                needed[row["id"]]=row
                if base==108:bosses[key]=row["id"]
                else:rosters[key].append(row["id"])
    visuals={};sounds={};definitions={};palette_path="levels/l1data/l1_1.pal"
    for position,(actor,row) in enumerate(needed.items(),1):
        progress(f"[{position}/{len(needed)}] Bestiary: "+row["name"])
        files={state:row["graphics"].replace("%c",suffix) for state,suffix in zip(("idle","walk","attack","hit","death"),"nwahd")}
        names=list(files.values())+[palette_path]+([row["translation"]] if row["translation"] else [])
        if any(n not in entries for n in names):raise ValueError("Missing original enemy resource: "+actor)
        identity={"decoder":"zone-monsters-1","width":row["width"],"inputs":{n:entries[n][1] for n in names}}
        digest=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()[:16]
        target=Path(folder)/actor/digest;meta=target/"monster.json"
        if meta.is_file():visual=json.loads(meta.read_text())
        else:
            target.mkdir(parents=True,exist_ok=True);palette=entries[palette_path][0].read_bytes()
            translation=entries[row["translation"]][0].read_bytes() if row["translation"] else None
            if translation is not None and len(translation)!=256:raise ValueError("Invalid enemy TRN")
            visual={"clips":{},"provenance":{"files":files,"translation":row["translation"],"width":"original monster table"}}
            for state,path in files.items():
                data=entries[path][0].read_bytes();groups=sprite_groups(data);decoded=[]
                if len(groups) not in (1,8):raise ValueError("Invalid monster direction count")
                for group in groups:
                    frames=[]
                    for begin,end in group:
                        w,h,indices,alpha=frame_layout(data[begin:end],"CL2",row["width"])
                        if translation is not None:indices=bytes(indices).translate(translation)
                        frames.append(palette_image(indices,alpha,w,h,palette))
                    decoded.append(frames)
                width=row["width"];height=max(im.height for frames in decoded for im in frames);columns=max(map(len,decoded))
                sheet=Image.new("RGBA",(width*columns,height*len(groups)))
                for direction,frames in enumerate(decoded):
                    for i,image in enumerate(frames):sheet.alpha_composite(image,(i*width,direction*height+height-image.height))
                path=target/(state+".png");sheet.save(path)
                visual["clips"][state]={"sheet":str(path.resolve()),"frame_width":width,"frame_height":height,"frames_per_direction":[len(frames) for frames in decoded],"frame_seconds":0.09 if state!="attack" else 0.055,"loop":state in ("idle","walk")}
            meta.write_text(json.dumps(visual,indent=2)+"\n")
        visuals[actor]=visual
        definitions[actor]={"id":actor,"name":row["name"],"original_floor_range":[row["min_floor"],row["max_floor"]],"ai_reference":row["ai"],"impact":"bone" if any(part in row["graphics"] for part in ("/skelaxe/","/skelbow/","/skelsd/","/sking/")) else "metal" if "/black/" in row["graphics"] else "blood","ranged":row["ai"] in ("AI_SKELBOW","AI_GOATBOW","AI_ACID","AI_SUCC","AI_COUNSLR","AI_MEGA","AI_LAZURUS"),"missile":"arrow" if row["ai"] in ("AI_SKELBOW","AI_GOATBOW") else "acid" if row["ai"]=="AI_ACID" else "spell","health_scale":min(2.0,max(0.6,sum(row["original_hp"])/100)),"speed_scale":0.75 if row["ai"]=="AI_ZOMBIE" else 1.15 if row["ai"] in ("AI_FALLEN","AI_SCAV","AI_SNAKE") else 1.0}
        for event,suffix in [("attack","a"),("hit","h"),("death","d")]:
            paths=[row["sound"].replace("%c",suffix).replace("%i",str(i)) for i in (1,2)]
            sounds[actor+"."+event]=[{"path":str(entries[n][0]),"source_path":n,"sha256":entries[n][1],"association":"original-monster-table"} for n in paths if n in entries]
    return {"visuals":visuals,"sounds":sounds,"definitions":definitions,"rosters":rosters,"bosses":bosses}

def zone_challenges(roster,definitions,boss=None):
    # Milestones follow named enemies actually spawned in this survival zone.
    result=[]
    if boss:result.append({"id":boss+"-1","title":"Defeat "+definitions[boss]["name"],"enemy":boss,"target":1})
    for target in (15,40):
        for actor in roster:
            result.append({"id":actor+"-"+str(target),"title":"Defeat "+str(target)+" "+definitions[actor]["name"],"enemy":actor,"target":target})
    return result
