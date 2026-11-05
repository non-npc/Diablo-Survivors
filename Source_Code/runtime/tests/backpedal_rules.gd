extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_backpedal")
func check_backpedal() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    scene.set_physics_process(false);scene.smoke=true;scene.start_class("warrior");scene.model.navigation=null;scene.model.stats.attack_range=480;scene.model.config.weapon="bow";scene.model.state="playing"
    scene.model.enemies.clear();scene.model.spawn_at(scene.model.player+Vector2(120,0),10000)
    var enemy=scene.model.enemies[0];enemy.speed=0;enemy.damage=0
    scene.model.automatic_attack()
    var attack:Dictionary={}
    for event in scene.model.events:
        if event.kind=="attack":attack=event
    require(attack.get("target_id",-1)==enemy.id,"Attack must identify its target for facing")
    scene.attack_target_id=enemy.id;scene.attack_animation=0
    scene.update_attack_facing(Vector2.LEFT)
    require(scene.facing==scene.model.direction_index(Vector2.RIGHT) and scene.player_walk_reverse,"Backing away must face the target and reverse walking")
    scene.update_attack_facing(Vector2.RIGHT)
    require(not scene.player_walk_reverse,"Forward walking must play normally")
    scene.update_attack_facing(Vector2.UP)
    require(not scene.player_walk_reverse,"Sideways movement must not reverse walking")
    scene.attack_animation=0.4;scene.update_attack_facing(Vector2.LEFT)
    require(is_equal_approx(scene.attack_animation,0.4),"Walking must preserve the normal attack animation timer")
    var before:Vector2=scene.model.player
    scene.model.attack_clock=999;scene.model.spawn_clock=999;scene.model.tick(0.1,Vector2.LEFT)
    require(scene.model.player.x<before.x,"Player must remain able to move during an attack")
    enemy.health=0;scene.attack_animation=0;scene.update_attack_facing(Vector2.LEFT)
    require(scene.attack_target_id==-1 and scene.facing==scene.model.direction_index(Vector2.LEFT) and not scene.player_walk_reverse,"Without a living target, facing must return to movement")
    scene.queue_free()
    if not failed:print("DIABLO_SURVIVORS_BACKPEDAL_OK")
    quit(1 if failed else 0)

