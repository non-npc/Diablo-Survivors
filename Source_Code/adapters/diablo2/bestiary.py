"""Versioned bestiary and area preparation from the user's classic game tables."""
import csv, hashlib, json, re, struct, sqlite3
from pathlib import Path
from PIL import Image
from inspector.services.workspace import atomic_json

VERSION = 11
SOUND_GROUPS={"sk":"skeleton","zm":"zombie","fa":"fallen","fs":"fallenshaman","si":"spikefiend","ye":"yeti","sr":"sandraider","wr":"wraith","cr":"corrupt","bb":"baboondemon","go":"goatman","sm":"sandmaggot","sw":"sandmaggotbaby","sd":"serpentdemon","sl":"leaper","pw":"pantherwoman","mo":"mosquito","sc":"swarm","sp":"spider","mm":"mummy","gm":"greatermummy","va":"vampire","bt":"batdemon","bk":"hawk","bh":"bighead","th":"thornhulk","fe":"pygmy","fc":"pygmy","fk":"bonefetish","fd":"frogdemon","fw":"willowisp","fr":"fingermage","um":"undeadhorror","dm":"megademon","cs":"scimitar","pn":"pinhead","vd":"vulturedemon","vm":"vilemother","gy":"regurgitator","ww":"vilechild","zz":"zakarumzealot","zp":"zakarumpriest","hp":"zakarumhighpriest","ec":"moo","an":"andariel","du":"duriel","mp":"mephisto","di":"diablo","su":"summoner","re":"reanimatedhorde","ox":"siegebeast","io":"yeti","xx":"minion","xy":"minion","0b":"succubus","0c":"succubus","os":"overseer","ip":"imp","f0":"frozenhorror","l3":"bloodlord","xu":"npc","m5":"deathmauler","42":"baal","45":"putriddefiler","46":"vilechild","43":"baalminion"}
SOUND_GROUPS.update({"gm":"goatman","gy":"greatermummy","sw":"swarm","sc":"beetle","ww":"willowisp","fw":"pygmyshaman","cs":"regurgitator","bn":"hawknest","rd":"greatermummy","22":"izual","gz":"smith","5p":"smith","0d":"guard","0e":"guard","0f":"guard"})
TABLE = "data/global/excel/"
BOSSES = {17:267,28:402,37:156,38:365,49:229,73:211,74:250,102:242,105:256,108:243,120:541,124:527,132:545}
BOSSES = {level:(index-1 if index>410 else index) for level,index in BOSSES.items()}
# LoD 1.07 ships pre-release Act V population placeholders in Levels.txt/bin.
# These authored normal-mode rosters use native Act V families, not those guests.
ACT5 = {
    110:[454,480,493],111:[455,481,494,530],112:[456,482,442,495],
    113:[437,447,502,507],114:[438,448,503],115:[439,449,504,508],
    116:[440,450,505],117:[457,483,443,496],118:[441,470,509],
    119:[458,471,475],120:[541,542,543],121:[440,473,477],
    122:[441,474,478],123:[441,474,479],124:[441,474,479],
    125:[458,483,444,497],126:[458,483,444,497],127:[458,483,445,497],
    128:[441,547,507],129:[460,548,508],130:[461,549,509],
    131:[381,558,559,572],132:[545],
}
ACT5 = {level:[index-1 if index>410 else index for index in indices] for level,indices in ACT5.items()}
NAMES = {111:"Frigid Highlands",113:"Crystalline Passage",114:"Frozen River",115:"Glacial Trail",116:"Drifter Cavern",117:"Frozen Tundra",118:"Ancients' Way",119:"Icy Cellar",120:"Arreat Summit",123:"Halls of Pain",125:"Abaddon",126:"Pit of Acheron",127:"Infernal Pit",108:"Chaos Sanctuary",132:"Worldstone Chamber"}
UNIQUE_AREAS={"Bishibosh":3,"Bonebreak":18,"Coldcrow":9,"Rakanishu":4,"Treehead WoodFist":5,"The Countess":25,"Pitspawn Fouldog":29,"Boneash":33,"Bloodwitch the Wild":56,"Fangskin":61,"Beetleburst":43,"Leatherarm":59,"Coldworm the Burrower":64,"Fire Eye":54,"Dark Elder":44,"Ancient Kaa the Soulless":72,"Web Mage the Burning":85,"Witch Doctor Endugu":91,"Stormtree":79,"Sarina the Battlemaid":94,"Icehawk Riftwing":92,"Ismail Vilehand":83,"Geleb Flamefinger":83,"Bremm Sparkfist":102,"Toorc Icefist":83,"Wyand Voidfinger":102,"Maffer Dragonhand":102,"Infector of Souls":108,"Lord De Seis":108,"Grand Vizier of Chaos":108,"Corpsefire":8,
    "Siege Boss":110,"Axe Dweller":111,"Bonesaw Breaker":115,"Dac Farren":110,"Megaflow Rectifier":111,"Eyeback Unleashed":111,"Threash Socket":112,"Pindleskin":121,"Snapchip Shatter":119,"Frozenstein":114,"Baal Subject 1":131,"Baal Subject 2":131,"Baal Subject 3":131,"Baal Subject 4":131,"Baal Subject 5":131}
