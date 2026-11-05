extends SceneTree
func _initialize() -> void:call_deferred("capture")
func photo(path:String) -> void:
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(path)
func capture() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    var args:=OS.get_cmdline_user_args()
    scene.manifest.save_path=args[args.find("--test-progress")+1]
    var prefix:String=args[args.find("--capture")+1]
    scene.read_progress();scene.set_physics_process(false);scene.selected_arena="cathedral";scene.show_classes();scene.queue_redraw()
    await photo(prefix+"-menu.png")
    scene.start_class("warrior");scene.model.offered=[]
    for choice in scene.model.eligible_upgrades():
        if choice.id in ["attacks","area","targets"]:scene.model.offered.append(choice)
    scene.model.state="upgrade";scene.update_ui();scene.queue_redraw()
    await photo(prefix+"-upgrades.png")
    var clear={"area_id":"cathedral","area":"Cathedral Survival","outcome":"victory","kills":500,"seconds":480,"kill_counts":{"skeleton":499,"goblin":1},"challenges":[{"id":"skeleton-100","complete":true,"current_complete":true,"gold":1}]}
    scene.write_progress(scene.Classes.record(scene.progress,clear))
    scene.write_progress(scene.Classes.record(scene.progress,clear))
    scene.show_classes();scene.select_level("tristram");scene.start_class("warrior");scene.queue_redraw()
    await photo(prefix+"-tristram.png")
    scene.achievement_tab=1;scene.show_achievements();scene.queue_redraw()
    await photo(prefix+"-records.png")
    scene.queue_free();print("GAMESHIFT_MENU_VISUAL_OK");quit()
