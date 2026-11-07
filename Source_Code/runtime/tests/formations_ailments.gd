extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Status=preload("res://scripts/ailments.gd")
func model() -> RefCounted:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.duration_seconds=480;config.enemy_roster=["skeleton"];config.powerups_enabled=false
    var result=Model.new(config);result.auto_attack_enabled=false;result.spawn_clock=999
    return result
func _initialize() -> void:
    var target:Dictionary={"ailments":{}}
    Status.apply(target,"fire",3);Status.apply(target,"fire",2)
    assert(target.ailments.fire.power==3 and target.ailments.size()==1)
    assert(is_equal_approx(Status.tick(target,1),3))
    Status.apply(target,"cold",1);Status.apply(target,"lightning",1)
    assert(Status.speed(target)==0.75 and Status.vulnerability(target)==1.15)
    Status.tick(target,10);assert(target.ailments.is_empty() and Status.speed(target)==1)
    Status.apply(target,"chaos",4);assert(Status.tick(target,0.5)==0)
    assert(is_equal_approx(Status.tick(target,0.25),3))
    var game=model();var director=game.formation_director
    assert(director.schedule.size()==2 and director.schedule[0]>=65)
    assert(director.shapes[0]!=director.shapes[1])
    var second=model();assert(second.formation_director.schedule==director.schedule)
    for shape in ["circle","square","diamond","line","pincer","vee"]:
        game.enemies.clear();director.active={}
        director.spawn(game,{"center":game.player,"shape":shape,"angle":0.0,"count":16 if shape in ["circle","square","diamond"] else 10,"kind":"skeleton","element":"poison","elite":false})
        assert(game.enemies.size()>=8 and game.enemies.size()<=18)
        var enemy:Dictionary=game.enemies[0];assert(enemy.element=="poison")
        enemy.position=game.player+Vector2(20,0);director.target(game,enemy)
        assert(not enemy.has("formation_id"),"Enemies must break formation at striking distance")
    game.enemies.clear()
    director.spawn(game,{"center":game.player,"shape":"circle","angle":0.0,"count":12,"kind":"skeleton","element":"cold","elite":true})
    assert(director.elite_used and game.enemies.back().get("miniboss",false))
    var circle:Dictionary=game.enemies[0];var before:Vector2=director.target(game,circle)
    director.active.age=5
    assert(director.target(game,circle).distance_to(game.player)<before.distance_to(game.player))
    game.damage_enemy(circle,10,game.player,true,"fire");assert(circle.ailments.has("fire"))
    var poisoned=model()
    Status.apply(poisoned.player_conditions,"poison",2);var hp:float=poisoned.health;poisoned.tick(0.5,Vector2.ZERO)
    assert(is_equal_approx(poisoned.health,hp-1),"Poison must damage even without enemies nearby")
    poisoned.state="paused";var remaining:float=poisoned.player_conditions.ailments.poison.remaining;poisoned.tick(1,Vector2.ZERO)
    assert(poisoned.player_conditions.ailments.poison.remaining==remaining)
    # No partial formation is spawned when the enemy cap cannot accommodate it.
    game.enemies.clear();game.config.director.max_enemies=5
    director.spawn(game,{"center":game.player,"shape":"circle","angle":0.0,"count":12,"kind":"skeleton","element":"","elite":false})
    assert(game.enemies.is_empty())
    var incoming=model();incoming.spawn_at(incoming.player+Vector2(20,0),1000)
    incoming.enemies[0].element="cold";incoming.tick(0.01,Vector2.ZERO)
    assert(incoming.player_conditions.ailments.has("cold"),"Elemental contact hits must afflict the player")
    var missile=model()
    missile.enemy_projectiles=[{"position":missile.player+Vector2(20,0),"velocity":Vector2(-100,0),"damage":10.0,"age":0.0,"missile":"fire","element":"fire","max_distance":210.0,"distance_travelled":0.0}]
    missile.tick(0.1,Vector2.ZERO)
    assert(missile.player_conditions.ailments.has("fire"),"Elemental projectiles must afflict the player")
    var killed=model();killed.spawn_at(killed.player+Vector2(100,0),1)
    Status.apply(killed.enemies[0],"poison",5);killed.tick(0.5,Vector2.ZERO)
    assert(killed.kills==1,"Ailment kills must count toward normal rewards")
    var paced=model()
    for second_index in range(480):
        paced.elapsed=float(second_index);paced.formation_director.tick(paced,1)
    assert(paced.formation_director.events_started==2,"An unobstructed eight-minute run should get two surprises")
    assert(paced.enemies.filter(func(e):return e.get("miniboss",false)).size()<=1)
    print("FORMATIONS_AILMENTS_OK");quit()
