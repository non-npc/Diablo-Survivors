extends SceneTree
func _initialize() -> void:call_deferred("check_trail")
func check_trail() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    scene.set_physics_process(false);scene.smoke=true;scene.start_class("warrior")
    scene.model.navigation=null;scene.model.enemies.clear();scene.model.spawn_goblin(scene.model.player+Vector2(120,0))
    var goblin:Dictionary=scene.model.enemies.back()
    scene.update_powerup_particles()
    var fx=scene.particle_fx
    var original:Vector2=fx.goblin_trail[0].position
    goblin.position+=Vector2(20,0);scene.model.elapsed+=0.1;scene.update_powerup_particles()
    assert(fx.goblin_trail.size()==6,"Moving goblin must leave particles at successive ground positions")
    scene.camera+=Vector2(80,40);scene.update_powerup_particles()
    assert(fx.goblin_trail[0].position==original,"Camera movement must not move trail particles across the ground")
    scene.model.enemies.clear();scene.model.elapsed+=3.6;scene.update_powerup_particles()
    assert(fx.goblin_trail.is_empty(),"Trail must expire after 3.5 seconds, including after goblin death")
    scene.queue_free();print("DIABLO_SURVIVORS_GOBLIN_TRAIL_OK");quit()
