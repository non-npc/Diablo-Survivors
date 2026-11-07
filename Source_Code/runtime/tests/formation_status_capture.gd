extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    var args:=OS.get_cmdline_user_args()
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false);scene.smoke=true
    scene.start_class(scene.manifest.get("default_class","barbarian"));scene.smoke=false
    scene.model.enemies.clear();scene.model.allies.clear();scene.model.powerups.clear()
    scene.model.auto_attack_enabled=false;scene.model.spawn_clock=999
    var kinds:Array=scene.model.config.get("enemy_roster",["skeleton"])
    var kind:String=kinds[0]
    scene.model.formation_director.spawn(scene.model,{"center":scene.model.player,"shape":"circle","angle":0.0,"count":16,"kind":kind,"element":"poison","elite":true})
    scene.model.formation_director.active.age=2.0
    for enemy in scene.model.enemies:
        if enemy.get("miniboss",false):enemy.position+=Vector2(110,20)
        scene.Ailments.apply(enemy,"poison",1)
    scene.Ailments.apply(scene.model.player_conditions,"fire",2)
    scene.Ailments.apply(scene.model.player_conditions,"lightning",1)
    scene.camera=scene.model.player
    scene.event_notice="Poison formation — elite encounter";scene.notice_clock=5
    scene.update_powerup_particles();scene.update_ui();scene.queue_redraw()
    await process_frame;await process_frame;RenderingServer.force_draw(false);await process_frame
    assert(scene.particle_fx.smoke.visible and scene.ailment_hud.text.contains("Scorched"))
    root.get_texture().get_image().save_png(args[args.find("--capture-path")+1])
    print("FORMATION_STATUS_VISUAL_OK");quit()
