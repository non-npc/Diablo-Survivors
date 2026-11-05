extends RefCounted
const Difficulties=preload("res://scripts/difficulties.gd")
const SHOP={
    "rerolls":{"title":"Second chances","effect":"+1 upgrade reroll per run per rank (up to 8 total)","price":150,"cap":5,"category":"General"},
    "haste":{"title":"Fleet feet","effect":"+3% movement speed per rank","price":60,"cap":10,"category":"General"},
    "vitality":{"title":"Vitality","effect":"+10 starting HP per rank","price":50,"cap":10,"category":"Defense"},
    "armor":{"title":"Iron skin","effect":"Reduce contact damage by 1 per rank","price":80,"cap":5,"category":"Defense"},
    "power":{"title":"Power","effect":"+5% weapon damage per rank","price":75,"cap":10,"category":"General"},
    "magnet":{"title":"Soul reach","effect":"+10 XP pickup range per rank","price":50,"cap":5,"category":"General"},
    "learning":{"title":"Experienced adventurer","effect":"+5% XP gained per rank","price":90,"cap":5,"category":"General"},
    "duration":{"title":"Lasting blessings","effect":"+10% timed boost duration per rank","price":120,"cap":5,"category":"General"},
    "precision":{"title":"Keen eye","effect":"+2 percentage points of critical chance per rank","price":150,"cap":5,"category":"General"},
    "recovery":{"title":"Steady recovery","effect":"Regenerate 0.2 HP per second per rank","price":120,"cap":5,"category":"Defense"},
    "harvest":{"title":"Vital spoils","effect":"Restore 0.25 HP per kill per rank","price":150,"cap":5,"category":"Defense"},
    "cleave":{"title":"Warrior: sweeping blade","effect":"Sword hits one extra target per rank","price":120,"cap":3,"category":"Class","class":"warrior"},
    "archery":{"title":"Rogue: marksmanship","effect":"+8% bow damage per rank","price":100,"cap":5,"category":"Class","class":"rogue"},
    "blast":{"title":"Sorcerer: expanding flame","effect":"+15 firebolt splash radius per rank","price":100,"cap":5,"category":"Class","class":"sorcerer"},
    "barbarian_cleave":{"title":"Barbarian: sweeping blade","effect":"+1 cleave target per rank","price":120,"cap":3,"category":"Class","class":"barbarian"},
    "amazon_archery":{"title":"Amazon: marksmanship","effect":"+8% bow damage per rank","price":100,"cap":5,"category":"Class","class":"amazon"},
    "paladin_guard":{"title":"Paladin: sacred guard","effect":"+1 armor per rank","price":100,"cap":5,"category":"Class","class":"paladin"},
    "necromancer_minions":{"title":"Necromancer: minion mastery","effect":"+20% minion damage per rank","price":100,"cap":5,"category":"Class","class":"necromancer"},
    "sorceress_blast":{"title":"Sorceress: expanding flame","effect":"+15 spell splash radius per rank","price":100,"cap":5,"category":"Class","class":"sorceress"},
    "assassin_strikes":{"title":"Assassin: lethal strikes","effect":"+8% weapon damage per rank","price":100,"cap":5,"category":"Class","class":"assassin"},
    "druid_recovery":{"title":"Druid: natural recovery","effect":"+0.5 HP regeneration per second per rank","price":100,"cap":5,"category":"Class","class":"druid"}
}
const AREA_ORDER = ["cathedral", "tristram", "cathedral-2", "cathedral-3", "skeleton-king", "cathedral-4", "maze", "catacombs-5", "catacombs-6", "bone-chamber", "catacombs-7", "catacombs-8", "caves-9", "poisoned-water", "caves-10", "caves-11", "caves-12", "hell-13", "hell-14", "hell-15", "lazarus", "hell-16"]
const CLASSES = ["warrior","rogue","sorcerer"]
const D2_CLASSES=["barbarian","amazon","paladin","necromancer","sorceress","assassin","druid"]
static func archetype(key:String) -> String:
    return "warrior" if key in ["barbarian","paladin","assassin"] else "rogue" if key=="amazon" else "sorcerer" if key in ["necromancer","sorceress","druid"] else key
static func requirement(key:String) -> String:
    return {"rogue":"500 lifetime kills","amazon":"500 lifetime kills","sorcerer":"complete Normal in an area","sorceress":"complete Normal in an area","paladin":"complete Nightmare in any area","necromancer":"1,000 lifetime kills","assassin":"2,000 lifetime kills","druid":"complete Hell in any area"}.get(key,"")
