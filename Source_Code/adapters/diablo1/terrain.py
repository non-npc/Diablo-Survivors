"""Independent classic Diablo terrain decoder: CEL + MIN + TIL + SOL.

Format facts referenced from DevilutionX dun_tile.hpp/dun_tile_data.cpp.
No original game pixels, maps or third-party source are embedded here.
"""
import math
import struct
from PIL import Image
from inspector.services.recognition import sprite_groups, rle_pixels, palette_image


def decode_primitive(data, shape, palette):
    if shape not in range(6): raise ValueError("Unsupported terrain shape")
    if shape == 0:
        if len(data) != 1024: raise ValueError("Square must contain 1024 pixels")
        return palette_image(data,b"\xff"*1024,32,32,palette)
    if shape == 1:
        indices,alpha=rle_pixels(data,"CEL")
        if len(indices)!=1024: raise ValueError("RLE square must contain 1024 pixels")
        return palette_image(indices,alpha,32,32,palette)
    indices=bytearray(1024);alpha=bytearray(1024)
    triangle=shape in (2,3)
    widths=list(range(2,33,2))+(list(range(30,1,-2)) if triangle else [32]*16)
    left=shape in (2,4)
    cursor=0
    for row,width in enumerate(widths):
        padded=row<16 or triangle
        padding=2 if padded and row%2==0 else 0
        if left: cursor+=padding
        if cursor+width>len(data): raise ValueError("Truncated terrain primitive")
        x=32-width if left else 0
        begin=row*32+x
        indices[begin:begin+width]=data[cursor:cursor+width]
        alpha[begin:begin+width]=b"\xff"*width
        cursor+=width
        if not left: cursor+=padding
    if cursor!=len(data): raise ValueError("Unexpected terrain primitive trailing bytes")
    return palette_image(indices,alpha,32,32,palette)


class TerrainSet:
    def __init__(self,cel,minimum,tiles,properties,palette,blocks=10):
        if len(palette)!=768: raise ValueError("Terrain requires a 256-color RGB palette")
        if blocks not in (10,16) or len(minimum)%(blocks*2): raise ValueError("Invalid MIN record width")
        if len(tiles)%8: raise ValueError("Invalid TIL records")
        self.frames=sprite_groups(cel)
        if len(self.frames)!=1: raise ValueError("Terrain CEL must have a single frame group")
        self.frames=self.frames[0];self.cel=cel;self.palette=palette
        self.pieces=list(struct.iter_unpack("<"+"H"*blocks,minimum))
        self.tiles=list(struct.iter_unpack("<4H",tiles))
        if len(properties)!=len(self.pieces): raise ValueError("SOL/MIN piece counts differ")
        self.properties=properties;self.blocks=blocks;self.cache={}
        shapes={}
        for piece in self.pieces:
            for ref in piece:
                if not ref: continue
                index=ref&4095;shape=(ref>>12)&7
                if not 1<=index<=len(self.frames) or shape>5: raise ValueError("Invalid MIN primitive reference")
                if index in shapes and shapes[index]!=shape: raise ValueError("Conflicting primitive encodings")
                shapes[index]=shape
        if any(ref>=len(self.pieces) for tile in self.tiles for ref in tile): raise ValueError("TIL reference outside MIN")
        self.shapes=shapes
        for index,shape in shapes.items():
            begin,end=self.frames[index-1]
            self.cache[(index,shape)]=decode_primitive(cel[begin:end],shape,palette)

    def piece(self,index):
        if not 0<=index<len(self.pieces): raise ValueError("Invalid piece index")
        height=self.blocks//2*32
        image=Image.new("RGBA",(64,height))
        # MIN rows are stored top to bottom as paired left/right primitives.
        for slot,ref in enumerate(self.pieces[index]):
            if ref:
                image.alpha_composite(self.cache[(ref&4095,(ref>>12)&7)],(slot%2*32,slot//2*32))
        return image

    def tile(self,index):
        if not 0<=index<len(self.tiles): raise ValueError("Invalid tile index")
        height=self.blocks//2*32+32
        image=Image.new("RGBA",(128,height))
        for ref,position in zip(self.tiles[index],((32,0),(64,16),(0,16),(32,32))):
            image.alpha_composite(self.piece(ref),position)
        return image

    def atlas(self):
        columns=8;cell_height=self.blocks//2*32+32
        height=math.ceil(len(self.tiles)/columns)*cell_height
        if columns*128*height>16*1024*1024: raise ValueError("Terrain atlas exceeds pixel limit")
        image=Image.new("RGBA",(columns*128,height))
        for i in range(len(self.tiles)):
            image.alpha_composite(self.tile(i),(i%columns*128,i//columns*cell_height))
        return image

    def summary(self):
        return {"primitive_count":len(self.frames),"decoded_primitives":len(self.shapes),"piece_count":len(self.pieces),"tile_count":len(self.tiles),"shapes":sorted(set(self.shapes.values())),"tile_reference_base":0,"primitive_reference_base":1,"piece_size":[64,self.blocks//2*32],"tile_size":[128,self.blocks//2*32+32],"sol_flags":{"solid":1,"block_light":2,"block_missile":4},"validation":"all referenced primitives decoded; MIN/TIL/SOL bounds checked"}
