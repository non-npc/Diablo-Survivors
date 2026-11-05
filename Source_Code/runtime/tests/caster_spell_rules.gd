extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Classes=preload("res://scripts/class_progress.gd")
func make_model(key:String) -> RefCounted:
    var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    var config:Dictionary=Classes.configure(base,key)
    config.powerups_enabled=false
    var model=Model.new(config)
    model.auto_attack_enabled=false;model.spawn_clock=999;model.attack_clock=0
    model.stats.crit_chance=0;model.stats.knockback=0;model.stats.attack_targets=1;model.stats.summon_cap=0;model.allies.clear()
    return model
func _initialize() -> void:
    for cls in ["sorcerer","sorceress"]:
        assert(make_model(cls).config.spell_kind=="firebolt")
    assert(not make_model("paladin").config.has("spell_kind"),"Paladin must remain melee")
    var bone=make_model("necromancer")
    for offset in [Vector2(110,0),Vector2(165,0),Vector2(110,45)]:
        bone.spawn_at(bone.player+offset,1000);bone.enemies.back().speed=0
    bone.automatic_attack()
    assert(bone.projectiles.size()==1 and bone.projectiles[0].spell=="bonespear")
    var origin:Vector2=bone.projectiles[0].position
    bone.tick(0.04,Vector2.ZERO)
    assert(bone.projectiles[0].position==origin,"Spell must wait for the casting gesture")
    for i in range(40):bone.tick(0.02,Vector2.ZERO)
    assert(bone.enemies[0].health<1000 and bone.enemies[1].health<1000,"Bone Spear must pierce enemies behind the first")
    assert(bone.enemies[2].health==1000,"Bone Spear must not retain fire splash damage")
    var fire=make_model("druid")
    fire.spawn_at(fire.player+Vector2(140,0),1000);fire.enemies[0].speed=0
    fire.automatic_attack()
    assert(fire.projectiles.size()==3,"Firestorm starts with three spreading streams")
    for i in range(60):fire.tick(0.02,Vector2.ZERO)
    assert(fire.enemies[0].health<1000 and not fire.fire_patches.is_empty(),"Ground flames must persist and damage enemies")
    assert(fire.fire_patches.size()<=192)
    assert(fire.fire_patches[0].lifetime>=37*0.04,"Flames must have time to play their full original animation")
    fire.projectiles.clear()
    for i in range(100):fire.tick(0.02,Vector2.ZERO)
    assert(fire.fire_patches.is_empty(),"Firestorm ground effects must expire")
    for key in ["rogue","amazon","sorcerer","sorceress","necromancer","druid"]:
        var ranged=make_model(key)
        var expected:float=240 if key in ["rogue","amazon"] else (140 if key=="druid" else 200)
        assert(ranged.stats.attack_range==expected,"Default ranged attack distance must be halved")
        ranged.automatic_attack(Vector2.RIGHT)
        assert(not ranged.projectiles.is_empty())
        assert(ranged.projectiles[0].max_distance==expected)
        # A large simulation step must stop at the distance cap, even after a speed upgrade.
        ranged.stats.projectile_speed*=3
        ranged.tick(0.2,Vector2.ZERO)
        ranged.tick(1.0,Vector2.ZERO)
        assert(ranged.projectiles.is_empty(),"Projectiles must expire at their travel cap")
        ranged.fire_patches.clear()
        ranged.stats.attack_range=ranged.tier_value({"stat":"attack_range","mode":"multiply","step":0.1},5)
        ranged.attack_clock=0
        ranged.automatic_attack(Vector2.RIGHT)
        assert(is_equal_approx(ranged.projectiles[0].max_distance,expected*1.5),"Long reach must extend projectile travel")
    var archer=make_model("rogue")
    archer.spawn_at(archer.player+Vector2(290,0),1000);archer.enemies[0].speed=0
    archer.automatic_attack()
    assert(archer.projectiles.is_empty(),"Automatic targeting must respect reduced range")
    archer.automatic_attack(Vector2.RIGHT)
    for i in range(60):archer.tick(0.02,Vector2.ZERO)
    assert(archer.enemies[0].health==1000,"Shots must not damage targets beyond their range")
    archer.stats.attack_range=archer.tier_value({"stat":"attack_range","mode":"multiply","step":0.1},5)
    archer.attack_clock=0;archer.automatic_attack()
    for i in range(60):archer.tick(0.02,Vector2.ZERO)
    assert(archer.enemies[0].health<1000,"Long reach must enable hits beyond default range")
    print("CASTER_SPELLS_OK");quit()
