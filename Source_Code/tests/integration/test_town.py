import struct
import pytest
from adapters.diablo1.town import read_sector,assemble,component

def test_sector_ids_and_quadrant_order():
    data=struct.pack("<HHHH",2,1,1,2)
    result=assemble([(1,2,3,4),(5,6,7,8)],[(data,0,0)],size=4)
    assert result[:8]==[1,2,5,6,3,4,7,8]

def test_sector_rejects_truncation_and_bad_references():
    with pytest.raises(ValueError):read_sector(struct.pack("<HHH",2,1,1),2)
    with pytest.raises(ValueError):read_sector(struct.pack("<HHH",1,1,3),2)
    with pytest.raises(ValueError):assemble([(1,2,3,4)],[(struct.pack("<HHH",1,1,1),3,3)],size=4)

def test_collision_uses_largest_connected_region():
    grid=[1]*49
    for x,y in [(1,1),(1,2),(2,2),(5,5)]:grid[y*7+x]=0
    assert component(grid,bytes([0,1]),7)=={8,15,16}
