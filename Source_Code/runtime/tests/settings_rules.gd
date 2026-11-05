extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_settings")
func check_settings() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false);scene.smoke=true
    if scene.manifest.get("music",{}).has("menu"):
        require(scene.music_path==scene.manifest.music.menu.path,"Main menu must use only the intro track")
        scene.start_class(scene.manifest.get("default_class","warrior"))
        require(scene.music_path==scene.manifest.music[scene.selected_arena].path,"Starting a run must switch to its regional soundtrack")
        scene.show_classes()
        require(scene.music_path==scene.manifest.music.menu.path,"Returning to menu must restore the intro track")
    scene.change_preference("sfx_volume",0.25)
    require(is_equal_approx(scene.audio_bank.volume,0.25),"SFX slider must update audio volume")
    scene.music_player.stream=AudioStreamGenerator.new();scene.music_player.play()
    scene.change_preference("music_enabled",false)
    require(scene.music_player.stream_paused,"Music toggle must pause music")
    scene.change_preference("music_volume",0.35)
    require(is_equal_approx(db_to_linear(scene.music_player.volume_db),0.35),"Music slider must adjust volume")
    scene.model.state="playing";scene.hp_flash=0.2
    scene.change_preference("screen_shake",false);scene.update_hit_feedback()
    require(scene.position==Vector2.ZERO and scene.hit_overlay.color.a>0,"Shake disabled must preserve red damage flash")
    scene.change_preference("screen_shake",true);scene.update_hit_feedback()
    require(scene.position.length()>0,"Shake enabled must move the view on damage")
    scene.model.state="paused";scene.show_settings()
    require(scene.model.state=="settings" and scene.settings_return=="paused","Settings opened during a run must preserve pause")
    scene.queue_free()
    if not failed:print("GAMESHIFT_SETTINGS_OK")
    quit(1 if failed else 0)
