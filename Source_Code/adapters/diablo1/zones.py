"""Cached survival layouts using local Diablo tiles; no game assets shipped."""
import hashlib,json,math,random,sqlite3
from pathlib import Path
from PIL import Image
from adapters.diablo1.terrain import TerrainSet
from adapters.diablo1.town import read_sector,component

from manager.services.paths import ROOT
CATALOG=ROOT/"runtime/resources/zones.json"
def zone_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))

SCENERY={
    1:{"obstacles":(70,71),"boundaries":(17,18,22,23),"floors":(12,66,67,68,69,72,75,76)},
    2:{"obstacles":(13,14,15,16,17),"boundaries":(9,10,11,12),"floors":(2,58,59,60,61,62,63,64,65,66,75)},
    3:{"obstacles":(85,88,89,91,94,95,96,97,98,99),"boundaries":(23,110,129,130),"floors":(6,65,105,106,107)},
    4:{"obstacles":(17,18,20,21,22,23,24,25,26,27,28,34,43),"boundaries":(17,18,20,21,22,23,24),"floors":(5,30,48,49,50)}
}

def generated_tiles(terrain,seed,width=28,tileset=1):
    rng=random.Random(seed);scenery=SCENERY[tileset]
    solid={i for i,refs in enumerate(terrain.tiles) if all(terrain.properties[p]&1 for p in refs)}
    open_tiles={i for i,refs in enumerate(terrain.tiles) if all(not terrain.properties[p]&1 for p in refs)}
    if any(index not in solid for index in scenery["obstacles"]+scenery["boundaries"]):raise ValueError("Scenery must use verified solid tiles")
    if any(index not in open_tiles for index in scenery["floors"]):raise ValueError("Floor variations must remain walkable")
    floor=scenery["floors"][0]
    cells=[floor]*(width*width)
    for y in range(width):
        for x in range(width):
            if x in (0,width-1) or y in (0,width-1):cells[y*width+x]=rng.choice(scenery["boundaries"])
            elif rng.random()<0.25:cells[y*width+x]=rng.choice(scenery["floors"])
    # Alternate props, jitter their anchors, and preserve wide lanes between them.
    index=seed%len(scenery["obstacles"])
    for y in range(5,width-4,5):
        for x in range(5,width-4,5):
            if rng.random()>0.85:continue
            px=x+rng.randint(-1,1);py=y+rng.randint(-1,1)
            cells[py*width+px]=scenery["obstacles"][index%len(scenery["obstacles"])]
            index+=1
    return width,width,cells

