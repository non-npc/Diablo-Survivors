extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func take(model:RefCounted,id:String) -> void:
    for choice in model.eligible_upgrades():
        if choice.id==id:model.offered=[choice];model.state="upgrade";model.choose_upgrade(0);return
    require(false,"Upgrade missing: "+id)
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    var warrior=Model.new(Classes.configure(config,"warrior"))
    for i in range(5):take(warrior,"attacks")
    require(warrior.stats.attack_count==6 and warrior.upgrade_ranks.attacks==5,"Extra attacks must have five real ranks")
    for choice in warrior.eligible_upgrades():require(choice.id!="attacks","Maxed upgrade must leave pool")
    take(warrior,"area");take(warrior,"targets")
    require(is_equal_approx(warrior.stats.area_scale,1.1) and warrior.stats.attack_targets==4,"Area and target upgrades must remain distinct")
    var melee=Model.new(Classes.configure(config,"warrior"));melee.spawn_at(melee.player+Vector2(35,0),1000)
    melee.stats.crit_chance=0
    take(melee,"attacks");melee.automatic_attack()
    require(melee.total_damage>=34 and melee.total_damage<=46 and melee.events.filter(func(e):return e.kind=="damage").size()==2,"Extra melee strike must deal another hit")
    var rolls=Model.new(Classes.configure(config,"warrior"));rolls.stats.crit_chance=0
    rolls.spawn_at(rolls.player+Vector2(35,0),10000)
    var seen:Dictionary={}
    for i in range(50):
        rolls.damage_enemy(rolls.enemies[0],20,rolls.player)
        var hit:Dictionary=rolls.events.back()
        require(hit.amount>=17 and hit.amount<=23 and not hit.critical,"Normal damage must vary within the base damage range")
        seen[hit.amount]=true
    require(seen.size()>1,"Successive hits must vary")
    rolls.stats.crit_chance=1;rolls.damage_enemy(rolls.enemies[0],20,rolls.player)
    require(rolls.events.back().critical and rolls.events.back().amount>=26,"Critical hit must carry its marker and increased damage")
    var rogue=Model.new(Classes.configure(config,"rogue"));take(rogue,"multishot");take(rogue,"targets")
    for choice in rogue.eligible_upgrades():require(choice.id not in ["area","bleed","burning"],"Inapplicable class upgrades must be hidden")
    rogue.spawn_at(rogue.player+Vector2(100,0),1000);rogue.automatic_attack()
    require(rogue.projectiles.size()==2 and rogue.projectiles[0].remaining==2,"Arrows must gain count and piercing")
    var source=Model.new(Classes.configure(config,"warrior"))
    take(source,"damage");source.xp=5;source.check_level_up()
    var ids:Dictionary={};var owned:=false;var fresh:=false
    for choice in source.offered:
        require(not ids.has(choice.id),"Choice cards must be unique");ids[choice.id]=true
        owned=owned or choice.previous_tier>0;fresh=fresh or choice.previous_tier==0
    require(owned and fresh,"Choices must mix new and owned upgrades")
    var record={"area_id":"cathedral","outcome":"victory","kills":100,"seconds":480,"challenges":[{"id":"skeleton-100","complete":true,"current_complete":true,"gold":1}]}
    var progress=Classes.record({},record)
    require(not Classes.area_unlocked(progress,"tristram") and Classes.difficulty_unlocked(progress,"cathedral","hard"),"First Easy clear unlocks Hard, not next area")
    var first:int=progress.gold
    progress=Classes.record(progress,record)
    require(progress.gold-first==198 and progress.challenge_counts.cathedral["skeleton-100"]==2,"Repeat challenge must count without paying another gold")
    require(not Classes.area_unlocked(progress,"future-area"),"Repeating a clear must not skip ahead")
    for i in range(55):progress=Classes.record(progress,record)
    progress=Classes.migrate(JSON.parse_string(JSON.stringify(progress)))
    require(progress.challenge_counts.cathedral["skeleton-100"]==57,"Lifetime challenge records must survive history trimming and reload")
    var replay=Model.new(config);replay.config["completed_challenges"]=["skeleton-100"]
    require(replay.challenge_results()[1].unlocked and replay.challenge_results()[0].gold==0,"Replay must advance past already claimed milestone")
    var empty=Model.new(config)
    for upgrade in config.upgrades:empty.upgrade_ranks[upgrade.id]=upgrade.get("max_tier",5)
    empty.xp=5;empty.check_level_up()
    require(empty.offered.size()==1 and empty.offered[0].get("recovery",false),"Exhausted pool must never offer maxed upgrades")
    var poison=Model.new(Classes.configure(config,"rogue"));poison.stats.dot_damage=5
    poison.spawn_at(poison.player+Vector2(100,0),100);poison.damage_enemy(poison.enemies[0],1,poison.player)
    poison.attack_clock=999;poison.spawn_clock=999
    poison.tick(0.5,Vector2.ZERO)
    require(poison.total_damage>1,"Poison must inflict real damage over time")
    var archer=Model.new(Classes.configure(config,"rogue"));archer.stats.attack_targets=2;archer.stats.knockback=0
    archer.spawn_at(archer.player+Vector2(100,0),100);archer.spawn_at(archer.player+Vector2(145,0),100)
    archer.automatic_attack();archer.attack_clock=999;archer.spawn_clock=999
    for i in range(40):archer.tick(0.01,Vector2.ZERO)
    require(archer.enemies.size()==2 and archer.enemies[0].health<100 and archer.enemies[1].health<100,"Piercing must damage distinct enemies along arrow path")
    var cow_record={"mode":"cow","outcome":"cow_complete","kills":500,"seconds":480}
    var cow_progress=Classes.record({},cow_record)
    cow_progress=Classes.record(cow_progress,cow_record)
    require(cow_progress.gold==2 and cow_progress.challenge_counts.cow["cow-500-bonus"]==2,"Cow challenge reward must be once-only while repetitions remain recorded")
    if not failed:print("GAMESHIFT_TIERS_PROGRESSION_OK")
    quit(1 if failed else 0)
