import struct
import pytest
from PIL import Image
from adapters.diablo2.formats import Bits,decode_dcc,dc6,cof,rgba,dt1_floors

def packed(values):
    bits=[]
    for value,count in values:bits.extend((value>>i)&1 for i in range(count))
    return bytes(sum(bits[j+i]<<i for i in range(min(8,len(bits)-j))) for j in range(0,len(bits),8))

def test_dcc_pixel_and_palette_order():
    body=[(1,32),(0,2)]+[(x,4) for x in [0,2,2,0,0,0,0]]+[(1,2),(1,2),(0,1),(0,20)]+[(int(i<2),1) for i in range(256)]+[(1,4),(0,4),(0,1)]
    source=bytes([0x74,6,1])+struct.pack('<III',1,1,0)+struct.pack('<I',19)+packed(body)
    frames,origin=decode_dcc(source,0)
    assert origin==(0,0) and frames[0].getpixel((0,0))==1
    palette=bytearray(768);palette[3:6]=bytes([10,20,30])
    assert rgba(frames[0],palette).getpixel((0,0))==(30,20,10,255)
    assert rgba(Image.new('P',(1,1),0),palette).getpixel((0,0))[3]==0
    with pytest.raises(ValueError):decode_dcc(source[:20],0)

def test_dc6_and_cof_bounds():
    data=struct.pack('<6I',6,0,0,0,1,1)+struct.pack('<I',28)+struct.pack('<8I',0,2,1,0,0,0,0,4)+bytes([2,1,2,128])
    assert list(dc6(data)[0].getdata())==[1,2]
    with pytest.raises((ValueError,struct.error)):dc6(data[:-1])
    source=bytes([1,1,8])+bytes(25)+bytes([1,0,0,0,0])+b'hth'+bytes(1)+bytes(1)+bytes([1])*8
    assert cof(source)['layers']==[(1,'hth')]
    with pytest.raises(ValueError):cof(source[:-1])

def test_dt1_and_bit_limits():
    with pytest.raises(ValueError):dt1_floors(bytes(276))
    reader=Bits(bytes([255]),end=3)
    assert reader.signed(3)==-1
    with pytest.raises(ValueError):reader.read(1)
