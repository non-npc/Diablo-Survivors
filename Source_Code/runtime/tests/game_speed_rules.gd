extends SceneTree
func _initialize() -> void:call_deferred("check_speed")
func check_speed() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.smoke=true;scene.start_class("warrior");scene.smoke=false;scene.audio_bank.set_muted(true)
    scene.model.config.powerups_enabled=false;scene.model.spawn_clock=999;scene.model.attack_clock=999
    assert(scene.game_speed==1.0 and scene.speed_reset.disabled,"Each run must start at normal speed")
    for index in range(10):scene.change_game_speed(1)
    assert(scene.game_speed==10.0 and scene.speed_plus.disabled,"Speed must cap at 10x")
    var before:float=scene.model.elapsed
    scene._physics_process(0.1)
    assert(absf(scene.model.elapsed-before-1.0)<0.001,"10x speed must advance combat and countdown by one second per tenth-second")
    scene.model.state="paused";before=scene.model.elapsed;scene._physics_process(0.1)
    assert(scene.model.elapsed==before,"Speed must not advance a paused run")
    scene.model.state="upgrade";scene._physics_process(0.1)
    assert(scene.model.elapsed==before,"Upgrade selection must remain paused at high speed")
    scene.speed_reset.pressed.emit()
    assert(scene.game_speed==1.0 and scene.speed_value.text=="1×","Reset button must immediately restore 1x")
    scene.model.state="playing";scene._physics_process(0.1)
    assert(absf(scene.model.elapsed-before-0.1)<0.001,"Reset must restore normal countdown rate")
    for index in range(10):scene.change_game_speed(-1)
    assert(scene.game_speed==1.0 and scene.speed_minus.disabled,"Speed must not fall below 1x")
    scene.set_game_speed(10.0)
    scene.model.elapsed=float(scene.model.config.duration_seconds)-0.05
    scene.model.tick(0.06,Vector2.ZERO)
    assert(scene.model.state=="victory","Speed must preserve normal run completion")
    scene.queue_free();await process_frame
    print("GAME_SPEED_OK");quit()
