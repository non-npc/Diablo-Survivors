"""Normalize locally owned classic UI art with verified frame widths."""
import hashlib,json,sqlite3
from pathlib import Path
from PIL import Image
from inspector.services.recognition import sprite_groups,frame_layout,palette_image

def build_ui(database,folder):
    names=["data/char.cel","ctrlpan/spelicon.cel","levels/towndata/town.pal"]
    with sqlite3.connect(database) as c:
        entries={n.replace("\\","/"):(Path(p),h) for n,p,h in c.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    if any(n not in entries for n in names):raise ValueError("Character UI resources missing from cache")
    key=hashlib.sha256(json.dumps({n:entries[n][1] for n in names},sort_keys=True).encode()).hexdigest()[:16]
    target=Path(folder)/key;meta=target/"ui.json"
    if meta.is_file():return json.loads(meta.read_text(encoding="utf-8"))
    target.mkdir(parents=True,exist_ok=True)
    palette=entries[names[-1]][0].read_bytes();result={"source_files":names}
    for name,width,key in [(names[0],320,"character_panel"),(names[1],56,"spell_icons")]:
        data=entries[name][0].read_bytes();frames=sprite_groups(data)[0];images=[]
        for begin,end in frames:
            w,h,pixels,alpha=frame_layout(data[begin:end],"CEL",width)
            images.append(palette_image(pixels,alpha,w,h,palette))
        height=max(im.height for im in images)
        atlas=Image.new("RGBA",(width*len(images),height))
        for i,image in enumerate(images):atlas.alpha_composite(image,(i*width,height-image.height))
        path=target/(key+".png");atlas.save(path)
        result[key]={"texture":str(path.resolve()),"width":width,"height":height,"frames":len(images)}
    meta.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result
