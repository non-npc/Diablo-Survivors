extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_zones")
func check_zones() -> void:
    var args:=OS.get_cmdline_user_args()
    var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--zone-manifest")+1]))
    require(document.arenas.size()==22,"Base game must have 16 floors, town and five quest zones")
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.arena_cache.clear();scene.manifest=document;scene.manifest.save_path=args[args.find("--test-progress")+1]
    scene.progress=Classes.migrate({});scene.audio_bank.set_muted(true)
    for i in range(Classes.AREA_ORDER.size()):
        var key:String=Classes.AREA_ORDER[i]
        require(Classes.area_unlocked(scene.progress,key),"Immediate next area must unlock: "+key)
        if i+1<Classes.AREA_ORDER.size():require(not Classes.area_unlocked(scene.progress,Classes.AREA_ORDER[i+1]),"Clearing a predecessor must not skip the next area")
        scene.selected_arena=key;require(scene.apply_arena(key),"Zone must load: "+key);scene.restart()
        require(scene.model.navigation!=null and scene.model.navigation.available.size()>100,"Every zone must have navigable terrain: "+key)
        require(scene.model.navigation.clear_walk(scene.model.player,scene.model.player),"Spawn must have collision clearance: "+key)
        scene.model.stats.max_health=100000;scene.model.health=100000
        for tick in range(60):scene.model.tick(0.05,Vector2.ZERO)
        require(not scene.model.enemies.is_empty(),"Zone must support enemy spawning: "+key)
        for enemy in scene.model.enemies:
            require(enemy.kind in document.arenas[key].enemy_roster,"Spawned enemies must belong to the zone roster: "+key)
        for challenge in document.arenas[key].challenges:
            require(challenge.enemy in document.arenas[key].enemy_roster or challenge.enemy==document.arenas[key].boss or (key in ["cathedral","tristram"] and challenge.enemy=="skeleton"),"Challenges must match zone enemies")
        if not str(document.arenas[key].boss).is_empty():
            scene.model.elapsed=360;scene.model.spawn_directed()
            require(scene.model.boss_spawned and scene.model.enemies.back().kind==document.arenas[key].boss,"Named zone boss must spawn once late in the run")
        scene.progress.completed_difficulties[key]={"easy":true,"hard":true,"legendary":true}
        require(scene.arena_cache.size()<=3,"Zone texture cache must remain bounded")
        print("ZONE_OK: "+key)
    scene.queue_free()
    if not failed:print("GAMESHIFT_ZONES_OK")
    quit(1 if failed else 0)
