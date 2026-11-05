extends Node2D
# Small CPU particle pools also work with Godot's compatibility renderer.
var pickups:Array[CPUParticles2D]=[]
var mist:CPUParticles2D
var spells:Array[CPUParticles2D]=[]
var player_spells:Array[CPUParticles2D]=[]
var ground_flames:Array[CPUParticles2D]=[]
var goblins:Array[CPUParticles2D]=[]
var wisps:Array[CPUParticles2D]=[]
var treasures:Array[CPUParticles2D]=[]
var gameplay_speed:=1.0
var goblin_trail:Array[Dictionary]=[]
var trail_samples:Dictionary={}
var trail_scene:Node2D
var trail_model:RefCounted
func _draw() -> void:
    if trail_scene==null or trail_model==null:return
    for mote in goblin_trail:
        var age:float=trail_model.elapsed-float(mote.born)
        var fade:float=clampf(1-age/3.5,0,1)
        var point:Vector2=trail_scene.screen(mote.position)+Vector2(sin(age*2+mote.phase)*2,-age*3)
        if not Rect2(-20,-20,1320,760).has_point(point):continue
        draw_circle(point,6,Color(1,0.65,0.08,0.12*fade))
        draw_circle(point,1.6,Color(1,0.85,0.3,fade*(0.65+0.25*sin(age*5+mote.phase))))
func sync_wisps(scene:Node2D,gameplay:bool,running:bool) -> void:
    var used:=0
    if gameplay and scene.selected_class!="necromancer":
        for ally in scene.model.allies:
            if used>=8:break
            if wisps.size()<=used:
                var particles:=spell_emitter();particles.amount=20;particles.lifetime=1.2;particles.preprocess=1.2
                particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE;particles.emission_sphere_radius=10
                particles.initial_velocity_min=3;particles.initial_velocity_max=9;particles.direction=Vector2.UP;particles.spread=180
                particles.scale_amount_min=0.2;particles.scale_amount_max=0.45;wisps.append(particles)
            var particles:=wisps[used]
            particles.position=ally.position-scene.camera+Vector2(640,360)+Vector2(0,-9+sin(ally.age*3+used*PI)*2)
            particles.color=Color("ff8a32");particles.modulate.a=0.65+0.3*sin(ally.age*4+used*PI)
            set_active(particles,true,running);used+=1
    for index in range(used,wisps.size()):set_active(wisps[index],false,running)
func sync_goblins(scene:Node2D,gameplay:bool,running:bool) -> void:
    if trail_model!=scene.model:
        goblin_trail.clear();trail_samples.clear();trail_model=scene.model
    trail_scene=scene
    goblin_trail=goblin_trail.filter(func(mote):return scene.model.elapsed-float(mote.born)<3.5)
    if not gameplay:goblin_trail.clear();trail_samples.clear()
    var used:=0
    for enemy in scene.model.enemies:
        if not gameplay or enemy.health<=0 or enemy.get("kind","")!="goblin":continue
        if used>=4:break
        if running:
            var sample:Dictionary=trail_samples.get(enemy.id,{})
            if sample.is_empty() or (scene.model.elapsed-float(sample.time)>=0.08 and scene.model.nearest_position(enemy.position,sample.position).distance_to(sample.position)>=6):
                for index in range(3):
                    var phase:float=float(enemy.id)*1.7+scene.model.elapsed*9+index*2.1
                    goblin_trail.append({"position":enemy.position+Vector2(sin(phase)*10,cos(phase)*5),"born":scene.model.elapsed,"phase":phase})
                trail_samples[enemy.id]={"time":scene.model.elapsed,"position":enemy.position}
        if goblins.size()<=used:
            var particles:=emitter(false)
            particles.amount=16;particles.lifetime=0.8;particles.preprocess=0.8
            particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE;particles.emission_sphere_radius=12
            particles.initial_velocity_min=10;particles.initial_velocity_max=25
            particles.scale_amount_min=0.1;particles.scale_amount_max=0.22
            var gold_fade:=Gradient.new();gold_fade.offsets=PackedFloat32Array([0,0.25,0.65,1])
            gold_fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.85),Color(1,1,1,0.5),Color(1,1,1,0)])
            particles.color_ramp=gold_fade
            goblins.append(particles)
        var particles:=goblins[used];particles.position=scene.screen(enemy.position)+Vector2(0,-3)
        particles.color=Color("ffd23f");set_active(particles,true,running);used+=1
    for index in range(used,goblins.size()):set_active(goblins[index],false,running)
    while goblin_trail.size()>400:goblin_trail.pop_front()
    queue_redraw()
