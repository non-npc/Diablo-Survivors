extends SceneTree
func _initialize() -> void:
    call_deferred("benchmark")
func benchmark() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var scene=load("res://scenes/survival.tscn").instantiate()
    root.add_child(scene)
    scene.start_class("warrior")
    scene.model.base_stats.max_health=100000;scene.model.stats.max_health=100000;scene.model.health=100000
    scene.model.spawn_clock=999
    if scene.model.navigation!=null:
        for i in range(150):
            var nav=scene.model.navigation
            scene.model.spawn_at(nav.world(nav.available[i*19%nav.available.size()]),999)
    var start:=Time.get_ticks_usec()
    for i in range(30):
        scene.model.tick(1.0/60,Vector2.RIGHT.rotated(i*0.03))
        if scene.model.state=="upgrade":scene.model.choose_upgrade(0)
    var model_ms:=float(Time.get_ticks_usec()-start)/30/1000
    print("TOWN_CPU_MODEL_MS ",model_ms)
    var terrain_start:=Time.get_ticks_usec()
    for i in range(30):scene.visible_town_pieces()
    print("TOWN_CPU_TERRAIN_MS ",float(Time.get_ticks_usec()-terrain_start)/30/1000)
    var calls:=0.0
    for i in range(30):await process_frame
    start=Time.get_ticks_usec()
    for i in range(30):
        await process_frame
        calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var frame_ms:=float(Time.get_ticks_usec()-start)/30/1000
    print("TOWN_BENCHMARK ",JSON.stringify({"model_tick_ms":model_ms,"frame_ms":frame_ms,"draw_calls":calls/30,"enemies":scene.model.enemies.size()}))
    scene.queue_free();quit()
