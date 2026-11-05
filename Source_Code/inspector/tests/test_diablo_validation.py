import struct
import pytest
from adapters.diablo1.terrain import decode_primitive,TerrainSet
from adapters.diablo1.validation import translated_palette,animation_mapping,DIRECTIONS
from inspector.services.recognition import inspect_resource
from inspector.tests.test_recognition import sample_cl2

PALETTE=bytes(v for i in range(256) for v in (i,255-i,0))

def shaped_data(shape):
    triangle=shape in (2,3)
    widths=list(range(2,33,2))+(list(range(30,1,-2)) if triangle else [32]*16)
    data=bytearray()
    for row,width in enumerate(widths):
        padding=b"\x00\x00" if (row<16 or triangle) and row%2==0 else b""
        if shape in (2,4): data.extend(padding)
        data.extend(bytes([row])*width)
        if shape in (3,5): data.extend(padding)
    return bytes(data)

@pytest.mark.parametrize("shape,bytes_count,opaque",[(2,544,512),(3,544,512),(4,800,784),(5,800,784)])
def test_triangular_and_trapezoid_padding(shape,bytes_count,opaque):
    data=shaped_data(shape)
    assert len(data)==bytes_count
    image=decode_primitive(data,shape,PALETTE)
    assert image.size==(32,32)
    assert sum(a==255 for a in image.getchannel("A").getdata())==opaque
    # Encoded bottom row becomes the bottom image row, index zero remains opaque.
    x=31 if shape in (2,4) else 0
    assert image.getpixel((x,31))==(0,255,0,255)

@pytest.mark.parametrize("shape",[2,3,4,5])
def test_reject_truncated_terrain_primitives(shape):
    with pytest.raises(ValueError):decode_primitive(shaped_data(shape)[:-1],shape,PALETTE)


def test_square_and_rle_square():
    assert decode_primitive(bytes([7])*1024,0,PALETTE).getpixel((0,0))==(7,248,0,255)
    data=(bytes([32])+bytes([7])*32)*32
    assert decode_primitive(data,1,PALETTE).getpixel((0,0))==(7,248,0,255)


def fixture_terrain(bad_reference=False):
    raw=bytes([7])*1024
    cel=struct.pack("<3I",1,12,12+len(raw))+raw
    minimum=struct.pack("<10H",*([0]*8+[3 if bad_reference else 1,1]))
    return cel,minimum,struct.pack("<4H",0,0,0,0),bytes([1]),PALETTE


def test_terrain_composition_and_property_validation():
    terrain=TerrainSet(*fixture_terrain())
    assert terrain.summary()["decoded_primitives"]==1
    assert terrain.piece(0).size==(64,160)
    assert terrain.tile(0).size==(128,192)
    assert terrain.properties[0]&1


def test_reject_out_of_range_primitive():
    with pytest.raises(ValueError,match="reference"): TerrainSet(*fixture_terrain(True))


def test_translation_changes_colors_without_changing_alpha():
    translation=bytearray(range(256));translation[0]=42
    palette=translated_palette(PALETTE,translation)
    info,image=inspect_resource(sample_cl2(),"actor.cl2",palette=PALETTE,translation=translation,preview_group=1)
    assert image.getpixel((0,0))==(42,213,0,255)
    assert info["preview_group"]==1
    assert palette[:3]==bytes([42,213,0])


def test_animation_rules_are_scoped_and_do_not_invent_timing():
    info={"group_count":8,"frames_per_group":[8]*8}
    mapping=animation_mapping("monsters/skelaxe/sklaxw.cl2",info)
    assert mapping["state"]=="walk" and mapping["directions"]==list(DIRECTIONS)
    assert "timing unverified" in mapping["confidence"]
    assert animation_mapping("ui/randomw.cl2",info) is None
    assert animation_mapping("monsters/skelaxe/sklaxw.cl2",{"group_count":1}) is None
