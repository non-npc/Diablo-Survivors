extends SceneTree
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_cooldown")
func check_cooldown() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    scene.set_physics_process(false);scene.smoke=true;scene.start_class("warrior")
    scene.model.navigation=null;scene.model.stats.cooldown=0.12
    scene.model.stats.attack_range=500;scene.model.spawn_clock=999
    scene.model.enemies.clear();scene.model.spawn_at(scene.model.player+Vector2(100,0),100000)
    scene.model.enemies[0].speed=0;scene.model.enemies[0].damage=0
    scene._physics_process(0.05)
    var info:Dictionary=scene.visuals.player.walk.info
    var step_time:float=float(info.frame_seconds)*float(info.frames_per_direction.max())/2
    require(scene.model.attack_cycle_interval>=0.22+step_time+0.049,"Fast attacks must reserve time for a walking step")
    require(scene.model.attack_cycle_interval-scene.attack_animation_span>=step_time+0.049,"Attack visuals must end before the walking interval")
    var attacks:int=scene.model.attacks
    var saw_walk:=false
    for tick in range(20):
        scene._physics_process(0.05)
        if scene.player_state=="walk":saw_walk=true
        if scene.model.attacks>attacks:break
    require(saw_walk and scene.model.attacks>attacks,"Moving players must alternate attack and walking before the next attack")
    scene.model.stats.cooldown=1.8
    require(is_equal_approx(scene.model.attack_interval(),1.8),"Slower class attack intervals must be preserved")
    attacks=scene.model.attacks
    scene.model.auto_attack_enabled=false;scene.model.attack_clock=0;scene.model.tick(0.05,Vector2.ZERO)
    require(scene.model.attacks==attacks,"Disabled auto-attack must stop player attacks")
    scene.model.auto_attack_enabled=true;scene.model.tick(0.05,Vector2.ZERO)
    require(scene.model.attacks>attacks,"Re-enabled auto-attack must resume player attacks")
    scene.model.auto_attack_enabled=false;scene.model.attack_clock=0;scene.model.config.weapon="bow"
    require(scene.model.request_manual_attack(scene.model.player+Vector2(0,-100)),"Manual click must be accepted when ready")
    scene.model.tick(0.05,Vector2.ZERO)
    require(scene.model.projectiles.back().velocity.y<0 and absf(scene.model.projectiles.back().velocity.x)<0.01,"Manual attack must aim at the cursor instead of the nearest enemy")
    require(not scene.model.request_manual_attack(scene.model.player+Vector2(100,0)),"Manual attacks must respect the cooldown")
    scene.queue_free()
    if not failed:print("DIABLO_SURVIVORS_ATTACK_COOLDOWN_OK")
    quit(1 if failed else 0)
