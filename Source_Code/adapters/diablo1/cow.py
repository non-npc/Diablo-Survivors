"""Read the locally cached town cow animation for an original cow-hunt event."""
import hashlib,json,sqlite3
from pathlib import Path
from PIL import Image
from inspector.services.recognition import sprite_groups,frame_layout,palette_image

def build_cow(database,folder):
    with sqlite3.connect(database) as connection:
        rows={n.replace("\\","/"):(Path(p),h) for n,p,h in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    names=["towners/animals/cow.cel","levels/towndata/town.pal"]
    if any(n not in rows for n in names):raise ValueError("Cow animation missing; refresh Inspector")
    key=hashlib.sha256(json.dumps({n:rows[n][1] for n in names},sort_keys=True).encode()).hexdigest()[:16]
    target=Path(folder)/key;meta=target/"cow.json"
    if meta.is_file():return json.loads(meta.read_text(encoding="utf-8"))
    target.mkdir(parents=True,exist_ok=True)
    data=rows[names[0]][0].read_bytes();palette=rows[names[1]][0].read_bytes();groups=sprite_groups(data)
    if len(groups)!=8:raise ValueError("Expected eight cow directions")
    sheet=Image.new("RGBA",(max(map(len,groups))*128,len(groups)*128))
    for direction,group in enumerate(groups):
        for frame,(start,end) in enumerate(group):
            w,h,indices,alpha=frame_layout(data[start:end],"CEL",128)
            if w!=128 or h!=128:raise ValueError("Unexpected cow frame size")
            sheet.alpha_composite(palette_image(indices,alpha,w,h,palette),(frame*128,direction*128))
    path=target/"cow-walk.png";sheet.save(path)
    clip={"sheet":str(path.resolve()),"frame_width":128,"frame_height":128,"frames_per_direction":list(map(len,groups)),"frame_seconds":0.1,"loop":True}
    result={"clips":{"walk":clip,"idle":clip},"source_files":names}
    meta.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result
