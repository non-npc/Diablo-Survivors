extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.enemy_definitions={"archer":{"ranged":true,"missile":"arrow"}}
    config.enemy_roster=["archer"];config.challenges=[{"id":"archer-1","title":"Defeat an archer","enemy":"archer","target":1}]
    var model=Model.new(config);model.attack_clock=100;model.spawn_clock=100
    model.spawn_at(model.player+Vector2(200,0),100,false,"archer")
    var archer:Dictionary=model.enemies[0];archer.shot_clock=0
    model.tick(0.05,Vector2.ZERO)
    require(model.enemy_projectiles.size()==1 and archer.position.distance_to(model.player)==200,"Ranged enemy must fire from range instead of touching the player")
    model.damage_enemy(archer,1000,model.player)
    require(model.kill_counts.get("archer",0)==1 and model.challenge_results()[0].complete,"Enemy identity must drive kill milestones")
    var before:float=model.health
    for i in range(20):model.tick(0.05,Vector2.ZERO)
    require(model.health<before,"Enemy missile must inflict damage")
    require(model.events.filter(func(e):return e.kind=="player_hit").size()<=1,"Enemy missile must respect player invulnerability")
    if not failed:print("GAMESHIFT_MONSTER_RULES_OK")
    quit(1 if failed else 0)