func sync_treasures(scene:Node2D,gameplay:bool,running:bool) -> void:
    var used:=0
    for pickup in scene.model.pickups:
        if not gameplay or int(pickup.get("gold",0))<=0:continue
        if used>=8:break
        if treasures.size()<=used:
            var particles:=spell_emitter()
            particles.amount=28;particles.lifetime=1.3;particles.preprocess=1.3
            particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE;particles.emission_sphere_radius=18
            particles.direction=Vector2.UP;particles.spread=35
            particles.initial_velocity_min=10;particles.initial_velocity_max=24
            particles.scale_amount_min=0.1;particles.scale_amount_max=0.22
            treasures.append(particles)
        var particles:=treasures[used]
        particles.position=scene.screen(pickup.position)+Vector2(0,-5)
        particles.color=Color("ffdc63");set_active(particles,true,running);used+=1
    for index in range(used,treasures.size()):set_active(treasures[index],false,running)

func spell_emitter() -> CPUParticles2D:
    var particles:=CPUParticles2D.new();particles.amount=12;particles.lifetime=0.35
    particles.texture=soft_texture();particles.local_coords=true
    particles.gravity=Vector2.ZERO;particles.spread=20
    particles.initial_velocity_min=35;particles.initial_velocity_max=90
    particles.scale_amount_min=0.15;particles.scale_amount_max=0.4
    var fade:=Gradient.new();fade.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)]);particles.color_ramp=fade
    var material:=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;particles.material=material
    particles.emitting=false;particles.visible=false;add_child(particles)
    return particles
func sync_spells(scene:Node2D,gameplay:bool,running:bool) -> void:
    var used:=0
    for shot in scene.model.enemy_projectiles:
        if not gameplay or shot.missile in ["arrow","quill"]:continue
        var point:Vector2=scene.screen(shot.position)
        if not Rect2(-80,-80,1440,880).has_point(point):continue
        if used>=24:break
        if spells.size()<=used:spells.append(spell_emitter())
        var particles:=spells[used];particles.position=point
        particles.direction=-shot.velocity.normalized();particles.color=scene.enemy_spell_color(shot.missile)
        set_active(particles,true,running);used+=1
    for index in range(used,spells.size()):set_active(spells[index],false,running)
func magic_edge_emitter(bone:bool,ground:bool=false) -> CPUParticles2D:
    var particles:=spell_emitter()
    particles.amount=10 if ground else 14
    particles.lifetime=0.32 if ground else 0.24
    particles.preprocess=particles.lifetime
    particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_POINTS
    var points:=PackedVector2Array()
    for index in range(16):
        var angle:float=TAU*float(index)/16
        points.append(Vector2(cos(angle)*(15 if ground else 19),sin(angle)*(6 if ground else 4)))
    particles.emission_points=points
    particles.direction=Vector2.UP if ground else Vector2.LEFT
    particles.spread=40 if ground else 55
    particles.initial_velocity_min=8;particles.initial_velocity_max=24
    particles.scale_amount_min=0.07;particles.scale_amount_max=0.14
    var fade:=Gradient.new()
    fade.offsets=PackedFloat32Array([0,0.35,1])
    fade.colors=PackedColorArray([Color("f2ffff"),Color("93ebff"),Color(0.3,0.8,1,0)]) if bone else PackedColorArray([Color("fff2a0"),Color("ff9b25"),Color(1,0.2,0.02,0)])
    particles.color_ramp=fade
    particles.set_meta("bone",bone)
    return particles

func sync_player_spells(scene:Node2D,gameplay:bool,running:bool) -> void:
    var used:=0
    for shot in scene.model.projectiles:
        var kind:String=shot.get("spell","")
        if not gameplay or kind not in ["firebolt","bonespear"] or float(shot.get("release_delay",0))>0:continue
        var point:Vector2=scene.screen(shot.position)+Vector2(shot.get("visual_offset",Vector2(0,-28)))
        if used>=24:break
        if not Rect2(-60,-60,1400,840).has_point(point):continue
        var bone:bool=kind=="bonespear"
        if player_spells.size()<=used:player_spells.append(magic_edge_emitter(bone))
        if bool(player_spells[used].get_meta("bone"))!=bone:
            player_spells[used].queue_free();player_spells[used]=magic_edge_emitter(bone)
        var particles:=player_spells[used]
        particles.position=point;particles.rotation=shot.velocity.angle()
        set_active(particles,true,running);used+=1
    for index in range(used,player_spells.size()):set_active(player_spells[index],false,running)
    used=0
    for patch in scene.model.fire_patches:
        if not gameplay:break
        if used>=24:break
        var point:Vector2=scene.screen(patch.position)
        if not Rect2(-60,-60,1400,840).has_point(point):continue
        if ground_flames.size()<=used:ground_flames.append(magic_edge_emitter(false,true))
        var particles:=ground_flames[used]
        particles.position=point;set_active(particles,true,running);used+=1
    for index in range(used,ground_flames.size()):set_active(ground_flames[index],false,running)