# Original 1.07 expansion text uses placeholder class IDs for these presets.
UNIQUE_NATIVE={"Siege Boss":479,"Axe Dweller":454,"Bonesaw Breaker":437,"Dac Farren":492,"Megaflow Rectifier":479,"Eyeback Unleashed":529,"Threash Socket":441,"Pindleskin":436,"Snapchip Shatter":501,"Frozenstein":447,"Baal Subject 1":62,"Baal Subject 2":105,"Baal Subject 3":557,"Baal Subject 4":558,"Baal Subject 5":571}
UNIQUE_NAMES={"Siege Boss":"Shenk the Overseer","Axe Dweller":"Eldritch the Rectifier","Megaflow Rectifier":"Sharptooth Slayer","Threash Socket":"Thresh Socket","Baal Subject 1":"Colenzo the Annihilator","Baal Subject 2":"Achmel the Cursed","Baal Subject 3":"Bartuc the Bloody","Baal Subject 4":"Ventar the Unholy","Baal Subject 5":"Lister the Tormentor"}

def rows(assets,name):
    return [row for row in csv.DictReader(assets.read(TABLE+name+".txt").decode("cp1252").splitlines(),delimiter="\t") if row.get("Class",row.get("Name",""))!="Expansion"]

def localized_names(assets):
    result={}
    for filename in ["string.tbl","expansionstring.tbl","patchstring.tbl"]:
        path="data/local/lng/eng/"+filename
        if not assets.present(path):continue
        data=assets.read(path)
        if len(data)<21:raise ValueError("Truncated string table")
        _,entries,hash_count,version,_,_,length=struct.unpack_from("<HHIBIII",data)
        start=21+entries*2
        if start+hash_count*17>len(data) or length!=len(data):raise ValueError("Invalid string table bounds")
        for slot in range(hash_count):
            active,index,hash_value,key_offset,value_offset,value_length=struct.unpack_from("<BHIIIH",data,start+slot*17)
            if not active:continue
            if key_offset>=len(data) or value_offset+value_length>len(data):raise ValueError("String entry outside table")
            key=data[key_offset:data.find(b"\0",key_offset)].decode("cp1252")
            result[key]=data[value_offset:value_offset+value_length].rstrip(b"\0").decode("cp1252").strip()
    return result

def number(row,key,default=0):
    try:return int(row.get(key,default) or default)
    except ValueError:return default

def display_name(value):
    return re.sub(r"(?<=[a-z])(?=[A-Z])"," ",value).replace("exp","").strip()

