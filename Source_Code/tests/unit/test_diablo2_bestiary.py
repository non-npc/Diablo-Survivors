import csv,io,struct
from adapters.diablo2.bestiary import plans,profile,localized_names
from adapters.diablo2.formats import dc6_direction,cof

def table(records):
    output=io.StringIO();writer=csv.DictWriter(output,fieldnames=list(records[0]),delimiter="\t")
    writer.writeheader();writer.writerows(records);return output.getvalue().encode("cp1252")

class Assets:
    identity={"expansion":False}
    def __init__(self):
        self.files={"monstats":table([{"Class":"Skeleton","Code":"SK","IsNPC":"0","IsAtt":"1"},{"Class":"Zombie","Code":"ZM","IsNPC":"0","IsAtt":"1"},{"Class":"NPC","Code":"NP","IsNPC":"1","IsAtt":"0"}]),"levels":table([{"Name":"Blood Moor","Id":"2","Act":"0","LevelName":"Blood Moor","MonLvl1":"1","Mtot":"2","M1":"0","M2":"1","S1":"2"},{"Name":"Town","Id":"1","Act":"0","LevelName":"Rogue Encampment","MonLvl1":"0","Mtot":"0","M1":"0","M2":"0","S1":"0"}])}
    def read(self,path):return self.files[path.split("/")[-1].split(".")[0]]
    def present(self,path):return False

def test_normal_roster_preserves_skeleton_zero_and_excludes_npcs():
    monsters,areas=plans(Assets())
    assert len(areas)==1 and areas[0]["id"]=="d2-area-2"
    assert areas[0]["monster_indices"]==[0,1]
    assert areas[0]["act"]==1

def test_ranged_skeleton_equipment_and_melee_distinction():
    row={"Code":"SK","BaseW":"bow","Class":"Skeleton Archer","MissA1":"0"}
    assert profile(row,170,[{"Missile":"Arrow"}])["ranged"]
    row.update(BaseW="1hs",MissA1="65535",Class="Skeleton")
    assert not profile(row,0,[{"Missile":"Arrow"}])["ranged"]

def test_one_direction_cof_and_signed_dc6_origin():
    source=bytes([1,1,1])+bytes(25)+bytes([1,0,0,0,0])+b"hth"+bytes(1)+bytes(1)+bytes([1])
    assert cof(source)["directions"]==1
    data=struct.pack("<6I",6,0,0,0,1,1)+struct.pack("<I",28)+struct.pack("<8i",0,2,1,-3,4,0,0,4)+bytes([2,1,2,128])
    images,origin=dc6_direction(data,0)
    assert origin==(-3,4) and list(images[0].getdata())==[1,2]

def test_missing_optional_localization_is_safe():
    assert localized_names(Assets())=={}
