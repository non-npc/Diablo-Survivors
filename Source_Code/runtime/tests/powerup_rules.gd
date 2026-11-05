extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_powerups")
func check_powerups() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=true
    config.arena_width=3200;config.arena_height=2400
    var model=Model.new(config);model.spawn_clock=999;model.attack_clock=999
    model.update_powerups(0)
    require(model.powerups.size()==4,"Each area must have three regular collectibles and a rare harvest slot")
    for first in range(model.powerups.size()):
        for second in range(first+1,model.powerups.size()):
            if model.powerups[first].active and model.powerups[second].active:
                require(not model.powerups_share_screen(model.powerups[first].position,model.powerups[second].position),"Spawned boosts must not share a screen, including across wrapped edges")
    var item:Dictionary=model.powerups[1];item.position=model.player
    model.update_powerups(0)
    require(not item.active and model.haste_clock==35,"Walking over speed pickup must start its timed boost")
    var duration_upgrade:Dictionary={}
    for upgrade in model.eligible_upgrades():
        if upgrade.id=="boost_duration":duration_upgrade=upgrade
    model.offered=[duration_upgrade];model.state="upgrade";model.choose_upgrade(0)
    require(model.haste_clock==42 and is_equal_approx(model.stats.boost_duration,1.2),"Duration upgrade must extend active boosts as well as future pickups")
    var original:Vector2=item.position;model.update_powerups(44)
    require(not item.active and model.haste_clock==0,"Boost must expire independently of pickup respawn")
    model.update_powerups(1)
    require(item.active and item.position.distance_to(original)>=250,"Pickup must respawn at a different location after 45 seconds")
    for other in model.powerups:
        if other!=item and other.active:
            require(not model.powerups_share_screen(item.position,other.position),"Respawn must preserve screen spacing")
    require(model.powerups_share_screen(Vector2(5,100),Vector2(model.arena.end.x-5,100)),"Opposite edges must count as nearby for boost placement")
    model.powerups[0].position=model.player;model.health=20;model.update_powerups(0)
    require(model.health==55,"Healing must restore 35 percent of maximum health")
    model.powerups[2].position=model.player;model.pickups=[{"position":model.player+Vector2(300,0),"xp":5,"heal":0}]
    model.update_powerups(0);model.update_powerups(0.1)
    require(model.magnet_clock>0 and model.pickups[0].position.distance_to(model.player)<300,"Magnet must pull nearby loot for its duration")
    model.state="paused";var remaining:float=model.magnet_clock;model.tick(5,Vector2.ZERO)
    require(model.magnet_clock==remaining,"Pause must freeze boost timers")
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.model.state="playing";scene.model.haste_clock=35;scene.update_ui()
    require(scene.powerup_bars.haste.visible and scene.powerup_bars.haste.value==35,"Active boost must show its purple countdown bar")
    scene.model.powerups=[{"kind":"haste","position":scene.model.player+Vector2(100,0),"active":true}]
    scene.update_powerup_particles()
    require(scene.particle_fx.mist is CPUParticles2D and scene.particle_fx.mist.visible,"Active timed buffs must enable actual mist particles")
    require(scene.particle_fx.pickups[0].visible and scene.particle_fx.pickups[0].emitting,"Active collectibles must emit neon particles")
    var pickup_fx:CPUParticles2D=scene.particle_fx.pickups[0]
    require(pickup_fx.local_coords and scene.particle_fx.mist.local_coords,"Existing particles must follow their camera-relative emitter")
    require(pickup_fx.direction==Vector2.UP and pickup_fx.initial_velocity_min>0 and pickup_fx.initial_velocity_max<=14,"Magical motes must rise gently from the pickup base")
    var anchor_offset:Vector2=pickup_fx.position-scene.screen(scene.model.powerups[0].position)
    var previous_position:Vector2=pickup_fx.position
    scene.camera+=Vector2(120,-80);scene.update_powerup_particles()
    require(pickup_fx.position.is_equal_approx(previous_position-Vector2(120,-80)),"Camera motion must shift the complete pickup effect with its ground object")
    require((pickup_fx.position-scene.screen(scene.model.powerups[0].position)).is_equal_approx(anchor_offset),"Camera movement must preserve pickup-relative particle anchor")
    require(absf(anchor_offset.y)<=3 and anchor_offset.x==0,"Pickup bob must stay within three pixels of its anchor")
    require(pickup_fx.position.is_equal_approx(scene.powerup_screen(scene.model.powerups[0])),"Sparkles and icon must bob together")
    for point in pickup_fx.emission_points:
        require(point.y>=22 and absf(point.x)<=25,"Magical motes must originate at the bottom, not around the square")
    scene.model.state="paused";scene.update_powerup_particles()
    require(scene.particle_fx.mist.speed_scale==0 and scene.particle_fx.pickups[0].speed_scale==0,"Pause must freeze particles")
    scene.model.state="playing";scene.model.powerups[0].active=false;scene.update_powerup_particles()
    require(not scene.particle_fx.pickups[0].visible,"Collected pickups must hide their particles")
    scene.model.powerups[0].active=true;scene.update_powerup_particles()
    require(scene.particle_fx.pickups.size()==1 and scene.particle_fx.pickups[0].visible,"Respawn must reuse its emitter")
    scene.model.haste_clock=0;scene.update_ui()
    require(not scene.powerup_bars.haste.visible,"Expired boosts must remove their bar")
    scene.update_powerup_particles()
    require(not scene.particle_fx.mist.visible,"Expired boosts must also remove mist particles")
    scene.show_classes();scene.update_powerup_particles()
    require(not scene.particle_fx.pickups[0].visible,"Menu must hide collectible particles")
    scene.queue_free()
    if not failed:print("GAMESHIFT_POWERUPS_OK")
    quit(1 if failed else 0)
