"""Original D2 spell animations, decoded only from the user's installed archives."""
import struct
from pathlib import Path
from PIL import Image
from adapters.diablo2.formats import decode_dcc, dcc_direction, rgba
VERSION=2
SOURCES={'firebolt':'firebolt','bonespear':'bonespear','firestorm':'groundfiresmall'}

def build_spells(assets,output):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    palette=assets.read('data/global/palette/act1/pal.dat')
    result={}
    for kind,name in SOURCES.items():
        if kind=="firestorm" and not assets.identity.get("expansion",False):continue
        source=f'data/global/missiles/{name}.dcc';data=assets.read(source)
        # Moving missiles use the native east-facing frame and rotate to screen velocity.
        moving=kind in ('firebolt','bonespear')
        directions=1 if moving or data[2]==1 else 8
        decoded=[decode_dcc(data,7 if moving else dcc_direction(data[2],d)) for d in range(directions)]
        left=min(origin[0] for frames,origin in decoded);top=min(origin[1] for frames,origin in decoded)
        right=max(origin[0]+frames[0].width for frames,origin in decoded);bottom=max(origin[1]+frames[0].height for frames,origin in decoded)
        width=right-left;height=bottom-top;count=struct.unpack_from('<I',data,3)[0]
        columns=min(count,max(1,4096//width));rows=(count+columns-1)//columns
        if width*columns>8192 or height*rows*directions>8192:raise ValueError('Spell atlas exceeds texture limit')
        atlas=Image.new('RGBA',(width*columns,height*rows*directions))
        for d,(frames,origin) in enumerate(decoded):
            for n,frame in enumerate(frames):atlas.alpha_composite(rgba(frame,palette),((n%columns)*width+origin[0]-left,(d*rows+n//columns)*height+origin[1]-top))
        path=output/(kind+'.png');atlas.save(path)
        result[kind]={'clips':{'idle':{'sheet':str(path),'frame_width':width,'frame_height':height,'frame_columns':columns,'anchor':[-left,-top] if kind=='firestorm' else [width/2,height/2],'frames_per_direction':[count]*directions,'frame_seconds':0.04 if kind=='firestorm' else 0.06,'loop':kind!='firestorm','source_path':source,'rotate_to_velocity':moving,'additive':moving}},'provenance':{'source_path':source}}
    return result
