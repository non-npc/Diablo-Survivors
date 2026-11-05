extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.enemy_roster=["zombie","skeleton","archer","mage"];config.enemy_definitions={"archer":{"ranged":true},"mage":{"ranged":true}}
    var model=Model.new(config)
    for index in range(100):require(model.directed_enemy_kind()=="zombie","First stage must use basic melee only")
    model.elapsed=130;var found:=false
    for index in range(300):
        var kind:String=model.directed_enemy_kind()
        if kind=="archer":found=true
        require(kind!="mage","Later ranged variety must remain locked in stage two")
    require(found,"Stage two must introduce ranged attackers")
    model.elapsed=30;require(not model.surge_plan().active,"Early surge must have a recovery break")
    model.attack_clock=999;model.spawn_clock=0
    model.tick(0.02,Vector2.ZERO)
    require(model.enemies.is_empty(),"Recovery must not spawn ordinary enemies")
    model.elapsed=45;model.spawn_clock=0;model.tick(0.02,Vector2.ZERO)
    require(model.enemies.size()==1,"Next surge must resume spawning")
    model.enemies.clear();model.elapsed=0
    for index in range(40):model.spawn_at(model.player+Vector2(100,0),10000)
    model.spawn_clock=0;model.tick(0.02,Vector2.ZERO)
    require(model.enemies.size()==40,"Survivors at the stage cap must pause spawning")
    model.elapsed=470;require(model.surge_plan().limit<=130 and model.surge_plan().quota>16,"Late pressure must increase without approaching 300-enemy ceiling")
    config.duration_seconds=960;config.difficulty="legendary"
    var legendary=Model.new(config);legendary.elapsed=250
    require(legendary.surge_plan().stage==1,"Difficulty stages must scale with run duration")
    if not failed:print("GAMESHIFT_SURGES_OK")
    quit(1 if failed else 0)
