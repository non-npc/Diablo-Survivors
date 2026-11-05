"""Export compact metadata and a coverage report; never copy game payloads."""
import json,sqlite3,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from adapters.diablo2.importer import Assets,detect
from adapters.diablo2.bestiary import rows,VERSION
from inspector.services.workspace import atomic_json

def export(workspace,expansion):
    active=json.loads((ROOT/workspace/"active.json").read_text())
    manifest=json.loads(Path(active["manifest_path"]).read_text())
    identity=detect(manifest["source_game"]["folder"],include_expansion=expansion,validate_archives=False)
    assets=Assets(identity,Path(active["manifest_path"]).parent)
    try:
        monster_rows=rows(assets,"monstats")
        assets.read("data/global/excel/levels.txt")
        fields=["Class","namco","Code","BaseW","BaseId","IsNPC","IsAtt","Velocity","ModeW","MinHP","MaxHP"]+["Miss"+mode for mode in ["A1","A2","S1","S2","S3","S4","C"]]+["Skill"+str(i) for i in range(1,6)]
        needed={profile["original_index"] for profile in manifest["bestiary"]["monsters"].values()}
        compact_rows=[{key:row.get(key,"") for key in fields} if index in needed else {} for index,row in enumerate(monster_rows)]
        template={"schema_version":1,"version":VERSION,"compatible_edition":identity["edition_id"],"table_sha256":{name:assets.used[name]["sha256"] for name in ["data/global/excel/monstats.txt","data/global/excel/levels.txt"]},"monster_rows":compact_rows,**manifest["bestiary"]}
        path=ROOT/"catalogs/diablo2"/(identity["edition_id"]+"-bestiary.json");atomic_json(path,template)
    finally:assets.close()
    return manifest

def main():
    manifests=[export(Path(".local/diablo2-base-test"),False),export(Path(".local/diablo2"),True)]
    lines=["# Bestiary coverage", "", "Validated against the locally installed original classic assets on 2026-10-13.", "", "| Pack | Enemy profiles | Combat areas | Named unique profiles |", "| --- | ---: | ---: | ---: |", "| Diablo I GOG 1.0.9.2 | 95 | 22 | Included in floor/quest import |"]
    for document in manifests:
        counts=document["bestiary"]["counts"];label="Diablo II + LoD 1.07" if document["source_game"]["expansion"] else "Diablo II base assets (expansion excluded)"
        lines.append(f"| {label} | {counts['monsters']} | {counts['areas']} | {counts['named_uniques']} |")
    lines += ["", "Profiles count distinct identities/variants and bosses, not unique sprite families. Reusable compositions and decoded assets are cached locally. Only the selected area's sprites are loaded. Diablo II uses its own area names and Acts; towns and empty noncombat areas are excluded, and the cow map stays a portal event.", "", "D1 population comes from the shipped original monster floor ranges and quest DUN conversions. D2 Acts I–IV use the installed Normal population and special-population tables, with explicit boss and named-unique placements. Normal population is used across our Easy/Hard/Legendary modes; these are survival difficulties, not original D2 Nightmare/Hell roster rules.", "", "LoD 1.07 contains pre-release Act V placeholders. Act V uses explicitly authored native-family rosters and named-unique mappings, labeled in each area's provenance. These are themed survival assignments, not verified reproduction of the original hardcoded/preset population. Unused/debug monsters and unplaced uniques are not presented as playable enemies.", "", "Original graphics and family audio are imported. Melee/ranged behavior, elemental projectiles, and stationary original profiles are supported. Original resurrection, spawning offspring, burrowing, teleporting, curses, unique modifiers, and full boss skill sets are not reproduced. Areas use original regional floor art in survival layouts; they are not original-map clones.", "", "Bundled catalogs contain metadata and compatibility hashes only. A matching installation uses that roster template; different table hashes fall back to the supported local table reader. Original sprites, audio, raw tables, MPQs and local databases are never included in the release.", "", "The local asset database includes `bestiary_monsters` and `bestiary_areas`; `bestiary.json` and `survival.json` sit beside it.", "", "Family reference: [Blizzard's Arreat Summit bestiary](https://classic.battle.net/diablo2exp/monsters/). The installed tables control version-specific data; later website statistics are not copied into balance values.", "", "## Diablo II + LoD area roster", "", "| Area | Enemies |", "| --- | --- |"]
    anchor=lines.index("## Diablo II + LoD area roster")
    lines[anchor:anchor]=["Boss-only chambers use a survival endurance adaptation: the first boss appears after five seconds, with one active main boss. After it dies, a sixty-second recovery precedes the next encounter, until the selected difficulty timer ends. Named uniques still appear only once per run, including the other Ancients.",""]
    for area in manifests[1]["arenas"].values():
        names=list(dict.fromkeys(area["enemy_definitions"][kind]["name"] for kind in area["enemy_roster"]))
        lines.append("| "+area["title"]+" | "+", ".join(names)+" |")
    (ROOT/"docs/bestiary.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("Exported two compatibility catalogs and docs/bestiary.md")

if __name__=="__main__":main()
