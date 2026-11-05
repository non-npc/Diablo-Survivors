extends SceneTree
const Difficulties=preload("res://scripts/difficulties.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_ending")
func check_ending() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.manifest.arenas["hell-16"]={"challenges":[{"id":"final-enemies","title":"Defeat foes","enemy":"skeleton","target":10}]}
    scene.selected_arena="hell-16";scene.model.state="victory"
    scene.progress.completed_difficulties={"hell-16":{"easy":true,"hard":true,"legendary":true}}
    scene.progress.completed_challenges={}
    require(not scene.campaign_finished(),"Final area clear alone must not trigger the ending")
    for difficulty in Difficulties.ORDER:
        var slot:String=Difficulties.slot("hell-16",difficulty);scene.progress.completed_challenges[slot]={}
        for challenge in Difficulties.challenges(scene.manifest.arenas["hell-16"].challenges,difficulty,""):
            scene.progress.completed_challenges[slot][challenge.id]=true
    require(scene.campaign_finished(),"Final area plus all challenges must trigger ending")
    scene.model.state="dead"
    require(not scene.campaign_finished(),"Death must not display victory ending")
    scene.model.state="victory";scene.selected_arena="cathedral"
    require(not scene.campaign_finished(),"Earlier areas must not trigger ending")
    scene.queue_free()
    if not failed:print("GAMESHIFT_CAMPAIGN_ENDING_OK")
    quit(1 if failed else 0)
