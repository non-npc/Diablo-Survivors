"""Build coded visual selection sheets from locally cached original assets."""
import json,math,sqlite3,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from adapters.diablo1.terrain import TerrainSet
from adapters.diablo1.zones import zone_catalog
from inspector.services.recognition import sprite_groups,frame_layout,palette_image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"level_props"
REGIONS=[("CAT","Cathedral",1), ("CTC","Catacombs",2), ("CAV","Caves",3), ("HEL","Hell",4), ("TWN","Tristram",0)]
def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",size)
def sheet(title,items,prefix):
    folder=OUT/prefix;folder.mkdir(parents=True,exist_ok=True)
    if not folder.resolve().is_relative_to(OUT.resolve()):raise ValueError("Invalid selection-sheet output path")
    for stale in folder.glob(prefix+"-*.png"):stale.unlink()
    pages=[];per_page=24;columns=min(6,max(1,len(items)));cell_w=220;cell_h=250
    for page,start in enumerate(range(0,len(items),per_page),1):
        subset=items[start:start+per_page];rows=math.ceil(len(subset)/columns)
        canvas=Image.new("RGB",(columns*cell_w+40,rows*cell_h+125),(20,25,31));draw=ImageDraw.Draw(canvas)
        draw.text((22,16),title+f" - page {page}",font=font(28),fill=(240,243,249))
        draw.text((22,58),"Original art. Choose by code." if columns<4 else "Choose by code. Original art; static previews. Scale may vary to fit.",font=font(17),fill=(166,181,201))
        for slot,(code,name,image,info) in enumerate(subset):
            x=20+slot%columns*cell_w;y=100+slot//columns*cell_h
            draw.rounded_rectangle((x+3,y+3,x+cell_w-6,y+cell_h-8),radius=8,fill=(55,62,70),outline=(66,77,92))
            draw.text((x+12,y+10),code,font=font(19),fill=(245,210,115))
            art=image.copy();art.thumbnail((196,174),Image.Resampling.NEAREST)
            canvas.paste(art,(x+(cell_w-art.width)//2,y+46+(174-art.height)//2),art)
            draw.text((x+12,y+220),name,font=font(14),fill=(204,214,227))
            info["sheet"]=f"{prefix}/{prefix}-{page:02}.png"
        path=folder/f"{prefix}-{page:02}.png";canvas.save(path);pages.append(str(path.relative_to(OUT)).replace("\\","/"))
    return pages

def main():
    state=json.loads((ROOT/".local/inspector/last_preparation.json").read_text())
    with sqlite3.connect(state["database_path"]) as connection:
        entries={name.replace("\\","/"):(Path(raw),sha) for name,raw,sha in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    OUT.mkdir(parents=True,exist_ok=True);index={"edition":"diablo1-gog-main","codes":{},"groups":[],"zones":zone_catalog()}
    prop_metadata=json.loads((ROOT/"catalogs/diablo1/prop_metadata.json").read_text(encoding="utf-8"))
    index["references"]=prop_metadata["references"]
    index["unverified_outdoor_categories"]=prop_metadata["unverified_outdoor_categories"]
    palette_name="levels/l1data/l1_1.pal";palette=entries[palette_name][0].read_bytes()
    def object_item(prefix,definition):
        name=definition["source_path"];frame=int(definition["frame"])
        raw=entries[name][0].read_bytes();group=sprite_groups(raw)[0]
        if frame>=len(group):raise ValueError("Object preview frame out of bounds: "+name)
        begin,end=group[frame]
        width,height,indices,alpha=frame_layout(raw[begin:end],"CEL",int(definition["width"]))
        image=palette_image(indices,alpha,width,height,palette)
        code=prefix+"-"+definition["stem"].upper()+(f"-{frame+1:02}" if frame else "")
        info={"kind":"object_sprite","classification":"standalone prop","name":definition["name"],"source_path":name,"source_sha256":entries[name][1],"frame":frame,"width":width,"palette":palette_name,"association":definition["association"],"references":prop_metadata["references"],"collision":"authored placement footprint required"}
        index["codes"][code]=info
        return code,definition["name"],image,info
    for prefix,title,region in REGIONS:
        region_items=[]
        if region in (0,1):
            base="levels/towndata/town" if region==0 else "levels/l1data/l1"
            names=[base+"."+ext for ext in ("cel","min","til","sol","pal")]
            data=[entries[name][0].read_bytes() for name in names]
            terrain=TerrainSet(*data,blocks=16 if region==0 else 10)
            choices=prop_metadata["town_nature"] if region==0 else [{"tile":70,"name":"Pillars"},{"tile":71,"name":"Pillars"}]
            for choice in choices:
                tile=int(choice["tile"]);code=f"{prefix}-{tile:03}"
                info={"kind":"terrain_prop","classification":"outdoor nature" if region==0 else "pillars","region":title,"tileset":region,"tile_index":tile,"source_files":names,"source_sha256":{n:entries[n][1] for n in names},"association":"visually verified intact town tree/rock artwork" if region==0 else "user-verified pillars","collision":"original SOL footprint"}
                index["codes"][code]=info;region_items.append((code,choice["name"],terrain.tile(tile),info))
        for definition in prop_metadata["regions"][prefix]:region_items.append(object_item(prefix,definition))
        pages=sheet(title+" original props",region_items,prefix)
        index["groups"].append({"name":title,"prefix":prefix,"pages":pages,"count":len(region_items),"zones":[z["id"] for z in index["zones"] if z["tileset"]==region]})
    shared_items=[object_item("OBJ",definition) for definition in prop_metadata["shared"]]
    pages=sheet("Shared dungeon props",shared_items,"OBJ")
    index["groups"].append({"name":"Shared dungeon props","prefix":"OBJ","pages":pages,"count":len(shared_items),"zones":"Original dungeon themes/ranges as recorded per entry; not Tristram"})
    (OUT/"selection-index.json").write_text(json.dumps(index,indent=2)+"\n")
    lines=["# Original object selection sheets","","Send codes exactly as printed, for example `CAT-070, CAT-071, OBJ-BARREL`.","","CAT: Cathedral; CTC: Catacombs; CAV: Caves; HEL: Hell; TWN: Tristram. Each regional sheet is filtered by original object placement/quest/theme evidence. Shared dungeon props have their own OBJ sheet. Caves have few separate props; rock formations built into walls are excluded. Outdoors shows intact Tristram trees and rocks. No standalone shrub/bush/flower sprites have been verified. CAT-070 and CAT-071 are your identified pillars.","","These are source-art previews, not approved placements. Original interactive objects would be decorative unless gameplay is added. The saved JSON links every code to its exact source and tile/frame.",""]
    for group in index["groups"]:
        lines.append("## "+group["name"])
        for page in group["pages"]:lines.append(f"![{page}]({page})")
    (OUT/"README.md").write_text("\n".join(lines)+"\n")
    print(json.dumps({"folder":str(OUT),"groups":[{"name":g["name"],"count":g["count"],"pages":g["pages"]} for g in index["groups"]]}))
if __name__=="__main__":main()
