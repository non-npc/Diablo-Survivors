extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
const Modes=preload("res://scripts/difficulties.gd")
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_modes")
func check_modes() -> void:
    var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    base["formations_enabled"]=false # Isolate timer/progression checks from combat events.
    base.challenges=[{"id":"skeleton-20","title":"Defeat 20 skeletons","enemy":"skeleton","target":20},{"id":"boss-1","title":"Defeat 1 boss","enemy":"boss","target":1}];base["boss"]="boss"
    var progress:Dictionary=Classes.migrate({})
    require(Classes.difficulty_unlocked(progress,"cathedral","easy") and not Classes.difficulty_unlocked(progress,"cathedral","hard"),"Only first area's Easy starts unlocked")
    var last_target:=0
    for difficulty in Modes.ORDER:
        require(Classes.difficulty_unlocked(progress,"cathedral",difficulty),"Previous difficulty must unlock next mode")
        var config:Dictionary=Modes.configure(base,difficulty)
        require(config.duration_seconds==Modes.MODES[difficulty].seconds,"Each mode must use its own timer")
        require(config.challenges[0].target>last_target and config.challenges[1].target==1,"Targets must rise while single bosses remain attainable")
        last_target=config.challenges[0].target
        var model=Model.new(config);model.spawn_clock=100000;model.attack_clock=100000;model.boss_spawned=true;model.config.rare_events={"spawn_chance":0}
        model.kill_counts.skeleton=config.challenges[0].target
        for tick in range(int(config.duration_seconds)-1):model.tick(1,Vector2.ZERO)
        require(model.state=="playing","Run must not complete early")
        model.tick(1,Vector2.ZERO)
        require(model.state=="victory" and model.summary().difficulty==difficulty,"Timer must finish at the mode duration")
        progress=Classes.record(progress,model.summary())
        require(progress.completed_difficulties.cathedral[difficulty],"Difficulty victory must persist")
        require(Classes.area_unlocked(progress,"tristram")== (difficulty=="legendary"),"Only Legendary may unlock next area")
        var first_gold:int=progress.gold
        progress=Classes.record(progress,model.summary())
        require(progress.gold-first_gold==Classes.reward(model.summary())-1,"Repeating a claimed challenge cannot award its gold again")
    require(progress.completed_challenges.size()==3,"Challenge claims must be isolated for each difficulty")
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.manifest.save_path=ProjectSettings.globalize_path("res://../.local/difficulty-test-"+str(Time.get_ticks_usec())+".json")
    scene.write_progress(progress);scene.selected_arena="cathedral";scene.select_difficulty("hard");scene.start_class("warrior")
    require(scene.model.config.duration_seconds==720 and scene.progress.last_played.difficulty=="hard","Play must apply and save selected difficulty")
    scene.read_progress();scene.restore_last_played()
    require(scene.selected_difficulty=="hard","Reopening must restore selected difficulty")
    scene.show_classes();scene.select_level("tristram")
    require(scene.selected_difficulty=="easy","Area without unlocked Hard must fall back to Easy")
    scene.select_difficulty("legendary")
    require(scene.selected_difficulty=="easy","Locked difficulty selection must be rejected")
    scene.queue_free()
    if not failed:print("GAMESHIFT_DIFFICULTY_RULES_OK")
    quit(1 if failed else 0)
