"""Verified metadata-only combat sound associations; local cached WAV payloads only."""
import json,sqlite3
from pathlib import Path
MAPPINGS={
 "warrior.attack":["sfx/misc/swing.wav","sfx/misc/swing2.wav"],
 "rogue.attack":["sfx/misc/bfire.wav"],
 "sorcerer.attack":["sfx/misc/cast2.wav"],
 "firebolt.impact":["sfx/misc/firimp1.wav","sfx/misc/firimp2.wav"],
 "skeleton.attack":[f"monsters/skelaxe/sklaxa{i}.wav" for i in (1,2)],
 "skeleton.hit":[f"monsters/skelaxe/sklaxh{i}.wav" for i in (1,2)],
 "skeleton.death":[f"monsters/skelaxe/sklaxd{i}.wav" for i in (1,2)],
 "cow.attack":["sfx/towners/cow1.wav","sfx/towners/cow2.wav"],
 "cow.hit":["sfx/towners/cow3.wav","sfx/towners/cow4.wav"],
 "cow.death":["sfx/towners/cow5.wav","sfx/towners/cow6.wav"],
 "loot.powerup":["sfx/items/magic1.wav"],"loot.xp":["sfx/items/invgrab.wav"],"loot.healing":["sfx/misc/healing.wav"],
 "loot.gold":["sfx/items/gold.wav"],"portal.open":["sfx/misc/portal.wav"]}
for key,folder,prefix in [("warrior","warrior","warior"),("rogue","rogue","rogue"),("sorcerer","sorceror","mage")]:
 MAPPINGS[key+".hit"]=[f"sfx/{folder}/{prefix}69.wav"]
 MAPPINGS[key+".death"]=[f"sfx/{folder}/{prefix}71.wav"]

def build_audio(database,folder):
 with sqlite3.connect(database) as connection:
  entries={n.replace("\\","/"):(p,h) for n,p,h in connection.execute("SELECT source_path,raw_path,payload_sha256 FROM assets WHERE archive_path='DIABDAT.MPQ' AND raw_path IS NOT NULL")}
 result={"schema_version":1,"edition":"diablo1-gog-main","sounds":{},"missing":[],"notes":{"cow":"Authored combat associations using original town vocalizations","timing":"Authored runtime combat events; original animation-frame timing is not reproduced","references":["https://github.com/diasurgical/devilution/blob/master/Source/effects.cpp","https://github.com/diasurgical/devilution/blob/master/Source/player.cpp","https://github.com/diasurgical/devilution/blob/master/Source/monstdat.cpp","https://github.com/diasurgical/devilution/blob/master/Source/spelldat.cpp"]}}
 for event,names in MAPPINGS.items():
  result["sounds"][event]=[]
  for name in names:
   if name not in entries:result["missing"].append(name);continue
   raw,sha=entries[name]
   result["sounds"][event].append({"path":raw,"source_path":name,"sha256":sha,"association":"authored" if event.startswith("cow.") or event in ("firebolt.impact","loot.powerup","loot.xp","loot.healing") else "format-reference"})
 target=Path(folder);target.mkdir(parents=True,exist_ok=True)
 (target/"audio-mappings.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
 return result