def plans(assets):
    from manager.services.paths import ROOT
    catalog=ROOT/"catalogs/diablo2"/(assets.identity.get("edition_id","")+"-bestiary.json")
    if catalog.is_file():
        template=json.loads(catalog.read_text())
        if template.get("version")==VERSION and all(hashlib.sha256(assets.read(path)).hexdigest()==digest for path,digest in template.get("table_sha256",{}).items()) and template.get("table_sha256"):
            return template["monster_rows"],template["areas"]
    monsters=rows(assets,"monstats");levels=rows(assets,"levels")
    if not monsters or "Code" not in monsters[0] or "Class" not in monsters[0] or not levels or "Mtot" not in levels[0]:
        raise ValueError("This bestiary supports the classic 1.00–1.07 table layout. This installation uses a different monster/level table format.")
    areas=[]
    for level in levels:
        level_id=number(level,"Id");act=number(level,"Act")+1
        if level_id in (0,1,39,40,75,103,109) or (act==5 and not assets.identity["expansion"]):continue
        population=[number(level,"M"+str(i)) for i in range(1,number(level,"Mtot")+1)]
        population += [number(level,"S"+str(i)) for i in range(1,26) if number(level,"S"+str(i))>0]
        if act==5:population=ACT5.get(level_id,population)
        population=list(dict.fromkeys(i for i in population if 0<=i<len(monsters) and monsters[i].get("IsNPC")=="0" and monsters[i].get("IsAtt")=="1"))
        boss=BOSSES.get(level_id)
        if boss is not None and boss not in population:population.append(boss)
        if not population:continue
        areas.append({"id":f"d2-area-{level_id}","level_id":level_id,"act":act,"title":NAMES.get(level_id,level["LevelName"]),"level":max(1,number(level,"MonLvl1")),"monster_indices":population,"boss_index":boss,"roster_source":"authored-native-act5-107" if act==5 else "levels.txt normal population and special population","source_path":TABLE+"levels.txt"})
    # Keep the secret cow map as the existing portal event, outside area unlocks.
    return monsters,areas

def profile(row,index,missiles):
    token=row["Code"].lower();weapon=row.get("BaseW","hth").lower()
    missile_ids=[number(row,key,65535) for key in ["MissA1","MissA2","MissS1","MissS2","MissS3","MissS4","MissC"]]
    names=" ".join((missiles[i].get("Missile","")+" "+missiles[i].get("EType","")).lower() for i in missile_ids if 0<=i<len(missiles))
    ranged=weapon=="bow" or any(i not in (0,65535) and 0<=i<len(missiles) for i in missile_ids) or token in ("fs","fw","ww","va","fr","zp","gy","su","ip","0b","0c") or (token=="um" and weapon in ("mgk","hth"))
    missile="arrow" if weapon=="bow" else "quill" if token=="si" else "ice" if any(s in names for s in ("cold","ice")) else "acid" if any(s in names for s in ("poison","acid")) else "lightning" if any(s in names for s in ("light","bolt","nova")) else "fire" if any(s in names for s in ("fire","inferno")) or token in ("fs","va","ip","dm") else "spell"
    if "pois" in names:missile="acid"
    elif "ltng" in names or token=="ww":missile="lightning"
    elif token in ("fs","fw"):missile="fire"
    return {"id":f"d2-monster-{index}","name":display_name(row["Class"]),"original_index":index,"token":token,"weapon":weapon,"sound_group":SOUND_GROUPS.get(token,""),"stationary":number(row,"Velocity",4)==0 or number(row,"ModeW",1)==0,"ranged":ranged,"missile":missile,"ranged_min":30 if token=="dm" else 80,"ranged_max":220 if token=="dm" else 420,"shot_interval":2.2,"projectile_speed":340 if missile in ("arrow","quill") else 270,"health_scale":min(2,max(0.65,(number(row,"MinHP",20)+number(row,"MaxHP",20))/80)),"speed_scale":min(1.4,max(0.65,number(row,"Velocity",4)/5)),"impact":"bone" if token in ("sk","re","fk") else "blood","source_path":TABLE+"monstats.txt","original_skills":[number(row,"Skill"+str(i)) for i in range(1,6) if number(row,"Skill"+str(i))],"behavior_scope":"survival melee/ranged; original special AI not reproduced"}

