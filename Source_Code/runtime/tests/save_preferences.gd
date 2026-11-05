extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func game() -> Node2D:
    var scene=load("res://scenes/survival.tscn").instantiate()
    root.add_child(scene);scene.set_physics_process(false)
    scene.manifest.arenas["tristram"]=scene.manifest.arenas.cathedral.duplicate(true)
    return scene
func _initialize() -> void:call_deferred("check_saves")
func check_saves() -> void:
    var scene=game()
    var initial:Dictionary=scene.Classes.migrate({"gold":5000,"total_kills":600,"has_victory":true,"completed_difficulties":{"cathedral":{"easy":true,"hard":true,"legendary":true}}})
    require(scene.write_progress(initial),"Test profile must save")
    var stale=game()
    scene.show_shop();scene.buy("haste");scene.buy("haste")
    stale.show_shop();stale.buy("haste")
    scene.read_progress()
    require(scene.progress.shop.haste==3 and scene.progress.gold==4640,"Consecutive purchases across windows must retain all ranks and correct gold")
    require(scene.progress.purchase_history.size()==3,"Purchases must retain auditable rank and cost records")
    scene.selected_arena="tristram";scene.start_class("rogue")
    require(scene.progress.last_played=={"character":"rogue","area":"tristram","difficulty":"easy"},"Play must save selections immediately")
    var reopened=game();reopened.restore_last_played();reopened.show_classes()
    require(reopened.selected_class=="rogue" and reopened.selected_arena=="tristram","Reopened game must restore character and area")
    require(reopened.progress.shop.haste==3 and reopened.progress.gold==4640,"Reopened shop must keep purchased ranks and balance")
    reopened.start_class("rogue")
    require(is_equal_approx(reopened.model.stats.speed,250*1.09),"Reloaded permanent ranks must apply to next run")
    reopened.progress.last_played={"character":"unknown","area":"hell-16"};reopened.restore_last_played()
    require(reopened.selected_class=="warrior" and reopened.selected_arena=="cathedral","Invalid or locked stored selections must fall back safely")
    reopened.show_classes()
    var before:=FileAccess.get_file_as_string(reopened.progress_path())
    reopened.show_reset_confirmation();reopened.show_classes()
    require(before==FileAccess.get_file_as_string(reopened.progress_path()),"No must leave the saved profile unchanged")
    reopened.show_reset_confirmation();reopened.reset_progress()
    var fresh=game()
    require(fresh.progress.gold==0 and fresh.progress.total_kills==0 and not fresh.progress.has_victory,"Reset must clear gold, kills and character unlocks")
    for rank in fresh.progress.shop.values():require(rank==0,"Reset must clear every permanent upgrade")
    for key in ["completed_areas","completed_difficulties","completed_challenges","area_clear_counts","challenge_counts","enemy_totals"]:
        require(fresh.progress[key].is_empty(),"Reset must clear "+key)
    require(fresh.progress.get("runs",[]).is_empty() and fresh.progress.get("purchase_history",[]).is_empty(),"Reset must clear run and purchase records")
    require(fresh.selected_class=="warrior" and fresh.selected_arena=="cathedral" and fresh.model.state=="classes","Reset must restore first-launch selections")
    for item in [scene,stale,reopened,fresh]:item.queue_free()
    if not failed:print("GAMESHIFT_SAVE_PREFERENCES_OK")
    quit(1 if failed else 0)
