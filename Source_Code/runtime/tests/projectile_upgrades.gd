extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func take(model:RefCounted,id:String) -> void:
    for choice in model.eligible_upgrades():
        if choice.id==id:model.offered=[choice];model.state="upgrade";model.choose_upgrade(0);return
    require(false,"Missing upgrade: "+id)
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    for key in ["rogue","sorcerer"]:
        var model=Model.new(Classes.configure(config,key));model.spawn_clock=999;model.attack_clock=999
        take(model,"pierce")
        model.stats.crit_chance=0
        model.spawn_at(model.player+Vector2(100,0),1000);model.spawn_at(model.player+Vector2(220,0),1000)
        for enemy in model.enemies:enemy.speed=0
        model.automatic_attack()
        for step in range(40):model.tick(0.02,Vector2.ZERO)
        require(model.enemies[0].health<1000 and model.enemies[1].health<1000,"Pierce must damage a target behind the first: "+key)
        for tier in range(4):take(model,"multishot")
        model.projectiles.clear();model.automatic_attack()
        require(model.projectiles.size()==5,"Max multi-shot must fire exactly five projectiles: "+key)
        for upgrade in model.eligible_upgrades():require(upgrade.id!="multishot","Maxed multi-shot must leave the pool")
    config.director.max_enemies=1000
    var capped=Model.new(config)
    for index in range(350):capped.spawn_at(capped.player+Vector2(100,0),10)
    require(capped.enemies.size()==300,"Spawn count must never exceed 300")
    capped.enemies.pop_back();capped.spawn_at(capped.player+Vector2(100,0),10)
    require(capped.enemies.size()==300,"A freed enemy slot must accept a replacement")
    if not failed:print("GAMESHIFT_PROJECTILE_UPGRADES_OK")
    quit(1 if failed else 0)