def recolor_visual(visual,assets,row,index,output):
    token=row["Code"].lower();path=f"data/global/monsters/{token}/cof/palshift.dat"
    base=number(row,"BaseId",index+1)-1;shift=index-base
    if not 0<shift<8 or not assets.present(path):return visual
    data=assets.read(path)
    if len(data)<(shift+1)*256:return visual
    palette=assets.read("data/global/palette/act1/pal.dat")
    rgb=bytes(c for i in range(256) for c in palette[i*3:i*3+3][::-1])
    translated=bytes(c for i in data[shift*256:(shift+1)*256] for c in palette[i*3:i*3+3][::-1])
    result=json.loads(json.dumps(visual));target=Path(output);target.mkdir(parents=True,exist_ok=True)
    pal=Image.new("P",(1,1));pal.putpalette(rgb)
    for state,clip in result["clips"].items():
        destination=target/(state+("-shields" if visual.get("composition_version",0)>=2 else "")+"-layout3.png")
        if not destination.exists():
            with Image.open(clip["sheet"]) as image:
                alpha=image.getchannel("A");indexed=image.convert("RGB").quantize(palette=pal,dither=Image.Dither.NONE);indexed.putpalette(translated)
                colored=indexed.convert("RGBA");colored.putalpha(alpha);colored.save(destination)
        clip["sheet"]=str(destination)
    result["provenance"]["palette_shift"]={"source_path":path,"table":shift,"basis":"normal variant index minus base-family index"}
    return result

