extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_classes")
func check_classes() -> void:
    var fresh:Dictionary=Classes.migrate({})
    require(Classes.unlocked(fresh,"barbarian"),"Barbarian must start unlocked")
    for key in Classes.D2_CLASSES:
        if key!="barbarian":require(not Classes.unlocked(fresh,key),"Other D2 classes must unlock through play")
    var earned:Dictionary=Classes.migrate({"total_kills":2000,"has_victory":true,"completed_difficulties":{"cathedral":{"easy":true,"hard":true,"legendary":true}}})
    var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    for key in Classes.D2_CLASSES:
        require(Classes.unlocked(earned,key),"Each class must be unlockable: "+key)
        var model=Model.new(Classes.configure(base,key,earned))
        model.spawn_at(model.player+Vector2(25,0),1);model.automatic_attack()
        require(model.stats.damage>0 and (model.attacks>0 or not model.projectiles.is_empty()),"Each class must attack: "+key)
        if key=="necromancer":require(model.stats.summon_cap==1,"Necromancer starts with a skeletal ally")
        if key=="assassin":require(model.stats.attack_count==2,"Assassin has twin strikes")
    var args:=OS.get_cmdline_user_args()
    if args.has("--d2-manifest"):
        var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
        var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--d2-manifest")+1]));scene.manifest=document
        scene.manifest.save_path=args[args.find("--test-progress")+1]
        require(scene.playable_classes().size()== (7 if document.source_game.expansion else 5),"Class count must match expansion")
        scene.write_progress(earned)
        for key in scene.playable_classes():
            scene.selected_arena="cathedral";scene.start_class(key)
            require(scene.model.state=="playing" and scene.model.config.class_id==key and scene.visuals.player.has("walk"),"Imported class must launch: "+key)
        scene.queue_free()
    if not failed:print("GAMESHIFT_DIABLO2_CLASSES_OK")
    quit(1 if failed else 0)
