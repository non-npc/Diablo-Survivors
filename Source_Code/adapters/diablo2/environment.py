"""Area-specific terrain selection and standalone scenery from installed D2 assets."""
import random
import struct
from pathlib import Path
from PIL import Image, ImageFilter, ImageOps, ImageStat
from adapters.diablo2.formats import rgba,decode_dcc

VERSION = 1

def base_tiles(data, tiles):
    """Keep one compatible DT1 material, excluding border/decorative subtiles."""
    pointer=struct.unpack_from('<I',data,272)[0]
    groups={}
    for index,image in tiles:
        main,sub,rarity=struct.unpack_from('<III',data,pointer+index*96+24)
        groups.setdefault((main,sub),[]).append((index,image))
    candidates=[(key,group) for key,group in groups.items() if key[1]==0]
    if not candidates:candidates=list(groups.items())
    # Repeated records with identical material keys are the original interchangeable variants.
    key,group=max(candidates,key=lambda item:(len(item[1]),-item[0][0]))
    return group

def continuous_ground(tiles,palette):
    """Bake a seamless natural surface from quiet original ground patches."""
    patches=[rgba(im,palette).crop((40,20,120,60)).convert('RGB') for _,im in tiles]
    patches=sorted(patches,key=lambda im:sum(ImageStat.Stat(im).var))[:12]
    rng=random.Random(3841)
    half=Image.new('RGB',(1600,1200))
    base=patches[0]
    for y in range(0,1200,40):
        for x in range(0,1600,80):
            patch=ImageOps.mirror(base) if (x//80)%2 else base
            if (y//40)%2:patch=ImageOps.flip(patch)
            half.paste(patch,(x,y))
    mask=Image.new('L',(80,40),0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rectangle((12,8,67,31),fill=190)
    mask=mask.filter(ImageFilter.GaussianBlur(8))
    for y in range(-20,1220,20):
        for x in range(-40,1640,40):
            patch=rng.choice(patches)
            if rng.randrange(2):patch=ImageOps.mirror(patch)
            half.paste(patch,(x+rng.randrange(-12,13),y+rng.randrange(-6,7)),mask)
    # Mirrored boundaries meet exactly, including at the wrapping map edges.
    result=Image.new('RGB',(3200,2400))
    result.paste(half,(0,0));result.paste(ImageOps.mirror(half),(1600,0))
    result.paste(ImageOps.flip(result.crop((0,0,3200,1200))),(0,1200))
    return result

def standalone_tiles(data):
    """Decode only standalone roof-layer scenery from explicitly approved prop sets.

    Orientation 13 contains split shadows/ground pieces and must never become props.
    """
    if len(data)<276 or struct.unpack_from('<II',data)!=(7,6):raise ValueError('Unsupported scenery DT1')
    count,pointer=struct.unpack_from('<II',data,268)
    if count>10000 or pointer+count*96>len(data):raise ValueError('Invalid scenery tile table')
    result=[]
    for index in range(count):
        off=pointer+index*96
        if struct.unpack_from('<I',data,off+20)[0]!=14:continue
        blocks,_,count_blocks=struct.unpack_from('<III',data,off+72)
        if count_blocks>4096 or blocks+count_blocks*20>len(data):raise ValueError('Invalid scenery block table')
        decoded=[]
        for b in range(count_blocks):
            bo=blocks+b*20;x,y=struct.unpack_from('<hh',data,bo)
            fmt=struct.unpack_from('<H',data,bo+8)[0];length=struct.unpack_from('<I',data,bo+10)[0]
            cursor=blocks+struct.unpack_from('<I',data,bo+16)[0];end=cursor+length
            if end>len(data):raise ValueError('Scenery block outside DT1')
            if fmt==1:
                jumps=(14,12,10,8,6,4,2,0,2,4,6,8,10,12,14)
                lengths=(4,8,12,16,20,24,28,32,28,24,20,16,12,8,4)
                for row,(jump,run) in enumerate(zip(jumps,lengths)):
                    decoded.append((x+jump,y+row,data[cursor:cursor+run]));cursor+=run
            else:
                row=col=0
                while cursor<end:
                    if cursor+2>end:raise ValueError('Truncated scenery block')
                    skip,run=data[cursor:cursor+2];cursor+=2
                    if skip==run==0:row+=1;col=0;continue
                    col+=skip
                    if cursor+run>end:raise ValueError('Truncated scenery run')
                    decoded.append((x+col,y+row,data[cursor:cursor+run]));cursor+=run;col+=run
        if not decoded:continue
        left=min(x for x,y,p in decoded);right=max(x+len(p) for x,y,p in decoded)
        top=min(y for x,y,p in decoded);bottom=max(y+1 for x,y,p in decoded)
        if right-left>1024 or bottom-top>1024:raise ValueError('Scenery exceeds size limit')
        image=Image.new('P',(right-left,bottom-top))
        for x,y,pixels in decoded:image.paste(Image.frombytes('P',(len(pixels),1),pixels),(x-left,y-top))
        result.append((index,image,[-left+80,-top]))
    return result

PROP_SOURCES={
    1:[],
    2:['act2/outdoors/palm.dt1','act2/outdoors/rocks.dt1','act2/outdoors/prickly.dt1'],
    3:['act3/jungle/trees.dt1'],
    4:['act4/lava/rocks.dt1'],
    5:[],
}

def prepare_scenery(assets,output,act):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    palette=assets.read(f'data/global/palette/act{act}/pal.dat')
    result=ds1_tree_props(assets,output,palette) if act==1 else []
    for source in PROP_SOURCES[act]:
        path='data/global/tiles/'+source
        if not assets.present(path):continue
        for index,image,anchor in standalone_tiles(assets.read(path)):
            if source=='act3/jungle/trees.dt1' and index not in (70,71,77,86):continue
            rgba_image=rgba(image,palette)
            destination=output/(source.replace('/','-')+f'-{index}.png')
            rgba_image.save(destination)
            result.append({'texture':str(destination),'anchor':anchor,'scale':0.7,'source_path':path,'source_tile':index})
    # This is the original loose-rock object, not a wall or a floor fragment.
    rock='data/global/objects/ry/tr/rytrlitnuhth.dcc'
    if assets.present(rock):
        frames,origin=decode_dcc(assets.read(rock),0)
        image=rgba(frames[0],palette)
        destination=output/'loose-rock.png';image.save(destination)
        result.append({'texture':str(destination),'anchor':[-origin[0],-origin[1]],'scale':0.8,'source_path':rock})
    return result


def upgrade_environment(assets,output,document,progress=lambda message:None):
    from adapters.diablo2.importer import terrain
    terrains={};props={}
    for area in document['arenas'].values():
        original=area['terrain'];source=original['source_path'];act=int(area.get('act',1))
        level=int(area.get('original_level_id',0))
        if act==4 and level in (104,105,106):source='data/global/tiles/act4/mesa/floor.dt1'
        if act==4 and level==107:source='data/global/tiles/act4/lava/floor.dt1'
        key=(source,act)
        if key not in terrains:
            progress('Preparing cohesive terrain: '+source)
            terrains[key]=terrain(assets,Path(output)/'terrain'/('cohesive-'+str(act)+'-'+source.replace('/','-').replace('.dt1','')+'.png'),source,'act'+str(act))
        area['terrain']=terrains[key]
        outdoors='/outdoors/' in source or '/ground/' in source or '/siege/' in source or (act==4 and level in (104,105,106,107))
        if outdoors:
            if act not in props:props[act]=prepare_scenery(assets,Path(output)/'scenery'/('act'+str(act)),act)
            area['scenery']=props[act]
        else:area.pop('scenery',None)
    first=document['arenas'][document['default_arena']]
    document['terrain']=first['terrain']
    document['environment_version']=VERSION
def ds1_tree_props(assets,output,palette):
    """Assemble tree pieces using their original small DS1 scenery layout."""
    path='data/global/tiles/act1/outdoors/trees.ds1'
    data=assets.read(path);version,w,h=struct.unpack_from('<III',data);w+=1;h+=1
    if not 8<=version<=18 or w*h>65536:raise ValueError('Unsupported scenery layout')
    cursor=16 # version, dimensions, act
    if version>=10:cursor+=4
    files=struct.unpack_from('<I',data,cursor)[0];cursor+=4;names=[]
    for _ in range(files):
        end=data.index(b'\0',cursor);name=data[cursor:end].decode('cp1252').replace('\\','/').lower();cursor=end+1
        name='data/'+name.split('/data/',1)[-1];names.append(name.replace('.tg1','.dt1'))
    if 9<=version<=13:cursor+=8
    walls=struct.unpack_from('<I',data,cursor)[0];cursor+=4
    if version>=16:cursor+=4 # floor layer count; not needed for roof scenery
    tile_lookup={}
    for name in names:
        if not assets.present(name):continue
        raw=assets.read(name);pointer=struct.unpack_from('<I',raw,272)[0]
        for index,image,anchor in standalone_tiles(raw):
            main,sub=struct.unpack_from('<II',raw,pointer+index*96+24)
            tile_lookup[(main,sub)]=(rgba(image,palette),anchor)
    cells={}
    for layer in range(walls):
        values=struct.unpack_from('<'+'I'*(w*h),data,cursor);cursor+=w*h*4
        orientations=struct.unpack_from('<'+'I'*(w*h),data,cursor);cursor+=w*h*4
        for i,value in enumerate(values):
            key=((value>>20)&63,(value>>8)&255)
            if value and orientations[i]==14 and key in tile_lookup:cells[(i%w,i//w)]=tile_lookup[key]
    components=[]
    while cells:
        first=next(iter(cells));pending=[first];group=[]
        while pending:
            key=pending.pop()
            if key not in cells:continue
            group.append((key,cells.pop(key)))
            x,y=key
            pending.extend((x+dx,y+dy) for dx in (-1,0,1) for dy in (-1,0,1) if dx or dy)
        components.append(group)
    result=[]
    for n,group in enumerate(components):
        pieces=[]
        for (x,y),(image,anchor) in group:
            pieces.append(((x-y)*80-anchor[0],(x+y)*40-anchor[1],image))
        left=min(x for x,y,im in pieces);top=min(y for x,y,im in pieces)
        right=max(x+im.width for x,y,im in pieces);bottom=max(y+im.height for x,y,im in pieces)
        image=Image.new('RGBA',(right-left,bottom-top))
        for x,y,im in sorted(pieces,key=lambda p:p[1]+p[2].height):image.alpha_composite(im,(x-left,y-top))
        destination=Path(output)/f'assembled-tree-{n}.png';image.save(destination)
        result.append({'texture':str(destination),'anchor':[image.width/2,image.height],'scale':0.7,'source_path':path,'assembled_tiles':len(group)})
    return result
