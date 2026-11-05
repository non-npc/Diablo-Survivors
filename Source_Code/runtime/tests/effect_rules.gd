extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_effects")
func check_effects() -> void:
    var args:=OS.get_cmdline_user_args()
    var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--effects-manifest")+1]))
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    for kind in document.impact_effects:scene.impact_visuals[kind]=scene.load_visual(document.impact_effects[kind])
    require(scene.impact_visuals.size()==4,"Original blood/bone/metal effects must decode")
    scene.impact_event({"kind":"damage","actor":"zombie","position":Vector2.ZERO})
    require(scene.impact_particles.back().kind=="blood","Flesh hits must use blood spray")
    scene.impact_event({"kind":"kill","actor":"skeleton","position":Vector2.ZERO})
    require(scene.impact_particles.back().kind=="bone" and scene.impact_particles.back().death,"Skeletal deaths must use bone fragments")
    var count:int=scene.impact_particles.size()
    scene.impact_event({"kind":"damage","actor":"zombie","position":Vector2.ZERO,"fatal":true})
    require(scene.impact_particles.size()==count,"Killing blows must not duplicate hit and death effects")
    for i in range(200):scene.impact_event({"kind":"player_hit","position":Vector2.ZERO})
    require(scene.impact_particles.size()==96,"Impact effects must have a bounded pool")
    scene.restart();require(scene.impact_particles.is_empty(),"New runs must clear old splatters")
    scene.queue_free()
    if not failed:print("GAMESHIFT_EFFECTS_OK")
    quit(1 if failed else 0)
