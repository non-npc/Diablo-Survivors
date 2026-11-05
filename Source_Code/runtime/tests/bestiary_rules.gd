extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_bestiary")
func check_bestiary() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false);scene.smoke=true
    var order:Array=scene.manifest.area_order
    var fresh:Dictionary=Classes.migrate({"area_order":order})
    require(Classes.area_unlocked(fresh,str(order[0])),"First D2 area must start unlocked")
    require(not Classes.area_unlocked(fresh,str(order[1])),"Second D2 area must remain locked")
    fresh.completed_difficulties[order[0]]={"legendary":true}
    require(Classes.area_unlocked(fresh,str(order[1])),"Completing Legendary must unlock the next D2 area")
    for key in scene.manifest.arenas:
        var area:Dictionary=scene.manifest.arenas[key]
        for kind in area.enemy_roster:
            require(scene.manifest.enemy_visuals.has(kind) and area.enemy_definitions.has(kind),"Every area enemy needs imported graphics and a profile: "+kind)
        for challenge in area.challenges:require(challenge.enemy in area.enemy_roster,"Challenges must match area enemies")
    for key in ["d2-area-2","d2-area-41","d2-area-76","d2-area-104",str(scene.manifest.final_arena)]:
        scene.selected_arena=key;scene.start_class("barbarian")
        require(scene.model.config.area_id==key and scene.model.state=="playing","Each Act must launch with its own roster")
    scene.progress.total_kills=1000;scene.start_class("necromancer")
    require(scene.selected_class=="necromancer" and scene.visuals.has("skeleton"),"Necromancer must load the original skeleton minion after the registry changes")
    require(scene.manifest.has("minion_visual"),"Necromancer skeleton art must remain separate from the enemy registry")
    var config:Dictionary=scene.manifest.configuration.duplicate(true)
    var unique_area:Dictionary=scene.manifest.arenas["d2-area-25"]
    config.enemy_roster=unique_area.enemy_roster;config.enemy_definitions=unique_area.enemy_definitions;config.unique_roster=unique_area.unique_roster;config.boss=""
    var model=Model.new(config);model.spawn_clock=999;model.attack_clock=999;model.elapsed=float(config.duration_seconds)*0.55
    model.tick(0.01,Vector2.ZERO)
    var unique_count:int=model.enemies.filter(func(enemy):return str(enemy.kind).begins_with("d2-unique-")).size()
    require(unique_count==1,"The Countess must appear in her own area")
    model.tick(0.01,Vector2.ZERO)
    require(model.enemies.filter(func(enemy):return str(enemy.kind).begins_with("d2-unique-")).size()==1,"Named uniques must spawn only once per run")
    var chamber:Dictionary=scene.manifest.arenas["d2-area-73"]
    config.enemy_roster=[chamber.boss];config.enemy_definitions=chamber.enemy_definitions;config.unique_roster=[];config.boss=chamber.boss
    model=Model.new(config);model.elapsed=5;model.spawn_clock=999;model.attack_clock=999;model.tick(0.01,Vector2.ZERO)
    require(model.enemies.size()==1 and model.enemies[0].kind==chamber.boss,"A boss-only chamber must begin its encounter without minutes of empty waiting")
    model.tick(0.01,Vector2.ZERO);model.enemies[0].health=0;model.tick(0.01,Vector2.ZERO)
    require(model.enemies.is_empty(),"A boss endurance chamber must give a recovery interval")
    model.tick(60.1,Vector2.ZERO)
    require(model.enemies.size()==1 and model.enemies[0].kind==chamber.boss,"Boss endurance must keep one correct boss active at a time")
    scene.queue_free()
    if not failed:print("DIABLO_SURVIVORS_BESTIARY_OK")
    quit(1 if failed else 0)
