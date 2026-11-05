extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=false
    config.death_durations={"skeleton":[6.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0]}
    var model=Model.new(config)
    model.spawn_clock=999;model.attack_clock=999;model.health=100000
    for index in range(81):
        model.spawn_at(model.player+Vector2(100,0),10)
        var enemy:Dictionary=model.enemies.back();enemy.facing=0
        model.damage_enemy(enemy,100,model.player)
    assert(model.corpses.size()==81,"Crowd cleanup must not truncate unfinished death sequences")
    for step in range(50):model.tick(0.1,Vector2.ZERO)
    assert(model.corpses.size()==81,"Six-second death animations must survive past the old four-second cutoff")
    assert(model.corpses[0].lifetime==7.0,"Fade must follow the full frame sequence")
    model.spawn_at(model.player+Vector2(100,0),10)
    var enemy:Dictionary=model.enemies.back();enemy.facing=7
    model.damage_enemy(enemy,100,model.player)
    assert(model.corpses.back().lifetime==9.0,"Use the dying enemy's direction-specific frame count")
    print("DEATH_ANIMATION_RULES_OK")
    quit()
