extends SceneTree
func _initialize() -> void:call_deferred("check_marker")
func check_marker() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    scene.set_physics_process(false);scene.smoke=true;scene.start_class("warrior")
    scene.model.enemies.clear();scene.model.navigation=null
    scene.model.arena=Rect2(0,0,1000,800)
    scene.model.player=Vector2(990,400)
    scene.model.spawn_goblin(Vector2(10,400))
    var goblin:Dictionary=scene.model.enemies.back()
    # Even duplicate wrapped entries must resolve to only one marker.
    var duplicate:Dictionary=goblin.duplicate(true);duplicate.position+=Vector2(1000,0)
    scene.model.enemies.append(duplicate)
    var marker:Dictionary=scene.goblin_minimap_marker()
    assert(marker.id==goblin.id and marker.offset.x>0 and marker.offset.length()<4,"Across the right seam the one goblin marker must be nearby on the right")
    scene.model.player=Vector2(5,400)
    marker=scene.goblin_minimap_marker()
    assert(marker.id==goblin.id and marker.offset.x>0 and marker.offset.length()<1,"Crossing the seam must retain one nearby marker")
    scene.model.player=Vector2(30,400)
    marker=scene.goblin_minimap_marker()
    assert(marker.offset.x<0,"Passing the goblin must move its single marker to the left")
    scene.model.enemies.clear()
    assert(scene.goblin_minimap_marker().is_empty(),"No goblin means no star")
    scene.queue_free();await process_frame
    print("GOBLIN_MINIMAP_OK");quit()
