extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(condition:bool,message:String) -> void:
    if not condition:push_error(message);failed=true
func _initialize() -> void:
    call_deferred("check_events")
func check_events() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config["rare_events"]={"portal_chance":1.0,"spawn_chance":0.0}
    var sequence=Model.new(config)
    sequence.kill_counts={"skeleton":99}
    require(sequence.challenge_results()[0].unlocked and not sequence.challenge_results()[1].unlocked,"Only current challenge may unlock")
    sequence.kill_counts.skeleton=100
    require(sequence.challenge_results()[0].complete and sequence.challenge_results()[1].unlocked,"Completion must unlock next challenge")
    require(Classes.challenge_gold(sequence.summary())==0,"Challenge must not pay before expiry")
    sequence.kill_counts.skeleton=250;sequence.elapsed=480;sequence.state="victory"
    require(Classes.challenge_gold(sequence.summary())==2,"Completed challenges must each pay one gold")
    sequence.state="dead"
    require(Classes.challenge_gold(sequence.summary())==0,"Early defeat must not pay challenge bonus")
    var model=Model.new(config)
    require(model.spawn_goblin(model.player+Vector2(60,0)),"Goblin must spawn")
    require(not model.spawn_goblin(model.player),"Only one goblin may be active")
    var goblin:Dictionary=model.enemies.back()
    var start:Vector2=goblin.position
    model.update_goblin(goblin,0.1)
    require(goblin.position.distance_to(model.player)>start.distance_to(model.player),"Goblin must flee")
    model.damage_enemy(goblin,999,model.player)
    require(not model.spawn_goblin(model.player),"A defeated goblin must not be replaced by another in the same run")
    require(model.kills==1 and not model.portal.is_empty(),"Forced rare roll must open portal")
    require(model.pickups.back().gold==25 and model.pickups.back().xp==30,"Goblin must drop treasure")
    model.pickups.back().position=model.player
    model.tick(0.01,Vector2.ZERO)
    require(model.collected_xp>=30 and model.pickup_counts.get("treasure",0)==1 and model.kill_counts.get("goblin",0)==1,"Rewards must track defeated enemies and collected loot")
    require(model.loot_gold==25,"Collected treasure must enter run rewards")
    require(Classes.reward(model.summary())>=26,"Survival rewards must include collected loot")
    var cow_config=config.duplicate(true);cow_config["mode"]="cow";cow_config.duration_seconds=480
    cow_config.director.max_enemies=220;cow_config.director.spawn_interval=0.4
    var hunt=Model.new(cow_config);hunt.health=100000;hunt.stats.max_health=100000;hunt.base_stats.max_health=100000
    hunt.kills=500;hunt.elapsed=100;hunt.spawn_clock=0
    hunt.tick(0.01,Vector2.ZERO)
    require(hunt.state=="playing" and hunt.enemies.back().kind=="cow","500 kills must not end hunt or stop spawning")
    require(Classes.reward(hunt.summary())==0,"Cow reward must wait for countdown")
    hunt.elapsed=479.95;hunt.tick(0.1,Vector2.ZERO)
    require(hunt.state=="cow_complete" and Classes.reward(hunt.summary())==2,"Timer zero must award exactly two gold for 500 kills")
    require(Classes.reward({"mode":"cow","outcome":"cow_complete","kills":499})==0,"499 cows must not earn challenge reward")
    require(Classes.reward({"mode":"cow","outcome":"dead","kills":500})==0,"Early defeat must not earn timed reward")
    var clock=Model.new(cow_config);clock.health=100000;clock.stats.max_health=100000;clock.base_stats.max_health=100000
    for i in range(480):
        if clock.state=="upgrade":clock.choose_upgrade(0)
        clock.tick(1,Vector2.ZERO)
    require(clock.state=="cow_complete" and is_equal_approx(clock.elapsed,480),"Full eight-minute simulation must finish at timer zero")
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    var args:=OS.get_cmdline_user_args();scene.manifest.save_path=args[args.find("--test-progress")+1]
    scene.read_progress();scene.start_class("warrior")
    scene.model.elapsed=42;scene.model.portal={"position":scene.model.player,"remaining":60}
    var base=scene.model
    scene.enter_cow_event()
    require(scene.cow_event() and scene.model.config.duration_seconds==480,"Portal must start eight-minute cow event")
    scene.model.tick(0.1,Vector2.ZERO)
    require(base.elapsed==42,"Base survival timer must freeze during event")
    scene.model.elapsed=419;scene.update_ui()
    require(scene.cow_timer.text=="01:01","Cow countdown must show remaining minute and seconds")
    var normal_color:Color=scene.cow_timer.get_theme_color("font_color")
    scene.model.elapsed=420;scene.update_ui()
    require(scene.cow_timer.text=="01:00" and scene.cow_timer.get_theme_color("font_color").g<normal_color.g,"Final minute must turn countdown red")
    scene.model.kills=500;scene.model.elapsed=480;scene.model.state="cow_complete"
    scene.save_run();scene.save_run()
    require(scene.progress.gold==2 and scene.progress.runs.size()==1,"Event reward must save exactly once")
    var finished:Vector2=scene.model.player
    scene.model.tick(1,Vector2.RIGHT)
    require(scene.model.player==finished and scene.model.elapsed==480,"Area completion must stop gameplay at zero")
    scene.return_from_cow_event()
    require(scene.model==base and scene.model.elapsed==42 and scene.model.state=="playing","Returning must restore the paused survival run")
    require(scene.model.portal.is_empty(),"Portal must be consumed")
    if args.has("--capture"):
        scene.enter_cow_event(true);scene.model.spawn_at(scene.model.player+Vector2(100,20),18);scene.model.enemies.back()["kind"]="cow"
        scene.model.spawn_at(scene.model.player+Vector2(-130,-50),60);scene.model.enemies.back()["kind"]="goblin"
        scene.model.enemies.back()["lifetime"]=45.0
        scene.model.elapsed=425
        scene.set_physics_process(false)
        scene.update_ui();scene.queue_redraw()
        await process_frame;await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(args[args.find("--capture")+1])
    scene.queue_free()
    if not failed:print("GAMESHIFT_RARE_EVENTS_OK")
    quit(1 if failed else 0)
