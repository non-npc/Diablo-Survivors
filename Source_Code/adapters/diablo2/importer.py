"""Classic Diablo II asset preparation with a shipped path index and private cache."""
import hashlib,json,sqlite3,struct,time,io,wave
from pathlib import Path
from PIL import Image
from adapters.base.mpq import ClassicMPQ,StormArchive,safe_resource_path
from adapters.diablo2.formats import decode_dcc,rgba,cof,dc6,dc6_direction,dt1_floors,DIRECTIONS,dcc_direction
from inspector.services.metadata import executable_version
from inspector.services.workspace import atomic_json
from manager.services.paths import ROOT
COMPONENTS=("hd","tr","lg","ra","la","rh","lh","sh","s1","s2","s3","s4","s5","s6","s7","s8")
BASE_CLASSES={"barbarian":("ba","1hs","a1"),"amazon":("am","bow","a1"),"paladin":("pa","1hs","a1"),"necromancer":("ne","hth","sc"),"sorceress":("so","hth","sc")}
EXPANSION_CLASSES={"assassin":("ai","hth","a1"),"druid":("dz","hth","sc")}
CODEC_VERSION="diablo2-survival-4"

def detect(folder,include_expansion=True,validate_archives=True):
    folder=Path(folder).resolve()
    if not folder.is_dir():raise ValueError("Choose an existing game folder.")
    if any((folder/name).exists() for name in ["D2R.exe","D2R Launcher.exe"]) or (folder/"Data/data").is_dir():raise ValueError("Diablo II: Resurrected / Infernal Edition is not supported. Select classic Diablo II instead.")
    files={p.name.lower():p for p in folder.iterdir() if p.is_file()}
    missing=[n for n in ["d2data.mpq","d2char.mpq","d2sfx.mpq"] if n not in files]
    if missing:raise ValueError("Classic Diablo II folder is missing: "+", ".join(missing))
    archives=[files[n] for n in ["patch_d2.mpq","d2exp.mpq","d2char.mpq","d2data.mpq","d2sfx.mpq","d2speech.mpq"] if n in files and (include_expansion or n!="d2exp.mpq")]
    if validate_archives:
        for path in archives:ClassicMPQ(path)
    version=executable_version(files.get("game.exe",files.get("diablo ii.exe",folder/"Game.exe"))) or {}
    expansion=include_expansion and "d2exp.mpq" in files
    edition="diablo2-lod-en-107-baseline" if expansion else "diablo2-classic-en-100-baseline"
    return {"game_id":"diablo2","edition_id":edition,"verification":"compatible layout","folder":str(folder),"expansion":expansion,"version":version.get("fixed_product_version","unknown"),"archives":[str(p) for p in archives],"available_classes":list(BASE_CLASSES)+(list(EXPANSION_CLASSES) if expansion else [])}

class Assets:
    def __init__(self,identity,output):
        self.identity=identity;self.output=Path(output);self.used={};self.handles={};self.tables={}
        catalog=json.loads((ROOT/"catalogs/diablo2-classic-assets-v1.json").read_text())
        self.names={r["source_path"] for r in catalog["assets"]}
        # The expansion inventory is also bundled, so users do not discover paths.
        self.names.update(r["source_path"] for r in json.loads((ROOT/"catalogs/diablo2-lod-assets-v1.json").read_text()).get("assets",[]))
        self.candidates={}
        for path in identity["archives"]:
            filename=Path(path).name.lower();self.handles[filename]=StormArchive(path);self.tables[filename]=ClassicMPQ(path)
    def close(self):
        for archive in self.handles.values():archive.close()
    def read(self,name):
        name=safe_resource_path(name.lower())
        for archive,table in self.tables.items():
            metadata=table.lookup(name)
            if metadata:
                data=self.handles[archive].read(name)
                digest=hashlib.sha256(data).hexdigest();raw=self.output/"raw"/archive/name;raw.parent.mkdir(parents=True,exist_ok=True)
                if not raw.exists():raw.write_bytes(data)
                self.used[name]={"archive":archive,"sha256":digest,"raw_path":str(raw),"source_path":name,**metadata}
                return data
        raise FileNotFoundError("Required game asset not found: "+name)
    def inventory(self):
        for name in sorted(self.names):
            for archive,table in self.tables.items():
                metadata=table.lookup(name)
                if metadata:
                    yield name,archive,metadata
                    break
    def present(self,name):return any(t.lookup(name) for t in self.tables.values())
    def component(self,base,token,part,mode,weapon):
        prefix=f"data/global/{base}/{token}/{part}/{token}{part}"
        suffix=mode+weapon+".dcc"
        choices=[n for n in self.names if n.startswith(prefix) and n.endswith(suffix)]
        preferred=["lit","bhm","std","axe","bsd","lbw","des","med","hvy"]
        for equip in preferred:
            name=prefix+equip+suffix
            if self.present(name):return name
        for name in sorted(choices):
            if self.present(name):return name
        for equip in preferred:
            name=prefix+equip+mode+weapon+".dc6"
            if self.present(name):return name
        return None

