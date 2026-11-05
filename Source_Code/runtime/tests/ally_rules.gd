extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=false;config.player.summon_cap=2
    var model=Model.new(config);model.attack_clock=999;model.spawn_clock=999
    for step in range(100):model.tick(0.02,Vector2.ZERO)
    require(model.allies.size()==2 and model.allies[0].position.distance_to(model.allies[1].position)>=24,"Idle wisps must occupy separate positions")
    model.spawn_at(model.player+Vector2(100,40),10000)
    model.spawn_at(model.player+Vector2(100,-40),10000)
    for enemy in model.enemies:enemy.speed=0;enemy.damage=0
    for step in range(100):model.tick(0.02,Vector2.ZERO)
    require(model.allies[0].target_id!=model.allies[1].target_id,"Wisps must prefer separate available targets")
    require(model.enemies[0].health<10000 and model.enemies[1].health<10000,"Both wisps must attack independently")
    model.enemies.remove_at(1)
    for step in range(100):model.tick(0.02,Vector2.ZERO)
    require(model.allies[0].position.distance_to(model.allies[1].position)>=24,"Wisps sharing one enemy must remain separated")
    require(model.allies[0].target_id==model.allies[1].target_id,"Both wisps may attack the only remaining target")
    model.ally_visible_bounds=Rect2(model.player-Vector2(560,280),Vector2(1120,560))
    model.allies[0].position=model.player+Vector2(1200,-800)
    model.allies[1].position=model.player
    model.constrain_allies()
    for ally in model.allies:
        require(model.ally_visible_bounds.grow(0.01).has_point(ally.position),"Minions must stay inside the screen with a margin for their sprites and particles")
        var offset:Vector2=ally.position-model.player
        require(Vector2(offset.x/48.0,offset.y/72.0).length()>=0.999,"Wisps must stay outside the player sprite")
    model.allies_are_wisps=false;model.allies[1].position=model.player;model.constrain_allies()
    var skeleton_offset:Vector2=model.allies[1].position-model.player
    require(Vector2(skeleton_offset.x/48.0,skeleton_offset.y/72.0).length()>=0.999,"Skeleton minions must stay outside the Necromancer sprite")
    model.enemies.clear();model.allies[0].position=model.player+Vector2(90,0)
    model.spawn_at(model.player-Vector2(100,0),10000)
    for enemy in model.enemies:enemy.speed=0;enemy.damage=0
    for step in range(150):
        model.tick(0.02,Vector2.ZERO)
        for ally in model.allies:
            var offset:Vector2=ally.position-model.player
            require(Vector2(offset.x/48.0,offset.y/72.0).length()>=0.999,"Skeletons pursuing enemies across their owner must go around him")
    model.enemies.clear();model.allies[0].position=model.player+Vector2(48,0)
    for step in range(200):model.tick(0.02,Vector2.ZERO)
    var resting_position:Vector2=model.allies[0].position
    for step in range(50):model.tick(0.02,Vector2.ZERO)
    require(model.allies[0].position.distance_to(resting_position)<0.1,"Idle skeletons near the player must settle without vibrating against his exclusion edge")
    require(not model.allies[0].get("moving",true),"A stationary skeleton must use idle rather than walk animation")
    model.arena=Rect2(0,0,1000,800);model.player=Vector2(500,400)
    model.allies[0].position=model.player+Vector2(550,0)
    model.align_world()
    require(model.allies[0].position.x>model.player.x,"A right-edge minion must not wrap to the left when it passes half the map width")
    model.enemies.clear();model.player=Vector2(1,400)
    model.allies[0].position=model.player+Vector2(200,0)
    model.allies[1].position=model.player+Vector2(220,0)
    model.ally_visible_bounds=Rect2(model.player-Vector2(560,280),Vector2(1120,560))
    model.tick(0.02,Vector2.LEFT)
    require(model.player.x>900 and model.allies[0].position.x>model.player.x,"A minion must retain its right-side offset when the player crosses the left map seam")
    require(model.allies[0].position.distance_to(model.player)<240,"Crossing a seam must not send minions a whole map away")
    if not failed:print("GAMESHIFT_ALLIES_OK")
    quit(1 if failed else 0)
