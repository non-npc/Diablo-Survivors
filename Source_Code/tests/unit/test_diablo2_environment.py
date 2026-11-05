import struct
from PIL import Image
from adapters.diablo2.environment import base_tiles, continuous_ground
from adapters.diablo2.formats import dcc_direction


def test_dcc_16_and_32_directions_keep_original_compass_slots():
    for count in (8,16,32):
        assert [dcc_direction(count,d) for d in range(8)] == [4,0,5,1,6,2,7,3]
    assert all(dcc_direction(1,d)==0 for d in range(8))


def test_floor_material_does_not_mix_transition_subtiles():
    data=bytearray(276+96*4);struct.pack_into('<I',data,272,276)
    for i,(main,sub) in enumerate([(2,8),(2,0),(2,0),(3,0)]):struct.pack_into('<III',data,276+i*96+24,main,sub,1)
    tiles=[(i,Image.new('P',(160,80),i+1)) for i in range(4)]
    assert [i for i,_ in base_tiles(data,tiles)]==[1,2]


def test_natural_ground_is_opaque_and_wraps_without_a_seam():
    palette=bytes([i for i in range(256) for _ in range(3)])
    image=continuous_ground([(0,Image.new('P',(160,80),100))],palette)
    assert image.size==(3200,2400)
    assert image.crop((0,0,1,image.height)).tobytes()==image.crop((image.width-1,0,image.width,image.height)).tobytes()
    assert image.crop((0,0,image.width,1)).tobytes()==image.crop((0,image.height-1,image.width,image.height)).tobytes()
