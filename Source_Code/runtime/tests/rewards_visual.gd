extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    var args:=OS.get_cmdline_user_args()
    scene.manifest.save_path=args[args.find("--test-progress")+1]
    scene.read_progress();scene.show_classes()
    scene.set_physics_process(false);scene.update_ui();scene.queue_redraw()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(args[args.find("--capture")+1]+"-classes.png")
    scene.start_class("warrior")
    scene.model.elapsed=480;scene.model.kills=137;scene.model.kill_counts={"skeleton":136,"goblin":1}
    scene.model.collected_xp=180;scene.model.pickup_counts={"xp":93,"healing":4,"treasure":1};scene.model.loot_gold=25;scene.model.healing_received=35
    scene.model.state="victory";scene.update_ui();scene.queue_redraw()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(args[args.find("--capture")+1]+"-rewards.png")
    scene.queue_free();print("GAMESHIFT_REWARDS_VISUAL_OK");quit()
