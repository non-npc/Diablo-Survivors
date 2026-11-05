"""Decode original local hit/splatter sprites into a bounded runtime atlas cache."""
import hashlib,json,sqlite3
from pathlib import Path
from PIL import Image,ImageFilter
from inspector.services.recognition import sprite_groups,frame_layout,palette_image
FILES={"blood":{"idle":("blood1",96),"walk":("blood3",128)},"bone":{"idle":("bone1",128),"walk":("bone2",128)},"metal":{"idle":("metlhit1",96),"walk":("blood3",128)}}
FILES["aura"]={"idle":("objects/vapor1.cel",128),"walk":("objects/vapor1.cel",128)}
def source_path(name):return name if "/" in name else "missiles/"+name+".cl2"

def build_effects(database,folder):
    with sqlite3.connect(database) as c:
        entries={n.replace("\\","/"):(Path(p),sha) for n,p,sha in c.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
    palette_name="levels/l1data/l1_1.pal"
    names=sorted({source_path(name) for clips in FILES.values() for name,width in clips.values()})+[palette_name]
    if any(n not in entries for n in names):raise ValueError("Missing cached original impact effect")
    key=hashlib.sha256(json.dumps({"decoder":"impact-effects-3","inputs":{n:entries[n][1] for n in names}},sort_keys=True).encode()).hexdigest()[:16]
    target=Path(folder)/key;meta=target/"effects.json"
    if meta.is_file():return json.loads(meta.read_text())
    target.mkdir(parents=True,exist_ok=True);palette=entries[palette_name][0].read_bytes();result={};cache={}
    for kind,clips in FILES.items():
        result[kind]={"clips":{}}
        for state,(name,width) in clips.items():
            source=source_path(name)
            if name not in cache:
                data=entries[source][0].read_bytes();groups=sprite_groups(data)
                if len(groups)!=1:raise ValueError("Unexpected impact directions")
                frames=[]
                for begin,end in groups[0]:
                    w,h,indices,alpha=frame_layout(data[begin:end],"CEL" if source.endswith(".cel") else "CL2",width)
                    image=palette_image(indices,alpha,w,h,palette)
                    if kind=="aura":
                        # Vapor luminance becomes density, never dark color: thin edges fade away.
                        density=[]
                        for index,coverage in zip(indices,alpha):
                            shade=palette[index*3]*0.299+palette[index*3+1]*0.587+palette[index*3+2]*0.114
                            density.append(int(coverage*max(0.0,min(1.0,(shade-12)/160))))
                        mask=Image.frombytes("L",(w,h),bytes(density)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                        image=Image.new("RGBA",(w,h),(245,248,255,0))
                        image.putalpha(mask.filter(ImageFilter.GaussianBlur(1.0)))
                    frames.append(image)
                height=max(im.height for im in frames);sheet=Image.new("RGBA",(width*len(frames),height))
                for i,image in enumerate(frames):sheet.alpha_composite(image,(i*width,height-image.height))
                path=target/(Path(name).stem+".png");sheet.save(path)
                cache[name]={"sheet":str(path.resolve()),"frame_width":width,"frame_height":height,"frames_per_direction":[len(frames)],"frame_seconds":0.045 if state=="idle" else 0.065,"loop":False,"source_path":source}
            result[kind]["clips"][state]=cache[name]
    meta.write_text(json.dumps(result,indent=2)+"\n");return result
