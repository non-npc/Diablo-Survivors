"""Reconstruct local Diablo town sectors; never embeds source maps or pixels."""
import hashlib,json,math,sqlite3,struct
from collections import deque
from pathlib import Path
from PIL import Image
from adapters.diablo1.terrain import TerrainSet
SECTORS=(("sector1s.dun",46,46),("sector2s.dun",46,0),("sector3s.dun",0,46),("sector4s.dun",0,0))

def read_sector(data,tile_count):
    if len(data)<4:raise ValueError("Truncated town sector")
    width,height=struct.unpack_from("<HH",data)
    if not 1<=width<=48 or not 1<=height<=48 or len(data)<4+width*height*2:raise ValueError("Invalid sector size")
    cells=list(struct.unpack_from("<"+"H"*(width*height),data,4))
    if any(value>tile_count for value in cells):raise ValueError("Sector tile reference out of bounds")
    return width,height,cells

def assemble(tiles,sectors,size=96):
    grid=[218]*(size*size)
    for data,ox,oy in sectors:
        width,height,cells=read_sector(data,len(tiles))
        if ox+width*2>size or oy+height*2>size:raise ValueError("Sector exceeds town bounds")
        for y in range(height):
            for x in range(width):
                value=cells[y*width+x]
                refs=tiles[value-1] if value else (218,)*4
                for slot,ref in enumerate(refs):grid[(oy+y*2+slot//2)*size+ox+x*2+slot%2]=ref
    return grid

def component(grid,properties,size):
    remaining={i for i,piece in enumerate(grid) if 0<i%size<size-1 and 0<i//size<size-1 and not properties[piece]&1}
    largest=set()
    while remaining:
        first=remaining.pop();found={first};queue=deque([first])
        while queue:
            index=queue.popleft();x,y=index%size,index//size
            for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                neighbor=ny*size+nx
                if 0<=nx<size and 0<=ny<size and neighbor in remaining:
                    remaining.remove(neighbor);found.add(neighbor);queue.append(neighbor)
        if len(found)>len(largest):largest=found
    if not largest:raise ValueError("Town has no connected walkable area")
    return largest

def build_town(database,folder):
    with sqlite3.connect(database) as connection:
        entries={name.replace("\\","/"): (Path(raw),sha) for name,raw,sha in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    names=["levels/towndata/town."+ext for ext in ("cel","min","til","sol","pal")]+["levels/towndata/"+name for name,_,_ in SECTORS]
    if any(name not in entries for name in names):raise ValueError("Refresh Inspector: town resources are missing")
    key=hashlib.sha256(json.dumps({"decoder":"tristram-2","inputs":{n:entries[n][1] for n in names}},sort_keys=True).encode()).hexdigest()[:16]
    target=Path(folder)/key;meta=target/"map.json"
    if meta.is_file():return json.loads(meta.read_text(encoding="utf-8"))
    target.mkdir(parents=True,exist_ok=True)
    terrain=TerrainSet(*(entries[n][0].read_bytes() for n in names[:5]),blocks=16)
    grid=assemble(terrain.tiles,[(entries["levels/towndata/"+name][0].read_bytes(),x,y) for name,x,y in SECTORS])
    connected=component(grid,terrain.properties,96)
    columns=64;atlas=Image.new("RGBA",(columns*64,math.ceil(len(terrain.pieces)/columns)*256))
    upper_bounds=[]
    decoded=[]
    for i in range(len(terrain.pieces)):
        image=terrain.piece(i);decoded.append(image)
        atlas.alpha_composite(image,(i%columns*64,i//columns*256))
        bounds=image.crop((0,0,64,224)).getchannel("A").getbbox()
        upper_bounds.append(list(bounds) if bounds else [])
    atlas_path=target/"town-pieces.png";atlas.save(atlas_path)
    floor=Image.new("RGBA",(6144,3584))
    for i in sorted(range(len(grid)),key=lambda i:i%96+i//96):
        x,y=i%96,i//96
        floor.alpha_composite(decoded[grid[i]].crop((0,224,64,256)),((x-y)*32+3072-32,(x+y)*16+256-16))
    floor_path=target/"town-floor.png";floor.save(floor_path)
    # Choose an open cell near the classic town arrival area.
    spawn=min(connected,key=lambda i:(i%96-75)**2+(i//96-68)**2)
    result={"schema_version":1,"name":"Tristram","atlas":str(atlas_path.resolve()),"floor_texture":str(floor_path.resolve()),"upper_bounds":upper_bounds,"columns":columns,"piece_width":64,"piece_height":256,"grid_width":96,"grid_height":96,"pieces":grid,"walkable":[1 if i in connected else 0 for i in range(96*96)],"missile_blocked":[1 if terrain.properties[p]&4 or i not in connected else 0 for i,p in enumerate(grid)],"origin":[3072,256],"spawn_cell":[spawn%96,spawn//96],"provenance":{"archive":"DIABDAT.MPQ","source_files":names,"sector_offsets":[[n,x,y] for n,x,y in SECTORS],"tile_ids":"DUN one-based; TIL/MIN zero-based","variant":"base Diablo sectors; quest/warp state overrides and NPCs omitted"},"statistics":{**terrain.summary(),"connected_walkable_cells":len(connected)}}
    meta.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    preview=Image.new("RGBA",(6144,3584),(12,18,16,255))
    for i in sorted(range(len(grid)),key=lambda i:i%96+i//96):
        x,y=i%96,i//96
        preview.alpha_composite(terrain.piece(grid[i]),((x-y)*32+3072-32,(x+y)*16+256-240))
    preview.thumbnail((1536,896));preview.save(target/"town-overview.png")
    return result