func soft_texture() -> GradientTexture2D:
    var gradient:=Gradient.new()
    gradient.offsets=PackedFloat32Array([0,0.35,1])
    gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0.6),Color(1,1,1,0)])
    var texture:=GradientTexture2D.new()
    texture.width=32;texture.height=32;texture.gradient=gradient
    texture.fill=GradientTexture2D.FILL_RADIAL
    texture.fill_from=Vector2(0.5,0.5);texture.fill_to=Vector2(1,0.5)
    return texture
func emitter(cloud:bool) -> CPUParticles2D:
    var particles:=CPUParticles2D.new()
    particles.amount=20 if cloud else 16
    particles.lifetime=2.0 if cloud else 3.2
    particles.preprocess=particles.lifetime
    particles.texture=soft_texture()
    particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE
    particles.emission_sphere_radius=26 if cloud else 23
    if not cloud:
        particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_POINTS
        var points:=PackedVector2Array()
        for index in range(24):
            var along:float=lerpf(-25,25,float(index)/23)
            points.append(Vector2(along,25+sin(float(index)*1.7)*3))
        particles.emission_points=points
    particles.direction=Vector2.UP;particles.spread=180 if cloud else 18
    particles.gravity=Vector2.ZERO
    # Camera-relative emitters must carry their already-emitted particles with them.
    particles.local_coords=true
    particles.initial_velocity_min=4 if cloud else 7
    particles.initial_velocity_max=12 if cloud else 14
    particles.scale_amount_min=0.65 if cloud else 0.32
    particles.scale_amount_max=1.25 if cloud else 0.48
    var fade:=Gradient.new()
    fade.offsets=PackedFloat32Array([0,0.35,0.65,1])
    fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.28 if cloud else 0.4),Color(1,1,1,0.14 if cloud else 0.25),Color(1,1,1,0)])
    particles.color_ramp=fade
    if cloud:particles.scale=Vector2(1,0.5)
    else:
        var material:=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
        particles.material=material
    particles.emitting=false;particles.visible=false
    add_child(particles)
    return particles
func sync(scene:Node2D) -> void:
    gameplay_speed=scene.game_speed
    if mist==null:mist=emitter(true)
    var gameplay:bool=scene.model.state in ["playing","paused","upgrade","character"]
    var running:bool=scene.model.state=="playing"
    sync_spells(scene,gameplay,running)
    sync_player_spells(scene,gameplay,running)
    sync_goblins(scene,gameplay,running)
    sync_wisps(scene,gameplay,running)
    sync_treasures(scene,gameplay,running)
    var aura:bool=gameplay and maxf(scene.model.haste_clock,scene.model.magnet_clock)>0
    mist.position=scene.screen(scene.model.player)+Vector2(0,-3)
    var speed_active:bool=scene.model.haste_clock>0
    var magnet_active:bool=scene.model.magnet_clock>0
    mist.color=scene.powerup_color("haste") if speed_active else scene.powerup_color("magnet")
    if speed_active and magnet_active:mist.color=scene.powerup_color("haste").lerp(scene.powerup_color("magnet"),0.5)
    mist.modulate.a=minf(1,maxf(scene.model.haste_clock,scene.model.magnet_clock)/0.5)
    set_active(mist,aura,running)
    while pickups.size()<scene.model.powerups.size():pickups.append(emitter(false))
    for index in range(pickups.size()):
        var particles:=pickups[index]
        var active:bool=index<scene.model.powerups.size() and gameplay
        if active:
            var pickup:Dictionary=scene.model.powerups[index]
            particles.position=scene.powerup_screen(pickup)
            particles.color=scene.powerup_color(pickup.kind)
            active=pickup.active
        set_active(particles,active,running)
func set_active(particles:CPUParticles2D,active:bool,running:bool) -> void:
    if active and not particles.visible:particles.restart()
    particles.visible=active;particles.emitting=active
    particles.speed_scale=gameplay_speed if running else 0
