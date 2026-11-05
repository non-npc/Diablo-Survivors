extends SceneTree
func _initialize() -> void:call_deferred("check_preview")
func check_preview() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false)
    scene.smoke=true;scene.start_class("warrior");scene.smoke=false
    scene.show_character()
    await process_frame;await process_frame
    assert(scene.character_preview.texture!=null,"Character preview must show an actual sprite rather than an empty column")
    assert(scene.CHARACTER_PREVIEW_ORDER==[5,6,3,4,7,2,1,0],"Preview must follow the requested NE, E, NW, N, SE, W, SW, S order")
    var first_direction:int=scene.character_preview_direction
    var event:=InputEventKey.new();event.physical_keycode=KEY_RIGHT;event.pressed=true
    scene._unhandled_key_input(event)
    assert(scene.character_preview_direction==posmod(first_direction+1,8),"Right arrow must rotate the character preview")
    event.physical_keycode=KEY_LEFT;scene._unhandled_key_input(event)
    assert(scene.character_preview_direction==first_direction,"Left arrow must rotate back")
    for index in range(8):
        scene.rotate_character_preview(1)
        assert(scene.character_preview.texture!=null,"Every direction must have a visible sprite")
    assert(scene.character_preview_direction==first_direction,"Rotation must wrap after eight directions")
    assert(scene.model.state=="character","Rotating the preview must leave gameplay paused")
    var parent:Control=scene.character_preview.get_parent()
    assert(parent.size.x>=220,"Art column must have enough space to show the sprite")
    scene.queue_free();await process_frame
    print("CHARACTER_PREVIEW_OK");quit()