static func area_id(run:Dictionary) -> String:
    if run.get("mode","")=="cow":return "cow"
    if run.has("area_id"):return str(run.area_id)
    return "tristram" if "tristram" in str(run.get("area","")).to_lower() else "cathedral"
static func migrate(document: Dictionary) -> Dictionary:
    # Normalize the current development schema; no legacy history reconstruction.
    var progress:Dictionary=document.duplicate(true)
    progress["schema_version"]=2
    progress["total_kills"]=maxi(0,int(progress.get("total_kills",0)))
    progress["has_victory"]=bool(progress.get("has_victory",false))
    progress["gold"]=maxi(0,int(progress.get("gold",0)))
    if not progress.get("shop") is Dictionary:progress["shop"]={}
    for key in SHOP:progress.shop[key]=clampi(int(progress.shop.get(key,0)),0,int(SHOP[key].cap))
    for key in ["completed_areas","completed_difficulties","area_clear_counts","completed_challenges","challenge_counts","enemy_totals","last_played"]:
        if not progress.get(key) is Dictionary:progress[key]={}
    if not progress.get("runs") is Array:progress["runs"]=[]
    return progress
static func difficulty_unlocked(progress:Dictionary,area:String,difficulty:String) -> bool:
    if not area_unlocked(progress,area) or difficulty not in Difficulties.ORDER:return false
    var index:int=Difficulties.ORDER.find(difficulty)
    return index==0 or progress.get("completed_difficulties",{}).get(area,{}).get(Difficulties.ORDER[index-1],false)
static func area_unlocked(progress:Dictionary,key:String) -> bool:
    var order:Array=progress.get("area_order",AREA_ORDER)
    if not order.is_empty() and key==str(order[0]):return true
    if progress.get("completed_difficulties",{}).get(key,{}).get("legendary",false):return true
    var index:=order.find(key)
    return index>0 and progress.get("completed_difficulties",{}).get(order[index-1],{}).get("legendary",false)
static func reward_for_progress(progress:Dictionary,run:Dictionary) -> int:
    var total:=reward(run)-challenge_gold(run)
    var area:=area_id(run)
    if area=="cow" and progress.get("cow_bonus_claimed",false):total=0
    var claimed:Dictionary=progress.get("completed_challenges",{}).get(Difficulties.slot(area,str(run.get("difficulty","easy"))),{})
    var seen:Dictionary={}
    if run.get("outcome","") in ["victory","cow_complete"]:
        for challenge in run.get("challenges",[]):
            var id:String=str(challenge.get("id",""))
            if not id.is_empty() and not seen.has(id) and not claimed.get(id,false) and int(challenge.get("gold",0))==1:
                total+=1;seen[id]=true
    return total
static func challenge_gold(run: Dictionary) -> int:
    if run.get("outcome","") not in ["victory","cow_complete"]:return 0
    var gold:=0
    var seen:Dictionary={}
    for challenge in run.get("challenges",[]):
        var key:String=str(challenge.get("id",""))
        if not key.is_empty() and not seen.has(key) and challenge.get("complete",false) and int(challenge.get("gold",0))==1:
            gold+=1;seen[key]=true
    return gold
static func reward(run: Dictionary) -> int:
    var bonus:=challenge_gold(run)
    if run.get("mode","")=="cow":return bonus+(2 if run.get("outcome","")=="cow_complete" and int(run.get("kills",0))>=500 else 0)
    return maxi(0,int(run.get("kills",0)))+int(maxf(0,float(run.get("seconds",0)))/10)+(50 if run.get("outcome","")=="victory" else 0)+maxi(0,int(run.get("loot_gold",0)))+bonus
static func price(progress: Dictionary,key: String) -> int:
    if not SHOP.has(key):return -1
    return int(SHOP[key].price)*(int(progress.get("shop",{}).get(key,0))+1)
static func purchase(progress: Dictionary,key: String) -> Dictionary:
    var result=migrate(progress)
    if not SHOP.has(key):return {}
    if SHOP[key].has("class") and not unlocked(result,SHOP[key]["class"]):return {}
    var cost:=price(result,key)
    if result.shop[key]>=SHOP[key].cap or result.gold<cost:return {}
    result.gold-=cost;result.shop[key]+=1
    return result
