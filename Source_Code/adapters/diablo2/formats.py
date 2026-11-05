"""Bounded DCC/DC6/COF decoding. DCC algorithm adapted from Diablerie (MIT).
See THIRD_PARTY_NOTICES.md. Original game bytes remain in the private cache.
"""
import struct
from PIL import Image
WIDTH_BITS=(0,1,2,4,6,8,10,12,14,16,20,24,26,28,30,32)
DIRECTIONS=(4,0,5,1,6,2,7,3)

def dcc_direction(direction_count, compass_direction):
    # Extra DCC directions are interleaved after the original eight, not evenly indexed.
    if direction_count not in (1,4,8,16,32) or not 0<=compass_direction<8:raise ValueError("Invalid directional mapping")
    return DIRECTIONS[compass_direction] if direction_count>=8 else compass_direction*direction_count//8

class Bits:
    def __init__(self,data,position=0,end=None):
        self.data=data;self.position=position;self.end=len(data)*8 if end is None else end
    def read(self,count):
        if count<0 or self.position+count>self.end:raise ValueError("Truncated DCC bit stream")
        if not count:return 0
        start=self.position//8;shift=self.position%8
        value=int.from_bytes(self.data[start:(self.position+count+7)//8],"little")>>shift
        self.position+=count
        return value&((1<<count)-1)
    def signed(self,count):
        value=self.read(count)
        return value-(1<<count) if count and value&(1<<(count-1)) else value
    def take(self,count):
        if self.position+count>self.end:raise ValueError("Invalid DCC stream size")
        stream=Bits(self.data,self.position,self.position+count);self.position+=count;return stream

def spans(size,first):
    if size-first<=1:return [size]
    result=[first];left=size-first
    while left>5:result.append(4);left-=4
    result.append(left);return result

def decode_dcc(data,direction):
    if len(data)<15 or data[0]!=0x74 or data[1]!=6:raise ValueError("Unsupported DCC header")
    directions=data[2];frames=struct.unpack_from("<I",data,3)[0]
    if directions not in (1,8,16,32) or not 1<=frames<=256 or direction>=directions:raise ValueError("Invalid DCC direction/frame count")
    if len(data)<15+directions*4:raise ValueError("Truncated DCC offsets")
    offset=struct.unpack_from("<I",data,15+direction*4)[0]
    stream=Bits(data,offset*8);stream.read(32);flags=stream.read(2)
    widths=[WIDTH_BITS[stream.read(4)] for _ in range(7)]
    headers=[];optional=0
    for _ in range(frames):
        stream.read(widths[0]);w=stream.read(widths[1]);h=stream.read(widths[2]);x=stream.signed(widths[3]);y=stream.signed(widths[4]);optional+=stream.read(widths[5]);stream.read(widths[6]);bottom=stream.read(1)
        if bottom:raise ValueError("Unsupported bottom-up DCC frame")
        if not 1<=w<=1024 or not 1<=h<=1024:raise ValueError("Invalid DCC dimensions")
        headers.append((x,y-h+1,w,h))
    left=min(f[0] for f in headers);top=min(f[1] for f in headers)
    width=max(f[0]+f[2] for f in headers)-left;height=max(f[1]+f[3] for f in headers)-top
    if width*height*frames>32_000_000:raise ValueError("DCC decoded size limit")
    stream.read(optional*8)
    eq_size=stream.read(20) if flags&2 else 0;mask_size=stream.read(20)
    enc_size=stream.read(20) if flags&1 else 0;raw_size=stream.read(20) if flags&1 else 0
    palette=[i for i in range(256) if stream.read(1)]
    if not palette:raise ValueError("Empty DCC palette")
    eq=stream.take(eq_size);mask=stream.take(mask_size);enc=stream.take(enc_size);raw=stream.take(raw_size);codes=stream
    bw=(width+3)//4;bh=(height+3)//4;cell_values=[None]*(bw*bh);entries=[];all_cells=[]
    for fi,(x,y,w,h) in enumerate(headers):
        dx=x-left;dy=y-top;ws=spans(w,4-dx%4);hs=spans(h,4-dy%4)
        cells=[];cy=dy
        for ch in hs:
            cx=dx
            for cw in ws:cells.append((cx,cy,cw,ch));cx+=cw
            cy+=ch
        all_cells.append(cells)
        for ci,(cx,cy,cw,ch) in enumerate(cells):
            bi=cx//4+(cy//4)*bw;old=cell_values[bi]
            if old is not None and eq_size and eq.read(1):continue
            selection=mask.read(4) if old is not None else 15
            count=selection.bit_count();encoding=enc.read(1) if count and enc_size else 0
            pixels=[];last=0
            for _ in range(count):
                if encoding:value=raw.read(8)
                else:
                    value=last;delta=codes.read(4);value+=delta
                    while delta==15:delta=codes.read(4);value+=delta
                if value==last:break
                if value>=len(palette):raise ValueError("DCC palette reference outside table")
                pixels.append(value);last=value
            values=[]
            for bit in range(4):
                if selection&(1<<bit):values.append(pixels.pop() if pixels else 0)
                else:values.append(old[bit])
            cell_values[bi]=values;entries.append((fi,ci,values))
            if len(entries)>1_000_000:raise ValueError("DCC cell limit")
    entries_iter=iter(entries);entry=next(entries_iter,None);previous_cells=[None]*(bw*bh);previous=None;images=[]
    for fi,cells in enumerate(all_cells):
        pixels=bytearray(width*height)
        for ci,cell in enumerate(cells):
            cx,cy,cw,ch=cell;bi=cx//4+(cy//4)*bw
            if entry is None or entry[:2]!=(fi,ci):
                old=previous_cells[bi]
                if previous is not None and old is not None and old[2:]==cell[2:]:
                    for row in range(ch):pixels[(cy+row)*width+cx:(cy+row)*width+cx+cw]=previous[(old[1]+row)*width+old[0]:(old[1]+row)*width+old[0]+cw]
            else:
                values=[palette[v] for v in entry[2]]
                bits=0 if values[0]==values[1] else 1 if values[1]==values[2] else 2
                for row in range(ch):
                    begin=(cy+row)*width+cx
                    if bits:
                        for col in range(cw):pixels[begin+col]=values[codes.read(bits)]
                    else:pixels[begin:begin+cw]=bytes([values[0]])*cw
                entry=next(entries_iter,None)
            previous_cells[bi]=cell
        images.append(Image.frombytes("P",(width,height),bytes(pixels)));previous=pixels
    return images,(left,top)

def rgba(indexed,palette):
    if len(palette)<768:raise ValueError("Truncated palette")
    rgb=bytes(component for i in range(0,768,3) for component in (palette[i+2],palette[i+1],palette[i]))
    image=indexed.copy();image.putpalette(rgb);image.info["transparency"]=0
    return image.convert("RGBA")

def cof(data):
    if len(data)<28:raise ValueError("Truncated COF")
    layers,frames,directions=data[:3]
    if not 1<=layers<=16 or not 1<=frames<=256 or directions not in (1,8,16,32):raise ValueError("Unsupported COF layout")
    layer_rows=[]
    for i in range(layers):
        offset=28+i*9
        if offset+9>len(data):raise ValueError("Truncated COF layer")
        layer=data[offset]
        if layer>=16:raise ValueError("Invalid COF component")
        layer_rows.append((layer,data[offset+5:offset+8].decode("ascii")))
    start=28+layers*9+frames
    priority=data[start:start+directions*frames*layers]
    if len(priority)!=directions*frames*layers:raise ValueError("Truncated COF priorities")
    return {"layers":layer_rows,"frames":frames,"directions":directions,"priority":priority}

def dc6(data):
    if len(data)<24:raise ValueError("Truncated DC6")
    version,flags,encoding,term,directions,frames=struct.unpack_from("<6I",data)
    if version!=6 or not 1<=directions<=32 or not 1<=frames<=512:raise ValueError("Invalid DC6 header")
    images=[]
    for i in range(directions*frames):
        pointer=struct.unpack_from("<I",data,24+i*4)[0]
        flip,w,h,x,y,unknown,next_frame,length=struct.unpack_from("<8I",data,pointer)
        if w*h>4_000_000 or pointer+32+length>len(data):raise ValueError("DC6 frame outside bounds")
        pixels=bytearray(w*h);col=0;row=h-1 if not flip else 0;end=pointer+32+length;cursor=pointer+32
        while cursor<end and 0<=row<h:
            code=data[cursor];cursor+=1
            if code==128:col=0;row+=1 if flip else -1;continue
            if code&128:col+=code&127
            else:
                if col+code>w or cursor+code>end:raise ValueError("Invalid DC6 run")
                pixels[row*w+col:row*w+col+code]=data[cursor:cursor+code];cursor+=code;col+=code
        images.append(Image.frombytes("P",(w,h),bytes(pixels)))
    return images

def dt1_floors(data):
    if len(data)<276 or struct.unpack_from("<II",data)!=(7,6):raise ValueError("Unsupported DT1 header")
    count,pointer=struct.unpack_from("<II",data,268)
    if count>10000 or pointer+count*96>len(data):raise ValueError("Invalid DT1 tile table")
    result=[]
    jumps=(14,12,10,8,6,4,2,0,2,4,6,8,10,12,14)
    lengths=(4,8,12,16,20,24,28,32,28,24,20,16,12,8,4)
    for index in range(count):
        offset=pointer+index*96;orientation=struct.unpack_from("<I",data,offset+20)[0]
        if orientation!=0 or any(flag&9 for flag in data[offset+40:offset+65]):continue
        blocks,block_bytes,nblocks=struct.unpack_from("<III",data,offset+72)
        if nblocks>4096 or blocks+nblocks*20>len(data):raise ValueError("Invalid DT1 block table")
        pixels=bytearray(160*80)
        for b in range(nblocks):
            bo=blocks+b*20;x,y=struct.unpack_from("<hh",data,bo)
            fmt=struct.unpack_from("<H",data,bo+8)[0];length=struct.unpack_from("<I",data,bo+10)[0];start=blocks+struct.unpack_from("<I",data,bo+16)[0];end=start+length
            if end>len(data):raise ValueError("DT1 block outside file")
            cursor=start
            if fmt==1:
                if length!=256:raise ValueError("Invalid isometric DT1 block")
                for row,(jump,run) in enumerate(zip(jumps,lengths)):
                    if not 0<=y+row<80 or not 0<=x+jump<=160-run:raise ValueError("DT1 floor bounds")
                    pos=(y+row)*160+x+jump;pixels[pos:pos+run]=data[cursor:cursor+run];cursor+=run
            else:
                row=0;col=0
                while cursor<end:
                    if cursor+2>end:raise ValueError("Truncated DT1 run")
                    skip,run=data[cursor:cursor+2];cursor+=2
                    if skip==run==0:row+=1;col=0;continue
                    col+=skip
                    if cursor+run>end or not 0<=y+row<80 or x+col+run>160:raise ValueError("DT1 floor run bounds")
                    pos=(y+row)*160+x+col;pixels[pos:pos+run]=data[cursor:cursor+run];cursor+=run;col+=run
        if sum(value!=0 for value in pixels)>=5800:result.append((index,Image.frombytes("P",(160,80),bytes(pixels))))
    return result

def dc6_direction(data,direction):
    """Normalize per-frame DC6 origins into the same canvas contract as DCC."""
    images=dc6(data);directions,count=struct.unpack_from("<II",data,16)
    direction=min(direction,directions-1);frames=images[direction*count:(direction+1)*count];origins=[]
    for index,image in enumerate(frames):
        pointer=struct.unpack_from("<I",data,24+(direction*count+index)*4)[0]
        x,y=struct.unpack_from("<ii",data,pointer+12)
        origins.append((x,y-image.height+1))
    left=min(x for x,y in origins);top=min(y for x,y in origins)
    right=max(x+image.width for (x,y),image in zip(origins,frames));bottom=max(y+image.height for (x,y),image in zip(origins,frames))
    result=[]
    for image,(x,y) in zip(frames,origins):
        canvas=Image.new("P",(right-left,bottom-top));canvas.paste(image,(x-left,y-top),image.point(lambda value:255 if value else 0,"L"));result.append(canvas)
    return result,(left,top)
