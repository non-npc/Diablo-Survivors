extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=false
    var model=Model.new(config);model.spawn_clock=999;model.attack_clock=999
    for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
        model.player=model.arena.get_center()
        if direction.x!=0:model.player.x=model.arena.end.x-1 if direction.x>0 else 1
        else:model.player.y=model.arena.end.y-1 if direction.y>0 else 1
        var before:Vector2=model.player
        model.tick(0.02,direction)
        require(model.arena.has_point(model.player),"Crossing an edge must return inside the map")
        require(model.nearest_position(model.player,before).distance_to(before)<10,"Crossing must retain continuous displacement")
    model.player=Vector2(1,model.arena.size.y/2)
    model.spawn_at(Vector2(model.arena.end.x-10,model.player.y),100)
    model.align_world()
    require(model.enemies.back().position.distance_to(model.player)<12,"Enemy across seam must remain close")
    model.automatic_attack()
    require(model.enemies.back().health<100,"Melee attacks must work across seam")
    model.pickups.append({"position":Vector2(model.arena.end.x-2,model.player.y),"xp":1})
    model.align_world()
    require(model.pickups.back().position.distance_to(model.player)<4,"Loot across seam must remain collectible")
    if not failed:print("GAMESHIFT_WRAP_OK")
    quit(1 if failed else 0)
