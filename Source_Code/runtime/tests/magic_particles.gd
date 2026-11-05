extends SceneTree
func _initialize() -> void:call_deferred("check_particles")
func check_particles() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false);scene.smoke=true
    scene.start_class(scene.manifest.get("default_class","warrior"))
    scene.model.projectiles=[{"position":scene.model.player,"velocity":Vector2(100,100),"spell":"bonespear","release_delay":0.0}]
    scene.model.fire_patches=[{"position":scene.model.player+Vector2(20,0)}]
    scene.update_powerup_particles()
    var fx=scene.particle_fx
    assert(fx.player_spells.size()==1 and fx.ground_flames.size()==1)
    var bone=fx.player_spells[0];var fire=fx.ground_flames[0]
    assert(bone.visible and bone.emitting and bone.get_meta("bone"))
    assert(is_equal_approx(bone.rotation,PI/4))
    assert(bone.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD)
    assert(bone.color_ramp.colors[1].b>bone.color_ramp.colors[1].r)
    assert(fire.color_ramp.colors[1].r>fire.color_ramp.colors[1].b)
    var original=bone.get_instance_id()
    scene.update_powerup_particles();assert(fx.player_spells[0].get_instance_id()==original,"Emitters must be reused")
    scene.model.state="paused";scene.update_powerup_particles();assert(bone.speed_scale==0 and fire.speed_scale==0)
    scene.model.state="playing";scene.model.projectiles.clear();scene.model.fire_patches.clear();scene.update_powerup_particles()
    assert(not bone.visible and not fire.visible and not bone.emitting)
    scene.model.projectiles=[{"position":scene.model.player,"velocity":Vector2.RIGHT,"spell":"firebolt","release_delay":0.1}]
    scene.update_powerup_particles();assert(not fx.player_spells[0].visible,"Casting delay must hide particles")
    print("MAGIC_PARTICLES_OK");scene.queue_free();await process_frame;quit()