static func unlocked(progress: Dictionary, key: String) -> bool:
    if key in ["warrior","barbarian"]:return true
    if key in ["rogue","amazon"]:return int(progress.get("total_kills",0))>=500
    if key in ["sorcerer","sorceress"]:return bool(progress.get("has_victory",false))
    if key in ["necromancer","assassin"]:return int(progress.get("total_kills",0))>= (1000 if key=="necromancer" else 2000)
    if key in ["paladin","druid"]:
        for area in progress.get("completed_difficulties",{}).values():
            if area.get("hard" if key=="paladin" else "legendary",false):return true
    return false
static func record(progress: Dictionary, run: Dictionary) -> Dictionary:
    var result=migrate(progress)
    result["total_kills"]+=maxi(0,int(run.get("kills",0)))
    result["has_victory"]=result.has_victory or run.get("outcome","")=="victory"
    if not result.has("runs"):result["runs"]=[]
    var completed=run.duplicate(true)
    completed["gold_earned"]=reward_for_progress(result,run)
    result.gold+=completed.gold_earned
    var actual_area:=area_id(run)
    var difficulty:String=str(run.get("difficulty","easy"))
    var area:=Difficulties.slot(actual_area,difficulty)
    if run.get("outcome","") in ["victory","cow_complete"]:
        if actual_area!="cow":
            if not result.completed_difficulties.has(actual_area):result.completed_difficulties[actual_area]={}
            result.completed_difficulties[actual_area][difficulty]=true
        if difficulty=="legendary" or actual_area=="cow":result.completed_areas[actual_area]=true
        result.area_clear_counts[area]=int(result.area_clear_counts.get(area,0))+1
        if not result.completed_challenges.has(area):result.completed_challenges[area]={}
        if not result.challenge_counts.has(area):result.challenge_counts[area]={}
        var seen:Dictionary={}
        for challenge in run.get("challenges",[]):
            var id:String=str(challenge.get("id",""))
            if id.is_empty() or seen.has(id):continue
            seen[id]=true
            if challenge.get("current_complete",challenge.get("complete",false)):result.challenge_counts[area][id]=int(result.challenge_counts[area].get(id,0))+1
            if int(challenge.get("gold",0))>0:result.completed_challenges[area][id]=true
        if area=="cow" and int(run.get("kills",0))>=500:
            result["cow_bonus_claimed"]=true
            result.challenge_counts[area]["cow-500-bonus"]=int(result.challenge_counts[area].get("cow-500-bonus",0))+1
    for enemy in run.get("kill_counts",{}):result.enemy_totals[enemy]=int(result.enemy_totals.get(enemy,0))+int(run.kill_counts[enemy])
    result.runs.append(completed)
    if run.get("outcome","")=="victory" and difficulty=="legendary" and actual_area!="cow":
        var order:Array=result.get("area_order",AREA_ORDER)
        var index:int=order.find(actual_area)
        if index>=0 and index+1<order.size():
            result["last_played"]={"character":run.get("class_id","warrior"),"area":order[index+1],"difficulty":"easy"}
    if result.runs.size()>50:result.runs.pop_front()
    result["best_kills"]=maxi(int(result.get("best_kills",0)),int(run.get("kills",0)))
    result["best_seconds"]=maxf(float(result.get("best_seconds",0)),float(run.get("seconds",0)))
    return result
