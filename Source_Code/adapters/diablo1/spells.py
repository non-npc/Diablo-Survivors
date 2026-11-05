"""Original D1 Firebolt sprite cache. No original pixels are distributed."""
import hashlib,json,sqlite3
from pathlib import Path
from PIL import Image
from inspector.services.recognition import sprite_groups,frame_layout,palette_image

def build_spells(database,output):
    with sqlite3.connect(database) as db:
        entries={n.replace('\\','/').lower():(Path(p),sha) for n,p,sha in db.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE raw_path IS NOT NULL")}
    sources=[f'missiles/fireba{1+2*d}.cl2' for d in range(8)];palette_name='levels/l1data/l1_1.pal'
    key=hashlib.sha256(json.dumps({n:entries[n][1] for n in sources+[palette_name]},sort_keys=True).encode()).hexdigest()[:16]
    output=Path(output)/key;output.mkdir(parents=True,exist_ok=True)
    palette=entries[palette_name][0].read_bytes();decoded=[]
    for source in sources:
        data=entries[source][0].read_bytes();groups=sprite_groups(data)
        frames=[]
        for start,end in groups[0]:
            w,h,indices,alpha=frame_layout(data[start:end],'CL2',96)
            frames.append(palette_image(indices,alpha,w,h,palette))
        decoded.append(frames)
    height=max(im.height for frames in decoded for im in frames);count=max(len(frames) for frames in decoded)
    atlas=Image.new('RGBA',(96*count,height*8))
    for d,frames in enumerate(decoded):
        for n,image in enumerate(frames):atlas.alpha_composite(image,(n*96,d*height+height-image.height))
    path=output/'firebolt.png';atlas.save(path)
    return {'firebolt':{'clips':{'idle':{'sheet':str(path.resolve()),'frame_width':96,'frame_height':height,'anchor':[48,height-16],'frames_per_direction':[len(frames) for frames in decoded],'frame_seconds':0.05,'loop':True,'rotate_to_velocity':True,'forward_row':6}},'provenance':{'source_paths':sources,'format_reference':'https://github.com/diasurgical/devilution/blob/master/Source/misdat.cpp'}}}
