extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    var args:=OS.get_cmdline_user_args()
    var cls:String=args[args.find("--caster")+1]
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.audio_bank.set_muted(true);scene.smoke=true
    scene.progress["total_kills"]=2000;scene.progress["has_victory"]=true
    scene.progress["completed_difficulties"]={scene.selected_arena:{"hard":true,"legendary":true}}
    scene.start_class(cls);scene.smoke=false
    assert(scene.selected_class==cls and scene.model.config.get("spell_kind","")=={"necromancer":"bonespear","druid":"firestorm"}.get(cls,"firebolt"))
    scene.model.auto_attack_enabled=false;scene.model.spawn_clock=999;scene.model.attack_clock=0
    scene.model.stats.summon_cap=0;scene.model.allies.clear()
    var aim:=Vector2.RIGHT.rotated(deg_to_rad(float(args[args.find("--aim-angle")+1]))) if args.has("--aim-angle") else Vector2.RIGHT
    scene.model.spawn_at(scene.model.player+aim*float(scene.model.stats.attack_range)*0.9,10000);scene.model.enemies.back().speed=0
    scene.model.automatic_attack()
    for i in range(15 if cls=="druid" else 18):scene.model.tick(0.02,Vector2.ZERO)
    scene.camera=scene.model.player;scene.facing=6;scene.player_state="attack";scene.player_age=0.15;scene.attack_animation_span=0.5
    scene.update_powerup_particles();scene.update_ui();scene.queue_redraw()
    await process_frame;await process_frame;RenderingServer.force_draw(false);await process_frame
    root.get_texture().get_image().save_png(args[args.find("--capture-path")+1])
    print("CASTER_VISUAL_OK "+cls);quit()