def normalize_visual(visual,assets):
    for state,clip in visual["clips"].items():
        if "frame_columns" in clip:continue
        width=clip["frame_width"];height=clip["frame_height"];count=clip["frames_per_direction"][0]
        source=visual["provenance"][state][0]
        directions=1 if assets.read(source)[2]==1 else 8
        columns=min(count,max(1,8192//width));rows_per_direction=(count+columns-1)//columns
        with Image.open(clip["sheet"]) as image:
            sheet=Image.new("RGBA",(columns*width,directions*rows_per_direction*height))
            for direction in range(directions):
                for frame in range(count):
                    sprite=image.crop((frame*width,direction*height,(frame+1)*width,(direction+1)*height))
                    sheet.alpha_composite(sprite,((frame%columns)*width,(direction*rows_per_direction+frame//columns)*height))
        destination=Path(clip["sheet"]).with_name(state+"-packed.png");sheet.save(destination)
        clip.update(sheet=str(destination),frame_columns=columns,frames_per_direction=[count]*directions)
    return visual

def area_floors(area):
    act=area["act"];level=area["level_id"];title=area["title"].lower()
    if act==1:
        if any(word in title for word in ["crypt","mausoleum"]):return ["act1/crypt/floor.dt1"]
        if any(word in title for word in ["catacomb","jail","barracks","cathedral"]):return ["act1/catacomb/floor.dt1"]
        if any(word in title for word in ["cave","passage","pit","hole","den"]):return ["act1/caves/cave.dt1"]
    if act==2:
        if "arcane" in title:return ["act2/arcane/sanctuary.dt1"]
        if "maggot" in title:return ["act2/maggot/floor.dt1"]
        if "harem" in title:return ["act2/palace/haremflr.dt1"]
        if "cellar" in title:return ["act2/palace/cellflr.dt1"]
        if any(word in title for word in ["tomb","temple","dead","tunnel","duriel"]):return ["act2/tomb/tomb.dt1"]
        if "sewer" in title:return ["act2/sewer/chamb.dt1"]
    if act==3:
        if "spider" in title:return ["act3/spider/lair.dt1"]
        if "sewer" in title:return ["act3/sewer/floors.dt1"]
        if level>=79 and level<=83:return ["act3/kurast/floors.dt1"]
        if level>=86:return ["act3/travincal/floors.dt1","act3/kurast/floors.dt1"]
    if act==5:
        if 113<=level<=116 or level in (118,119):return ["expansion/icecave/interior.dt1"]
        if level==120:return ["expansion/mountaintop/floor.dt1"]
        if 125<=level<=127:return ["act4/diab/floor.dt1"]
        if level>=128:return ["expansion/baallair/floor.dt1"]
    return []

def prepare_bestiary(assets,output,document,progress):
    from adapters.diablo2.importer import animation,terrain
    monsters,areas=plans(assets)
    missile_rows=rows(assets,"missiles");names=localized_names(assets)
    uniques=[]
    for unique in rows(assets,"superuniques"):
        title=unique.get("Name","");level_id=UNIQUE_AREAS.get(title)
        if level_id is None or (level_id>=110 and not assets.identity["expansion"]):continue
        original=UNIQUE_NATIVE.get(title,number(unique,"Class",-1))
        if not 0<=original<len(monsters):raise ValueError("Invalid unique monster base: "+title)
        uniques.append({"id":"d2-unique-"+re.sub(r"[^a-z0-9]+","-",title.lower()).strip("-"),"name":UNIQUE_NAMES.get(title,names.get(title) or title),"level_id":level_id,"original_index":original,"source_name":title,"mods":[number(unique,"Mod"+str(i)) for i in range(1,4) if number(unique,"Mod"+str(i))]})
    needed=sorted({i for area in areas for i in area["monster_indices"]})
    needed=sorted(set(needed)|{unique["original_index"] for unique in uniques})
    definitions={};visuals={};compositions={};errors=[]
    total=len(needed)+len(uniques)+len(areas)
    for position,index in enumerate(needed,1):
        row=monsters[index];kind=f"d2-monster-{index}";definition=profile(row,index,missile_rows)
        definition["name"]=names.get(row.get("namco","")) or display_name(row.get("namco","") or row["Class"])
        if index in (540,541,542):definition.update(unique=True,spawn_after=5.0)
        token=definition["token"];weapon=definition["weapon"]
        element={"fire":"fir","ice":"cld","acid":"pos","lightning":"lht"}.get(definition["missile"],"lht")
        variants={"s4":element,"s5":element} if token=="sk" and weapon=="hth" else None
        key=token+"-"+weapon
        if variants:key+="-"+element
        progress(f"[{position}/{total}] Bestiary: "+definition["name"])
        try:
            if key not in compositions:
                cached=output/"bestiary"/key/"visual.json"
                if cached.exists():compositions[key]=json.loads(cached.read_text())
                needs_decode=key not in compositions or compositions.get(key,{}).get("composition_version",0)<3 or (token=="cr" and "dead" not in compositions[key].get("clips",{}))
                if not needs_decode:
                    death_source=compositions[key]["provenance"]["death"][0]
                    needs_decode=(f"{token}dt" not in death_source and assets.present(f"data/global/monsters/{token}/cof/{token}dthth.cof"))
                if not needs_decode and compositions[key].get("composition_version",0)<2:
                    from adapters.diablo2.formats import cof
                    idle_source=compositions[key]["provenance"]["idle"][0]
                    needs_decode=any(layer==7 for layer,weapon_code in cof(assets.read(idle_source))["layers"])
                if needs_decode:
                    compositions[key]=animation(assets,cached.parent,"monsters",token,weapon,variants=variants,flexible=True)
                    atomic_json(cached,compositions[key])
            compositions[key]=normalize_visual(compositions[key],assets)
            atomic_json(output/"bestiary"/key/"visual.json",compositions[key])
            visuals[kind]=recolor_visual(compositions[key],assets,row,index,output/"bestiary"/kind)
            definitions[kind]=definition
        except (ValueError,FileNotFoundError,IndexError) as error:errors.append({"id":kind,"name":definition["name"],"error":str(error)})
    if errors:
        atomic_json(output/"bestiary-errors.json",errors)
        raise ValueError(f"Bestiary import needs fixes for {len(errors)} original compositions; see {output/'bestiary-errors.json'}")
    atomic_json(output/"bestiary-errors.json",[])
    for position,unique in enumerate(uniques,len(needed)+1):
        progress(f"[{position}/{total}] Bestiary: "+unique["name"])
        base=f"d2-monster-{unique['original_index']}";kind=unique["id"]
        definitions[kind]={**definitions[base],"id":kind,"name":unique["name"],"unique":True,"health_scale":float(definitions[base]["health_scale"])*3,"source_path":TABLE+"superuniques.txt","original_modifiers":unique["mods"],"preset_placement":"authored explicit area mapping"}
        visuals[kind]=visuals[base]
    terrains={};arenas={}
    for position,area in enumerate(areas,len(needed)+len(uniques)+1):
        progress(f"[{position}/{total}] Area: "+area["title"])
        act=area["act"];preferred=area_floors(area);family=f"act{act}-"+(preferred[0].replace("/","-") if preferred else "outdoors")
        if family not in terrains:
            candidates={1:["act1/outdoors/swamp.dt1"],2:["act2/outdoors/desert.dt1","act2/outdoors/dune.dt1"],3:["act3/ground/darkgrass.dt1","act3/kurast/floors.dt1"],4:["act4/diab/floor.dt1"],5:["expansion/siege/ground.dt1","expansion/siege/snow.dt1"]}[act]
            for candidate in preferred+candidates:
                source="data/global/tiles/"+candidate
                if assets.present(source):
                    try:terrains[family]=terrain(assets,output/"terrain"/(family+"-bestiary.png"),source,"act"+str(act));break
                    except ValueError:pass
            if family not in terrains:raise ValueError("No verified floor source for "+family)
        roster=[f"d2-monster-{i}" for i in area["monster_indices"]];boss=f"d2-monster-{area['boss_index']}" if area["boss_index"] is not None else ""
        unique_roster=[unique["id"] for unique in uniques if unique["level_id"]==area["level_id"]]
        if area["level_id"]==120:unique_roster += [kind for kind in roster if kind!=boss]
        roster=list(dict.fromkeys(roster+unique_roster))
        challenges=[]
        if boss:challenges.append({"id":boss+"-1","title":"Defeat "+definitions[boss]["name"],"enemy":boss,"target":1})
        for target in (15,40):
            for kind in roster:
                if kind!=boss and kind not in unique_roster:challenges.append({"id":kind+"-"+str(target),"title":f"Defeat {target} {definitions[kind]['name']}","enemy":kind,"target":target})
        for kind in unique_roster:challenges.append({"id":kind+"-1","title":"Defeat "+definitions[kind]["name"],"enemy":kind,"target":1,"single_spawn":True})
        level=area["level"]
        arenas[area["id"]]={"title":f"Act {act} — {area['title']}","act":act,"original_level_id":area["level_id"],"terrain":terrains[family],"arena_width":3200,"arena_height":2400,"enemy_roster":roster,"enemy_definitions":{kind:definitions[kind] for kind in roster},"boss":boss,"challenges":challenges,"enemy":{"health":14+min(level,45)*1.5,"speed":62+min(level,45),"contact_damage":7+min(level,45)//5},"provenance":area}
        arenas[area["id"]]["unique_roster"]=unique_roster
    document.update(arenas=arenas,area_order=list(arenas),default_arena=next(iter(arenas)),final_arena=list(arenas)[-1],enemy_visuals=visuals,bestiary_version=VERSION)
    document["minion_visual"]=compositions["sk-1hs"]
    first=arenas[document["default_arena"]]
    document.update(title=first["title"],terrain=first["terrain"],enemy_visual=visuals[first["enemy_roster"][0]])
    from adapters.diablo2.environment import upgrade_environment
    upgrade_environment(assets,output,document,progress)
    document["configuration"].update(enemy_roster=first["enemy_roster"],enemy_definitions=definitions)
    document["bestiary"]={"version":VERSION,"monsters":definitions,"areas":areas,"uniques":uniques,"scope":"normal population, versioned Act V authored rosters, act bosses and mapped named uniques; no original dungeon generation or special AI","counts":{"monsters":len(definitions),"areas":len(areas),"compositions":len(compositions),"named_uniques":len(uniques)}}
    atomic_json(output/"bestiary.json",document["bestiary"])
    with sqlite3.connect(output/"assets.sqlite3") as database:
        database.execute("CREATE TABLE IF NOT EXISTS assets (source_path TEXT PRIMARY KEY,archive_path TEXT,raw_path TEXT,payload_sha256 TEXT,type TEXT,metadata_json TEXT)")
        for name,entry in assets.used.items():
            database.execute("INSERT OR REPLACE INTO assets VALUES (?,?,?,?,?,?)",(name,entry["archive"],entry["raw_path"],entry["sha256"],"metadata" if name.endswith((".txt",".tbl")) else "sprite",json.dumps({k:v for k,v in entry.items() if k not in ("raw_path","sha256")})))
        database.execute("CREATE TABLE IF NOT EXISTS bestiary_monsters (id TEXT PRIMARY KEY,name TEXT,metadata_json TEXT)")
        database.execute("CREATE TABLE IF NOT EXISTS bestiary_areas (id TEXT PRIMARY KEY,title TEXT,act INTEGER,metadata_json TEXT)")
        for kind,definition in definitions.items():database.execute("INSERT OR REPLACE INTO bestiary_monsters VALUES (?,?,?)",(kind,definition["name"],json.dumps(definition)))
        for area in areas:database.execute("INSERT OR REPLACE INTO bestiary_areas VALUES (?,?,?,?)",(area["id"],area["title"],area["act"],json.dumps(area)))
