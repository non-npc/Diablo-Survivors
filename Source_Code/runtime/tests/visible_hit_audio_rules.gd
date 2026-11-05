extends SceneTree
func _initialize() -> void:call_deferred("check_audio")
func check_audio() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate()
    root.add_child(scene);scene.set_physics_process(false)
    scene.smoke=true;scene.start_class("warrior")
    scene.audio_bank.set_muted(false)
    scene.audio_bank.streams["skeleton.death"]=[scene.audio_bank.completion_chime()]
    scene.audio_bank.streams["skeleton.hit"]=[scene.audio_bank.completion_chime()]
    var hidden_position:Vector2=scene.camera+Vector2(0,390)
    scene.sound_event({"kind":"damage","actor":"skeleton","fatal":true,"impact":true,"position":hidden_position})
    assert(not scene.audio_bank.hit_sequence_active,"Offscreen projectile hits must not start hit/death audio")
    scene.sound_event({"kind":"kill","actor":"skeleton","position":hidden_position})
    assert(not scene.audio_bank.last_played.has("skeleton.death"),"Offscreen deaths must remain silent")
    scene.sound_event({"kind":"damage","actor":"skeleton","fatal":false,"impact":true,"position":hidden_position})
    assert(not scene.audio_bank.last_played.has("skeleton.hit"),"Offscreen enemy reactions must remain silent")
    scene.sound_event({"kind":"damage","actor":"skeleton","fatal":true,"impact":true,"position":scene.camera+Vector2(100,0)})
    assert(scene.audio_bank.hit_sequence_active,"Visible hits must still play hit/death audio")
    scene.camera+=Vector2(0,500)
    scene.audio_bank._process(0.2)
    assert(not scene.audio_bank.voices[8].playing,"An active hit must stop when its source leaves the screen")
    assert(not scene.audio_bank.voices[2].playing and not scene.audio_bank.voices[3].playing,"Delayed death audio must recheck visibility before playback")
    scene.audio_bank.stop_all()
    scene.sound_event({"kind":"goblin_spawn","position":hidden_position})
    assert(scene.audio_bank.last_played.has("goblin.spawn"),"Goblin spawn announcement must still work offscreen")
    scene.queue_free();await process_frame
    print("VISIBLE_HIT_AUDIO_OK");quit()
