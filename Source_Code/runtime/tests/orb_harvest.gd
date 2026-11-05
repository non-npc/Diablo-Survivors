extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=true
    var model=Model.new(config);model.spawn_clock=999;model.attack_clock=999
    model.powerups=[{"kind":"vacuum","position":model.player,"active":true,"respawn":0}]
    model.pickups=[{"position":model.player+Vector2(800,0),"xp":2,"heal":0},{"position":model.player+Vector2(0,700),"xp":3,"heal":0},{"position":model.player+Vector2(300,0),"xp":0,"heal":10}]
    model.update_powerups(0)
    require(model.pickups[0].magnet_pull and model.pickups[1].magnet_pull,"Rare harvest must mark all existing XP orbs")
    require(not model.pickups[2].get("magnet_pull",false),"Harvest must leave non-XP drops alone")
    model.tick(0.1,Vector2.ZERO)
    require(model.pickups.size()==3 and model.pickups[0].position.distance_to(model.player)<800,"Orbs must visibly travel, not collect instantly")
    for step in range(40):
        if model.state=="upgrade":model.choose_upgrade(0)
        model.tick(0.05,Vector2.ZERO)
    require(model.collected_xp==5,"All marked orbs must eventually reach player")
    require(model.pickups.size()==1 and model.pickups[0].xp==0,"Non-XP drop must remain")
    if not failed:print("GAMESHIFT_ORB_HARVEST_OK")
    quit(1 if failed else 0)
