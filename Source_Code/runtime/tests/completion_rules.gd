extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_completion")
func check_completion() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.smoke=true;scene.start_class("warrior");scene.smoke=false
    scene.manifest.save_path=ProjectSettings.globalize_path("res://../.local/completion-test-"+str(Time.get_ticks_usec())+".json")
    scene.model.elapsed=float(scene.model.config.duration_seconds)-0.01
    for index in range(300):scene.model.spawn_at(scene.model.player+Vector2(100,0),100)
    var started:=Time.get_ticks_usec()
    scene.model.tick(0.02,Vector2.ZERO);scene.update_ui()
    print("Completion panel main-thread work: %.2f ms" % ((Time.get_ticks_usec()-started)/1000.0))
    require(scene.model.state=="victory" and scene.overlay.visible,"Rewards must show immediately at expiry")
    require(scene.model.events.filter(func(event):return event.kind=="run_complete").size()==1,"Expiry must emit one completion sound event")
    require(scene.audio_bank.streams.has("run.complete"),"Completion chime must be preloaded")
    require(scene.reward_calculation_scheduled and not scene.reward_save_attempted,"Completion panel must appear before rewards are calculated")
    for frame in range(300):
        await process_frame
        scene.poll_reward_save()
        if scene.saved:break
    require(scene.saved and FileAccess.file_exists(scene.progress_path()),"Worker must finish saving earned rewards")
    var run_count:int=scene.progress.runs.size()
    scene.ui_state="";scene.update_ui()
    require(scene.progress.runs.size()==run_count and not scene.reward_save_pending,"Panel refresh must not award or save twice")
    DirAccess.remove_absolute(scene.progress_path())
    scene.queue_free();await process_frame
    if not failed:print("GAMESHIFT_COMPLETION_OK")
    quit(1 if failed else 0)
