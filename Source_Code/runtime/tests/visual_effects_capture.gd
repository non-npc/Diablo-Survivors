extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.audio_bank.set_muted(true);scene.smoke=true;scene.start_class(scene.manifest.get("default_class","warrior"));scene.smoke=false;scene.model.elapsed=45
    scene.model.haste_clock=29;scene.model.magnet_clock=24
    if OS.get_cmdline_user_args().has("--bestiary-zone"):
        var arguments:=OS.get_cmdline_user_args()
        scene.smoke=true;scene.selected_arena=arguments[arguments.find("--bestiary-zone")+1]
        scene.start_class(scene.manifest.get("default_class","warrior"));scene.smoke=false
        var roster:Array=scene.model.config.enemy_roster
        for index in range(roster.size()):
            scene.model.spawn_at(scene.model.player+Vector2(-360+(index%5)*180,-160+(index/5)*180),100,false,str(roster[index]))
    if OS.get_cmdline_user_args().has("--edge"):
        scene.model.player=Vector2(2,scene.model.arena.size.y/2);scene.camera=scene.model.player
    scene.model.powerups=[]
    if OS.get_cmdline_user_args().has("--goblin"):
        scene.model.spawn_goblin(scene.model.player+Vector2(220,90))
    if OS.get_cmdline_user_args().has("--ranged"):
        var index:=0
        for kind in ["skeleton_archer","skeleton_mage","fallen_shaman","quill_rat"]:
            if not scene.visuals.has(kind):scene.visuals[kind]=scene.load_visual(scene.manifest.enemy_visuals[kind])
            scene.model.spawn_at(scene.model.player+Vector2(-260+index*170,-100),100,false,kind);index+=1
    for item in [{"kind":"healing","offset":Vector2(100,0)},{"kind":"haste","offset":Vector2(-100,50)},{"kind":"magnet","offset":Vector2(180,100)}]:
        scene.model.powerups.append({"kind":item.kind,"position":scene.model.player+item.offset,"active":true,"respawn":0})
    scene.impact_event({"kind":"kill","actor":"zombie-0","position":scene.model.player+Vector2(130,-40)})
    if not scene.impact_particles.is_empty():scene.impact_particles.back().age=0.4
    if OS.get_cmdline_user_args().has("--shop"):
        scene.progress.gold=371;scene.progress.shop.cleave=1
        scene.shop_category="Class";scene.show_shop()
        scene.shop_message="Purchased Warrior: sweeping blade. Applies to your next run."
        scene.ui_state=""
    if OS.get_cmdline_user_args().has("--difficulty-preview"):
        scene.progress.completed_difficulties["cathedral"]={"easy":true,"hard":true}
        scene.selected_difficulty="legendary"
        scene.show_classes()
    if OS.get_cmdline_user_args().has("--menu"):scene.show_classes()
    if OS.get_cmdline_user_args().has("--reset"):scene.show_reset_confirmation()
    if OS.get_cmdline_user_args().has("--settings"):scene.show_settings()
    if OS.get_cmdline_user_args().has("--upgrade"):
        scene.model.xp=scene.model.xp_needed;scene.model.check_level_up()
    if OS.get_cmdline_user_args().has("--character"):scene.show_character()
    scene.update_powerup_particles()
    if OS.get_cmdline_user_args().has("--hud-stress"):
        scene.model.kills=99999;scene.model.level=99;scene.model.wave=99;scene.model.surge_spawned=99999
    scene.update_ui();scene.queue_redraw()
    if OS.get_cmdline_user_args().has("--hit"):
        scene.hp_flash=0.18;scene.update_hit_feedback()
    await process_frame;await process_frame
    RenderingServer.force_draw(false)
    await process_frame
    var args:=OS.get_cmdline_user_args()
    var output:String=args[args.find("--capture-path")+1] if args.has("--capture-path") else "user://effects-preview.png"
    root.get_texture().get_image().save_png(output)
    print("GAMESHIFT_VISUAL_EFFECTS_OK");quit()
