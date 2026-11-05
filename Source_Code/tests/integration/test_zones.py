from adapters.diablo1.zones import zone_catalog
from pathlib import Path
import json

def test_base_game_zone_inventory_and_saved_order():
    zones=zone_catalog()
    assert len(zones)==22
    assert [z["floor"] for z in zones if "floor" in z]==list(range(1,17))
    assert sum("quest_map" in z for z in zones)==5
    assert zones[0]["id"]=="cathedral" and zones[1]["id"]=="tristram"
    assert len({z["id"] for z in zones})==22
    for tileset in range(1,5):
        assert sum(z["tileset"]==tileset and "floor" in z for z in zones)==4
    source=Path("runtime/scripts/class_progress.gd").read_text()
    encoded=source.split("const AREA_ORDER = ",1)[1].splitlines()[0]
    assert json.loads(encoded)==[z["id"] for z in zones]


def test_original_enemy_ranges_and_challenge_identity():
    from adapters.diablo1.monsters import metadata,zone_challenges
    data=metadata();types={row["name"]:row for row in data["monsters"]}
    assert types["Zombie"]["min_floor"]==1 and types["Zombie"]["max_floor"]==2
    assert types["Blood Knight"]["index"]==96 and types["Advocate"]["index"]==108
    assert types["The Dark Lord"]["index"]==110
    challenges=zone_challenges(["zombie"],{"zombie":{"name":"Zombie"},"boss":{"name":"Boss"}},"boss")
    assert challenges[0]["enemy"]=="boss" and challenges[0]["target"]==1
    assert [(c["enemy"],c["target"]) for c in challenges[1:]]==[("zombie",15),("zombie",40)]


def test_generated_layout_alternates_props_without_stairs():
    from adapters.diablo1.zones import generated_tiles,SCENERY
    class Tiles:
        properties=[0,1]
        tiles=[(0,0,0,0)]*207
    for region,scenery in SCENERY.items():
        terrain=Tiles();terrain.tiles=list(terrain.tiles)
        for index in scenery["obstacles"]+scenery["boundaries"]:terrain.tiles[index]=(1,1,1,1)
        width,height,cells=generated_tiles(terrain,20261013,tileset=region)
        interior=[cells[y*width+x] for y in range(1,height-1) for x in range(1,width-1)]
        props={tile for tile in interior if tile in scenery["obstacles"]}
        assert len(props)>=min(3,len(scenery["obstacles"]))
        assert cells==generated_tiles(terrain,20261013,tileset=region)[2]
        assert not ({56,65}&props) if region==1 else True
