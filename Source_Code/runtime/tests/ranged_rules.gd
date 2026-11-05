extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.enemy_definitions={"archer":{"ranged":true,"missile":"arrow","ranged_min":80,"ranged_max":420},"d1_breath":{"ranged":true,"ai_reference":"AI_MEGA"},"melee":{"ranged":false}}
    config.powerups_enabled=false
    var model=Model.new(config);model.attack_clock=999;model.spawn_clock=999
    model.spawn_at(model.player+Vector2(600,0),1000,false,"archer")
    var enemy:Dictionary=model.enemies[0];var before:Vector2=enemy.position
    model.tick(0.1,Vector2.ZERO)
    require(enemy.position.distance_to(model.player)<before.distance_to(model.player),"Ranged enemy must approach when beyond maximum range")
    enemy.position=model.player+Vector2(150,0);enemy.shot_clock=0;before=enemy.position
    model.tick(0.1,Vector2.ZERO)
    require(enemy.position==before and model.enemy_projectiles.size()==1,"Ranged enemy must stand and fire inside firing band")
    enemy.position=model.player+Vector2(20,0);enemy.attack_age=0;enemy.shot_clock=0;before=enemy.position
    model.tick(0.1,Vector2.ZERO)
    require(enemy.position==before and model.enemy_projectiles.size()==1,"Player closing distance must not trigger chasing or retreat")
    require(enemy.ranged_max==210 and enemy.ranged_min==40,"Enemy firing distances must be halved")
    require(model.enemy_projectiles[0].max_distance==210,"Enemy projectile travel must match firing distance")
    # Move the player out of the shot's path and ensure it expires before reaching them.
    model.enemies.clear();model.player+=Vector2(-400,0)
    var hp:float=model.health
    for i in range(60):model.tick(0.02,Vector2.ZERO)
    require(model.enemy_projectiles.is_empty() and model.health==hp,"Enemy shots must expire at the shorter range")
    model.spawn_at(model.player+Vector2(20,0),1000,false,"archer");enemy=model.enemies.back()
    model.automatic_attack()
    require(enemy.health<1000,"Player must be able to melee a ranged enemy")
    model.spawn_at(model.player+Vector2(200,0),1000,false,"d1_breath")
    require(model.enemies.back().ranged_max==120 and model.enemies.back().ranged_min==12.5,"D1 breath attackers must use short-range defaults")
    if not failed:print("GAMESHIFT_RANGED_RULES_OK")
    quit(1 if failed else 0)