def build_zones(database,folder,progress=lambda message:None):
    with sqlite3.connect(database) as connection:
        entries={n.replace("\\","/"):(Path(p),sha) for n,p,sha in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    result={};sets={}
    queue=[zone for zone in zone_catalog() if zone["tileset"]!=0]
    for position,zone in enumerate(queue,1):
        progress(f"[{position}/{len(queue)}] Area: "+zone["title"])
        t=zone["tileset"];base=f"levels/l{t}data/l{t}"
        palette=zone.get("palette",base+("_1.pal" if t==4 else ".pal"))
        names=[base+"."+ext for ext in ("cel","min","til","sol")]+[palette]
        if zone.get("quest_map"):names.append(zone["quest_map"])
        if any(n not in entries for n in names):raise ValueError("Missing zone source: "+zone["id"])
        identity={"decoder":"survival-zones-6","zone":zone,"inputs":{n:entries[n][1] for n in names}}
        key=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()[:16]
        target=Path(folder)/zone["id"]/key;meta=target/"map.json"
        if meta.is_file():result[zone["id"]]=json.loads(meta.read_text());continue
        set_key=(t,palette)
        if set_key not in sets:
            inputs=[entries[n][0].read_bytes() for n in names[:5]]
            blocks=len(inputs[1])//len(inputs[3])//2
            terrain=TerrainSet(*inputs,blocks=blocks)
            decoded=[];bounds=[];columns=64
            atlas=Image.new("RGBA",(columns*64,math.ceil(len(terrain.pieces)/columns)*256))
            for i in range(len(terrain.pieces)):
                image=Image.new("RGBA",(64,256));piece=terrain.piece(i)
                image.alpha_composite(piece,(0,256-piece.height));decoded.append(image)
                atlas.alpha_composite(image,(i%columns*64,i//columns*256))
                rect=image.crop((0,0,64,224)).getchannel("A").getbbox();bounds.append(list(rect) if rect else [])
            shared=Path(folder)/"tilesets"/hashlib.sha256(json.dumps(identity["inputs"],sort_keys=True).encode()).hexdigest()[:16]
            shared.mkdir(parents=True,exist_ok=True);atlas_path=shared/"pieces.png";atlas.save(atlas_path)
            sets[set_key]=(terrain,decoded,bounds,atlas_path)
        terrain,decoded,bounds,atlas_path=sets[set_key]
        if zone.get("quest_map"):
            width,height,values=read_sector(entries[zone["quest_map"]][0].read_bytes(),len(terrain.tiles))
            fill={1:12,2:2,3:6,4:5}[t]
            cells=[value-1 if value else fill for value in values]
        else:width,height,cells=generated_tiles(terrain,20261012+zone.get("floor",0),tileset=t)
        # Square padded grid shares the existing isometric collision/navigation pipeline.
        size=max(width,height)*2+4
        padding=next(i for i,flags in enumerate(terrain.properties) if flags&1)
        grid=[padding]*(size*size)
        for y in range(height):
            for x in range(width):
                for slot,ref in enumerate(terrain.tiles[cells[y*width+x]]):
                    grid[(y*2+2+slot//2)*size+x*2+2+slot%2]=ref
        connected=component(grid,terrain.properties,size)
        # Restrict empty padding regardless of SOL flag on piece zero.
        connected={i for i in connected if 2<=i%size<width*2+2 and 2<=i//size<height*2+2}
        if len(connected)<100:raise ValueError("Zone has insufficient walkable area: "+zone["id"])
        target.mkdir(parents=True,exist_ok=True)
        origin=[size*32,256];canvas_size=(size*64,size*32+512)
        floor=Image.new("RGBA",canvas_size)
        for i in sorted(range(len(grid)),key=lambda i:i%size+i//size):
            x,y=i%size,i//size
            if not zone.get("quest_map") and 2<=x<width*2+2 and 2<=y<height*2+2:
                # Solid scenery may omit its own ground; keep intact floor underneath.
                base_refs=terrain.tiles[SCENERY[t]["floors"][0]]
                base_piece=base_refs[(y%2)*2+x%2]
                floor.alpha_composite(decoded[base_piece].crop((0,192,64,256)),((x-y)*32+origin[0]-32,(x+y)*16+origin[1]-48))
            floor.alpha_composite(decoded[grid[i]].crop((0,224,64,256)),((x-y)*32+origin[0]-32,(x+y)*16+origin[1]-16))
        floor_path=target/"floor.png";floor.save(floor_path)
        spawn=min(connected,key=lambda i:(i%size-size/2)**2+(i//size-size/2)**2)
        doc={"schema_version":1,"name":zone["title"],"atlas":str(atlas_path.resolve()),"floor_texture":str(floor_path.resolve()),"upper_bounds":bounds,"columns":64,"piece_width":64,"piece_height":256,"grid_width":size,"grid_height":size,"pieces":grid,"walkable":[int(i in connected) for i in range(size*size)],"missile_blocked":[int(i not in connected or terrain.properties[p]&4!=0) for i,p in enumerate(grid)],"origin":origin,"spawn_cell":[spawn%size,spawn//size],"arena_width":canvas_size[0],"arena_height":canvas_size[1],"provenance":{"archive":"DIABDAT.MPQ","source_files":names,"layout":"original quest DUN base tile layer; quest objects omitted" if zone.get("quest_map") else "authored deterministic survival layout; original dungeon generator not reproduced"},"statistics":{"connected_walkable_cells":len(connected),**terrain.summary()}}
        meta.write_text(json.dumps(doc,indent=2)+"\n",encoding="utf-8");result[zone["id"]]=doc
    return result