static func configure(base: Dictionary, key: String, progress: Dictionary={}) -> Dictionary:
    var result=base.duplicate(true)
    result["class_id"]=key
    var actual_class:=key
    key=archetype(key);result["archetype"]=key
    result["weapon"]="sword"
    if key=="rogue":
        result.weapon="bow";result.player.attack_targets=1;result.player.health=75;result.player.speed=250;result.player.damage=18;result.player.cooldown=0.55;result.player.attack_range=240
    elif key=="sorcerer":
        result.weapon="firebolt";result.player.health=65;result.player.speed=210;result.player.damage=32;result.player.cooldown=0.85;result.player.attack_range=200
    if actual_class in ["sorcerer","sorceress","necromancer","druid"]:
        result["spell_kind"]={"necromancer":"bonespear","druid":"firestorm"}.get(actual_class,"firebolt")
    var ranks:Dictionary=progress.get("shop",{})
    result["reroll_limit"]=3+clampi(int(ranks.get("rerolls",0)),0,5)
    result.player["armor"]=int(ranks.get("armor",0))
    result.player.pickup_radius+=10*int(ranks.get("magnet",0))
    if actual_class in ["warrior","barbarian"]:result.player.attack_targets+=int(ranks.get("barbarian_cleave" if actual_class=="barbarian" else "cleave",0))
    if key=="rogue":result.player.damage*=1+0.08*int(ranks.get("amazon_archery" if actual_class=="amazon" else "archery",0))
    result.player["splash_radius"]=65+15*int(ranks.get("sorceress_blast" if actual_class=="sorceress" else "blast",0)) if actual_class in ["sorcerer","sorceress"] else 65
    result.player.health+=10*int(ranks.get("vitality",0))
    result.player.damage*=1+0.05*int(ranks.get("power",0))
    result.player.speed*=1+0.03*int(ranks.get("haste",0))
    if actual_class=="paladin":result.player.health+=20;result.player.damage*=1.1;result.player["regeneration"]=0.5
    elif actual_class=="necromancer":result.player.health=60+10*int(ranks.get("vitality",0));result.player.damage*=0.65;result.player["summon_cap"]=1
    elif actual_class=="assassin":result.player.health=80+10*int(ranks.get("vitality",0));result.player["attack_count"]=2;result.player.damage*=0.75;result.player.speed*=1.1
    elif actual_class=="druid":result.player.attack_range=140;result.player.health=85+10*int(ranks.get("vitality",0));result.player["regeneration"]=1.0;result.player.damage*=0.9
    if actual_class=="paladin":result.player.armor+=int(ranks.get("paladin_guard",0))
    elif actual_class=="necromancer":result.player["ally_damage"]=14*(1+0.2*int(ranks.get("necromancer_minions",0)))
    elif actual_class=="assassin":result.player.damage*=1+0.08*int(ranks.get("assassin_strikes",0))
    elif actual_class=="druid":result.player.regeneration+=0.5*int(ranks.get("druid_recovery",0))
    result.player["xp_multiplier"]=1+0.05*int(ranks.get("learning",0))
    result.player["boost_duration"]=1+0.1*int(ranks.get("duration",0))
    result.player["crit_chance"]=0.05+0.02*int(ranks.get("precision",0))
    result.player["regeneration"]=float(result.player.get("regeneration",0))+0.2*int(ranks.get("recovery",0))
    result.player["kill_heal"]=0.25*int(ranks.get("harvest",0))
    return result

static func achievements(progress:Dictionary) -> Array:
    var cleared:Dictionary=progress.get("completed_areas",{})
    var unique:=0
    for area in progress.get("completed_challenges",{}):unique+=progress.completed_challenges[area].size()
    var result:Array=[
        {"title":"First victory","description":"Complete Cathedral Survival.","complete":not progress.get("completed_difficulties",{}).get("cathedral",{}).is_empty()},
        {"title":"Tristram defender","description":"Complete Tristram Survival.","complete":not progress.get("completed_difficulties",{}).get("tristram",{}).is_empty()},
        {"title":"Rogue unlocked","description":"Defeat 500 enemies across runs.","complete":unlocked(progress,"rogue")},
        {"title":"Sorcerer unlocked","description":"Complete a normal survival area.","complete":unlocked(progress,"sorcerer")},
        {"title":"Treasure hunter","description":"Defeat a treasure goblin.","complete":int(progress.get("enemy_totals",{}).get("goblin",0))>0},
        {"title":"Cow champion","description":"Defeat 500 cows and finish the hunt.","complete":bool(progress.get("cow_bonus_claimed",false))},
        {"title":"Challenge collector","description":"Complete three different area challenges.","complete":unique>=3}
    ]
    var order:Array=progress.get("area_order",AREA_ORDER)
    if not order.is_empty() and str(order[0]).begins_with("d2-area-"):
        result[0].description="Complete Blood Moor Survival."
        result[0].complete=not progress.get("completed_difficulties",{}).get("d2-area-2",{}).is_empty()
        result[1].complete=not progress.get("completed_difficulties",{}).get("d2-area-38",{}).is_empty()
        result[2].title="Amazon unlocked";result[2].complete=unlocked(progress,"amazon")
        result[3].title="Sorceress unlocked";result[3].complete=unlocked(progress,"sorceress")
        for key in progress.get("available_classes",["barbarian","amazon","paladin","necromancer","sorceress"]):
            if key in ["barbarian","amazon","sorceress"]:continue
            result.append({"title":str(key).capitalize()+" unlocked","description":requirement(key)+".","complete":unlocked(progress,key)})
    return result