def animation(assets,out,base,token,weapon,attack="a1",variants=None,flexible=False):
    out=Path(out);out.mkdir(parents=True,exist_ok=True);result={"clips":{},"provenance":{},"composition_version":3}
    palette=assets.read("data/global/palette/act1/pal.dat")
    modes={"idle":"nu","walk":"wl","attack":attack,"hit":"gh","death":"dt"}
    if base=="monsters" and any(assets.present(f"data/global/{base}/{token}/cof/{token}dd{w}.cof") for w in (weapon,"hth")):modes["dead"]="dd"
    for state,mode in modes.items():
        state_weapon="hth" if state=="death" and base=="chars" else weapon
        cof_name=f"data/global/{base}/{token}/cof/{token}{mode}{state_weapon}.cof"
        if state in ("death","dead") and not assets.present(cof_name):
            unarmed=f"data/global/{base}/{token}/cof/{token}{mode}hth.cof"
            if assets.present(unarmed):cof_name=unarmed;state_weapon="hth"
        if flexible and not assets.present(cof_name):
            for alternative in dict.fromkeys([mode,"rn" if state=="walk" else "a2" if state=="attack" else "nu","nu","dt"]):
                candidate=f"data/global/{base}/{token}/cof/{token}{alternative}{state_weapon}.cof"
                if assets.present(candidate):cof_name=candidate;mode=alternative;break
        composition=cof(assets.read(cof_name));components={};sources=[cof_name]
        for layer,layer_weapon in composition["layers"]:
            part=COMPONENTS[layer]
            if part=="sh" and base=="chars":continue
            name=assets.component(base,token,part,mode,layer_weapon)
            if variants and part in variants:
                candidate=f"data/global/{base}/{token}/{part}/{token}{part}{variants[part]}{mode}{layer_weapon}.dcc"
                if assets.present(candidate):name=candidate
            if name is None:
                if part in ("rh","lh","sh") or layer>=8:continue
                raise ValueError(f"Missing {token} {part} {state} component")
            data=assets.read(name)
            if flexible and (not variants or part not in variants) and name.endswith(".dcc") and struct.unpack_from("<I",data,3)[0]!=composition["frames"]:
                prefix=f"data/global/{base}/{token}/{part}/{token}{part}"
                choices=sorted(n for n in assets.names if n.startswith(prefix) and n.endswith(mode+layer_weapon+".dcc"))
                for candidate in choices:
                    if not assets.present(candidate):continue
                    trial=assets.read(candidate)
                    if struct.unpack_from("<I",trial,3)[0]==composition["frames"]:name=candidate;data=trial;break
            sources.append(name)
            if name.endswith(".dc6"):
                direction_count=struct.unpack_from("<I",data,16)[0]
                components[layer]=[dc6_direction(data,dcc_direction(direction_count,d)) for d in range(8)]
            else:components[layer]=[decode_dcc(data,dcc_direction(data[2],d)) for d in range(8)]
        if not components:raise ValueError("Empty character composition")
        left=min(pair[1][0] for rows in components.values() for pair in rows);top=min(pair[1][1] for rows in components.values() for pair in rows)
        right=max(pair[1][0]+pair[0][0].width for rows in components.values() for pair in rows)
        bottom=max(pair[1][1]+pair[0][0].height for rows in components.values() for pair in rows)
        width=max(128,2*max(abs(left),abs(right))+8);height=max(128,bottom-top+8)
        anchor=(width//2,height-bottom-4);count=composition["frames"]
        columns=min(count,max(1,8192//width));sheet_rows=(count+columns-1)//columns
        output_directions=1 if composition["directions"]==1 else 8
        sheet=Image.new("RGBA",(width*columns,height*output_directions*sheet_rows))
        for direction,internal in enumerate(DIRECTIONS[:output_directions]):
            for frame in range(count):
                image=Image.new("RGBA",(width,height))
                internal_direction=direction*composition["directions"]//8
                order=composition["priority"][(internal_direction*count+frame)*len(composition["layers"]):(internal_direction*count+frame+1)*len(composition["layers"])]
                for layer in order:
                    if layer not in components:continue
                    images,offset=components[layer][direction]
                    if len(images)!=count and not flexible:raise ValueError(f"COF/DCC frame count mismatch: {token} {state} layer {layer}: {count} vs {len(images)}")
                    # Original COFs control the timeline; shorter optional effect layers hold their last frame.
                    image.alpha_composite(rgba(images[min(frame,len(images)-1)],palette),(anchor[0]+offset[0],anchor[1]+offset[1]))
                sheet.alpha_composite(image,((frame%columns)*width,(direction*sheet_rows+frame//columns)*height))
        path=out/(state+".png");sheet.save(path)
        result["clips"][state]={"sheet":str(path),"frame_width":width,"frame_height":height,"frame_columns":columns,"anchor":list(anchor),"frames_per_direction":[count]*output_directions,"frame_seconds":0.065 if state=="walk" else 0.04 if state=="attack" else 0.09,"loop":state in ("idle","walk")}
        result["provenance"][state]=sources
    return result

def terrain(assets,out,name,palette_name="act1"):
    palette=assets.read(f"data/global/palette/{palette_name}/pal.dat")
    data=assets.read(name)
    tiles=dt1_floors(data)
    from adapters.diablo2.environment import base_tiles,continuous_ground
    if not tiles:raise ValueError("No floor tiles in "+name)
    tiles=base_tiles(data,tiles)
    tiles=tiles[:32];atlas=Image.new("RGBA",(128*8,64*((len(tiles)+7)//8)))
    for i,(index,image) in enumerate(tiles):atlas.alpha_composite(rgba(image,palette).resize((128,64),Image.Resampling.NEAREST),((i%8)*128,(i//8)*64))
    out=Path(out);out.parent.mkdir(parents=True,exist_ok=True);atlas.save(out)
    surface={}
    if "/outdoors/" in name or "/ground/" in name or "/siege/" in name:
        ground=out.with_name(out.stem+"-surface.png");continuous_ground(dt1_floors(data),palette).save(ground)
        surface={"surface_texture":str(ground)}
    return {**surface,"atlas":str(out),"cell_width":128,"cell_height":64,"columns":8,"tile_index":0,"tile_indices":list(range(len(tiles))),"source_path":name}

def audio(assets,out,classes,rosters,definitions=None):
    names=assets.names
    def pick(fragment,limit=2):return [n for n in sorted(names) if n.endswith(".wav") and fragment in n and assets.present(n)][:limit]
    associations={"loot.powerup":pick("cursor/levelup.wav"),"loot.xp":pick("cursor/pickup.wav"),"loot.healing":pick("item/potiondrink.wav"),"loot.gold":pick("item/gold"),"firebolt.impact":pick("skill/sorceress/firebolt")}
    for cls in classes:
        fragment="combat/weapon/one hand swing small" if cls in ("barbarian","paladin","assassin") else "combat/weapon/bow" if cls=="amazon" else "skill/necromancer/bonecast.wav" if cls=="necromancer" else "skill/druid/firecast" if cls=="druid" else "skill/sorceress/firebolt"
        associations[cls+".attack"]=pick(fragment)
        for event,term in [("hit","gethit" if cls in ("assassin","druid") else "hard"),("death","death")]:associations[cls+"."+event]=pick("combat/player/"+cls+"/"+term)
    for kind in rosters:
        for event,fragment in [("attack","roar" if kind=="fallen" else "attack"),("hit","gethit"),("death","death")]:
            group="zombie" if kind=="zombie" else "fallen" if kind=="fallen" else "fallenshaman" if kind=="fallen_shaman" else "spikefiend" if kind=="quill_rat" else "skeleton"
            if definitions is not None:group=definitions[kind].get("sound_group","")
            if not group:continue
            associations[kind+"."+event]=pick("monster/"+group+"/"+fragment)
    result={"sounds":{}};out=Path(out);out.mkdir(parents=True,exist_ok=True)
    for event,files in associations.items():
        result["sounds"][event]=[]
        for name in files:
            data=assets.read(name);digest=hashlib.sha256(data).hexdigest();path=out/(digest+".wav")
            if path.exists():
                result["sounds"][event].append({"path":str(path),"source_path":name,"sha256":digest,"association":"authored"});continue
            # Repack original PCM samples into a canonical RIFF, removing legacy chunks.
            with wave.open(io.BytesIO(data),"rb") as source:
                params=source.getparams();samples=source.readframes(source.getnframes())
            with wave.open(str(path),"wb") as target:
                target.setparams(params);target.writeframes(samples)
            result["sounds"][event].append({"path":str(path),"source_path":name,"sha256":digest,"association":"authored"})
    return result

def upgrade_icons(assets,output):
    """Use distinct original skill glyphs, excluding empty and pressed-state duplicates."""
    palette=assets.read("data/global/palette/act1/pal.dat")
    choices=[];seen=set();sources=[]
    for token in ["", "ba", "pa", "ne", "so", "am"]:
        source=f"data/global/ui/spells/{token}skillicon.dc6"
        for frame,decoded in enumerate(dc6(assets.read(source))):
            if frame%2:continue
            image=rgba(decoded,palette).resize((56,56),Image.Resampling.NEAREST)
            if sum(1 for r,g,b,a in image.getdata() if a and min(r,g,b)>190)<20:continue
            digest=hashlib.sha256(image.tobytes()).hexdigest()
            if digest in seen:continue
            seen.add(digest);choices.append(image);sources.append({"source_path":source,"frame":frame,"sha256":digest})
    upgrades=json.loads((ROOT/"runtime/resources/upgrades.json").read_text())
    ids=[upgrade["id"] for upgrade in upgrades]+["recovery"]
    if len(choices)<len(ids):raise ValueError("Not enough distinct Diablo II upgrade icons")
    sheet=Image.new("RGBA",(56*len(ids),56))
    for index in range(len(ids)):sheet.alpha_composite(choices[index],(index*56,0))
    path=Path(output)/"upgrade-icons-v1.png";sheet.save(path)
    return {"texture":str(path),"upgrade_indices":dict(zip(ids,range(len(ids)))),"sources":sources[:len(ids)],"version":2}

def add_ranged_enemies(assets,output,document,progress):
    specs={"skeleton_archer":("sk","bow","a1","arrow",80,440),"skeleton_mage":("sk","hth","a1","lightning",100,420),"fallen_shaman":("fs","hth","a1","fire",110,400),"quill_rat":("si","hth","a1","quill",70,360)}
    visuals=document.setdefault("enemy_visuals",{});definitions=document["configuration"].setdefault("enemy_definitions",{})
    for kind,(token,weapon,attack,missile,minimum,maximum) in specs.items():
        progress("Decoding "+kind.replace("_"," "))
        visuals[kind]=animation(assets,output/"monsters"/kind,"monsters",token,weapon,attack,{"s4":"lht","s5":"lht"} if kind=="skeleton_mage" else None)
        definitions[kind]={"ranged":True,"missile":missile,"ranged_min":minimum,"ranged_max":maximum,"shot_interval":2.2,"projectile_speed":340 if missile in ["arrow","quill"] else 270,"health_scale":0.85,"speed_scale":0.85,"impact":"bone" if kind.startswith("skeleton") else "blood"}
    for key,arena in document["arenas"].items():
        arena["enemy_definitions"]=definitions
        extras=["quill_rat","fallen_shaman"] if key=="tristram" else ["skeleton_archer","fallen_shaman"] if key=="cathedral" else ["skeleton_archer","skeleton_mage","fallen_shaman"]
        arena["enemy_roster"]=list(dict.fromkeys(arena["enemy_roster"]+extras))
        for kind in extras:
            if not any(c.get("enemy")==kind for c in arena["challenges"]):arena["challenges"].append({"id":kind+"-20","title":"Defeat 20 "+kind.replace("_"," "),"enemy":kind,"target":20})
    document["configuration"]["enemy_roster"]=document["arenas"]["cathedral"]["enemy_roster"]
    document["audio"]=audio(assets,output/"audio",document["available_classes"],visuals)
    document["ranged_enemies_version"]=2

def prepare(folder,workspace=None,progress=lambda message:None,include_expansion=True):
    identity=detect(folder,include_expansion,validate_archives=False);workspace=Path(workspace or ROOT/".local/diablo2").resolve()
    if workspace==Path(folder).resolve() or Path(folder).resolve() in workspace.parents:raise ValueError("Cache must be outside the game folder")
    fingerprints={p:[Path(p).stat().st_size,Path(p).stat().st_mtime_ns] for p in identity["archives"]}
    key=hashlib.sha256(json.dumps({"codec":CODEC_VERSION,"files":fingerprints},sort_keys=True).encode()).hexdigest()[:20]
    output=workspace/"generations"/key;manifest_path=output/"survival.json"
    if manifest_path.exists():
        cached=json.loads(manifest_path.read_text())
        from adapters.diablo2.bestiary import prepare_bestiary,VERSION
        if any(v.get('composition_version',0)<3 for v in cached.get('class_visuals',{}).values()):
            assets=Assets(identity,output)
            try:
                for cls in cached['available_classes']:
                    token,weapon,attack={**BASE_CLASSES,**EXPANSION_CLASSES}[cls]
                    progress('Correcting sprite directions: '+cls)
                    cached['class_visuals'][cls]=animation(assets,output/'classes'/cls,'chars',token,weapon,attack)
                cached['player_visual']=cached['class_visuals'][cached.get('default_class','barbarian')]
                if cached.get('cow_visual'):cached['cow_visual']=animation(assets,output/'cow','monsters','ec','hth')
            finally:assets.close()
            atomic_json(manifest_path,cached)
        if cached.get("bestiary_version")!=VERSION:
            assets=Assets(identity,output)
            try:
                prepare_bestiary(assets,output,cached,progress)
                cached["audio"]=audio(assets,output/"audio",cached["available_classes"],cached["enemy_visuals"],cached["configuration"]["enemy_definitions"])
            finally:assets.close()
            atomic_json(manifest_path,cached)
        if cached.get("ranged_enemies_version")!=2 and not cached.get("bestiary_version"):
            assets=Assets(identity,output)
            try:add_ranged_enemies(assets,output,cached,progress)
            finally:assets.close()
            atomic_json(manifest_path,cached)
        if cached.get("ui",{}).get("spell_icons",{}).get("version")!=2:
            assets=Assets(identity,output)
            try:cached.setdefault("ui",{})["spell_icons"]=upgrade_icons(assets,output)
            finally:assets.close()
            atomic_json(manifest_path,cached)
        if cached.get("source_game",{}).get("version")!=identity["version"]:
            cached["source_game"].update(version=identity["version"],verification="compatible classic layout; executable version changed")
            atomic_json(manifest_path,cached)
        from adapters.diablo2.environment import upgrade_environment,VERSION as ENVIRONMENT_VERSION
        if cached.get('environment_version')!=ENVIRONMENT_VERSION:
            assets=Assets(identity,output)
            try:upgrade_environment(assets,output,cached,progress)
            finally:assets.close()
            atomic_json(manifest_path,cached)
        from adapters.diablo2.spells import build_spells,VERSION as SPELLS_VERSION
        if cached.get('spell_effects_version')!=SPELLS_VERSION:
            progress('Decoding original caster spell animations')
            assets=Assets(identity,output)
            try:cached['spell_effects']=build_spells(assets,output/'spells')
            finally:assets.close()
            cached['spell_effects_version']=SPELLS_VERSION;atomic_json(manifest_path,cached)
        return manifest_path
    profile=json.loads((ROOT/"profiles"/(identity["edition_id"]+".json")).read_text())
    actual_files={Path(p).name.lower():Path(p) for p in identity["archives"]}
    verified=identity["version"]==profile["executable_product_version"] and "patch_d2.mpq" not in actual_files
    for archive in profile["archives"]:
        if not verified:break
        source=actual_files[archive["path"]]
        if source.stat().st_size!=archive["size_bytes"]:verified=False;break
        progress("Identifying "+source.name)
        with source.open("rb") as stream:
            if hashlib.file_digest(stream,"sha256").hexdigest()!=archive["sha256"]:verified=False;break
    identity["verification"]="verified edition" if verified else "compatible classic layout; edition fingerprints differ"
    output.mkdir(parents=True,exist_ok=True);assets=Assets(identity,output)
    try:
        from scripts.run_survival_demo import configuration
        from adapters.diablo1.zones import zone_catalog
        classes=dict(BASE_CLASSES)
        if identity["expansion"]:classes.update(EXPANSION_CLASSES)
        visuals={}
        initial_total=len(classes)+9
        for position,(cls,(token,weapon,attack)) in enumerate(classes.items(),1):
            progress(f"[{position}/{initial_total}] Decoding "+cls.capitalize());visuals[cls]=animation(assets,output/"classes"/cls,"chars",token,weapon,attack)
        progress(f"[{len(classes)+1}/{initial_total}] Decoding cow")
        cow=animation(assets,output/"cow","monsters","ec","hth")
        monsters={}
        for position,(kind,token,weapon) in enumerate([("skeleton","sk","1hs"),("zombie","zm","hth"),("fallen","fa","hth")],len(classes)+2):
            progress(f"[{position}/{initial_total}] Decoding "+kind);monsters[kind]=animation(assets,output/"monsters"/kind,"monsters",token,weapon)
        terrains={}
        for family,path,pal in [("cathedral","data/global/tiles/act1/crypt/floor.dt1","act1"),("tristram","data/global/tiles/act1/outdoors/swamp.dt1","act1"),("catacombs","data/global/tiles/act1/catacomb/floor.dt1","act1"),("caves","data/global/tiles/act1/caves/cave.dt1","act1"),("hell","data/global/tiles/act4/diab/floor.dt1","act4")]:
            progress(f"[{len(classes)+5+len(terrains)}/{initial_total}] Decoding "+family+" floors");terrains[family]=terrain(assets,output/"terrain"/(family+".png"),path,pal)
        definitions={kind:{"ranged":False,"health_scale":1.3 if kind=="zombie" else 1.0,"speed_scale":0.8 if kind=="zombie" else 1.1 if kind=="fallen" else 1.0,"impact":"bone" if kind=="skeleton" else "blood"} for kind in monsters}
        arenas={}
        for zone in zone_catalog():
            key=zone["id"];family="tristram" if key=="tristram" else "hell" if key.startswith(("hell","lazarus")) else "caves" if key.startswith(("caves","poisoned")) else "catacombs" if key.startswith(("catacombs","bone")) else "cathedral"
            depth=zone.get("floor",1)
            challenges=[{"id":kind+"-"+str(target),"title":f"Defeat {target} {kind}","enemy":kind,"target":target} for kind in ["zombie","skeleton","fallen"] for target in [15+depth*2,40+depth*3]]
            arenas[key]={"title":zone["title"],"terrain":terrains[family],"arena_width":3200,"arena_height":2400,"challenges":challenges,"enemy":{"health":14+depth*2,"speed":62+depth*1.5,"contact_damage":7+depth//3},"enemy_roster":list(monsters),"enemy_definitions":definitions,"boss":""}
        progress("Caching audio")
        document={"schema_version":1,"game_id":"diablo2","source_game":identity,"title":"Cathedral — Floor 1","profile_id":"diablo2-classic-survival","available_classes":list(classes),"default_class":"barbarian","class_names":{c:c.capitalize() for c in classes},"player_visual":visuals["barbarian"],"enemy_visual":monsters["skeleton"],"cow_visual":cow,"class_visuals":visuals,"enemy_visuals":monsters,"terrain":terrains["cathedral"],"configuration":configuration(),"default_arena":"cathedral","arenas":arenas,"audio":audio(assets,output/"audio",classes,monsters),"save_path":str(ROOT/".local/demo/progress/diablo2-v2.json")}
        document["configuration"].update(enemy_roster=list(monsters),enemy_definitions=definitions)
        document["ui"]={"spell_icons":upgrade_icons(assets,output)}
        from adapters.diablo2.bestiary import prepare_bestiary
        prepare_bestiary(assets,output,document,progress)
        from adapters.diablo2.spells import build_spells,VERSION as SPELLS_VERSION
        document["spell_effects"]=build_spells(assets,output/"spells");document["spell_effects_version"]=SPELLS_VERSION
        document["audio"]=audio(assets,output/"audio",document["available_classes"],document["enemy_visuals"],document["configuration"]["enemy_definitions"])
        with sqlite3.connect(output/"assets.sqlite3") as db:
            db.execute("CREATE TABLE IF NOT EXISTS assets (source_path TEXT PRIMARY KEY,archive_path TEXT,raw_path TEXT,payload_sha256 TEXT,type TEXT,metadata_json TEXT)")
            for name,archive,metadata in assets.inventory():
                row=assets.used.get(name,{})
                db.execute("INSERT OR REPLACE INTO assets VALUES (?,?,?,?,?,?)",(name,archive,row.get("raw_path"),row.get("sha256"),{'.dcc':'sprite','.dc6':'sprite','.dt1':'terrain','.wav':'audio'}.get(Path(name).suffix,'metadata'),json.dumps(metadata)))
        atomic_json(output/"identity.json",identity);atomic_json(manifest_path,document)
        atomic_json(workspace/"active.json",{"manifest_path":str(manifest_path),"database_path":str(output/"assets.sqlite3"),"identity":identity,"fingerprints":fingerprints})
        return manifest_path
    finally:assets.close()
