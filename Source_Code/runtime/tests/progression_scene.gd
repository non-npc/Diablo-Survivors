extends SceneTree
var failed := false
func require(condition: bool,message: String) -> void:
    if not condition:push_error(message);failed=true
func _initialize() -> void:
    call_deferred("check_scene")
func check_scene() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate()
    root.add_child(scene)
    var args:=OS.get_cmdline_user_args()
    var path:String=args[args.find("--test-progress")+1]
    scene.manifest.save_path=path
    scene.read_progress();scene.show_classes()
    require(scene.model.state=="classes","Startup must display class selection")
    scene.start_class("rogue")
    require(scene.model.state=="classes","Locked class must not start")
    scene.start_class("warrior")
    scene.model.spawn_clock=999;scene.model.attack_clock=999
    var planted:Vector2=scene.model.player
    scene.attack_animation=0.4
    for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
        var before:Vector2=scene.model.player
        scene.model.tick(0.02,scene.movement_for_animation(direction))
        require(scene.model.player!=before,"Attack animation must allow movement in every direction")
    planted=scene.model.player
    scene.attack_animation=0
    scene.model.tick(0.02,scene.movement_for_animation(Vector2.RIGHT))
    require(scene.model.player.x>planted.x,"Movement must resume when attack animation ends")
    scene.show_character()
    var sheet_elapsed:float=scene.model.elapsed
    scene._physics_process(0.05)
    require(scene.model.state=="character" and scene.model.elapsed==sheet_elapsed,"Character sheet must pause gameplay")
    scene.show_character()
    require(scene.model.state=="playing","Closing character sheet must restore play")
    scene.model.kills=500;scene.model.elapsed=480;scene.model.state="victory"
    scene.save_run();scene.save_run()
    scene.read_progress()
    require(scene.progress.total_kills==500 and scene.progress.gold==598 and scene.progress.runs.size()==1,"Finished run must save rewards exactly once")
    scene.show_shop();scene.buy("power")
    scene.read_progress()
    require(scene.progress.gold==523 and scene.progress.shop.power==1,"Shop purchase must persist")
    scene.manifest.save_path=path+"/blocked.json"
    scene.buy("power")
    require(scene.progress.gold==523 and scene.progress.shop.power==1,"Failed save must not charge purchase")
    scene.manifest.save_path=path
    scene.show_classes();scene.start_class("rogue")
    require(scene.model.config.weapon=="bow" and is_equal_approx(scene.model.stats.damage,18*1.05),"Unlocked Rogue must receive permanent damage")
    scene.show_classes();scene.start_class("sorcerer")
    require(scene.model.config.weapon=="firebolt","Victory must enable Sorcerer in UI")
    if args.has("--capture"):
        scene.show_character() if args.has("--capture-character") else scene.show_shop()
        if not args.has("--capture-character"):scene.shop_category="Class";scene.ui_state="";scene.update_ui()
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(args[args.find("--capture")+1])
    scene.queue_free()
    if not failed:print("GAMESHIFT_PROGRESSION_SCENE_OK")
    quit(1 if failed else 0)
