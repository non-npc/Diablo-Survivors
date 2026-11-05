import json
from pathlib import Path

def test_prop_regions_follow_original_placement_instead_of_duplicating_pool():
    data=json.loads(Path("catalogs/diablo1/prop_metadata.json").read_text())
    regions=data["regions"]
    cave={item["stem"] for item in regions["CAV"]}
    hell={item["stem"] for item in regions["HEL"]}
    cathedral={item["stem"] for item in regions["CAT"]}
    assert "mushptch" in cave and "sarc" not in cave and "bcase" not in cave
    assert {"cauldren","tnudem","tnudew","tsoul"}<=hell
    assert "cauldren" not in cathedral and "sarc" in cathedral
    assert "barrel" in {item["stem"] for item in data["shared"]}
    assert len({tuple(sorted({item["stem"] for item in entries})) for entries in regions.values()})==5
    assert len(data["town_nature"])==10
    for entries in list(regions.values())+[data["shared"]]:
        for item in entries:
            assert item["width"]>0 and item["frame"]>=0 and item["association"]
            assert item["source_path"].startswith("objects/") and item["source_path"].endswith(".cel")
