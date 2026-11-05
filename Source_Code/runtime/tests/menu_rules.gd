extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_menu")
func check_menu() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene)
    var args:=OS.get_cmdline_user_args();scene.manifest.save_path=args[args.find("--test-progress")+1]
    scene.read_progress();scene.selected_arena="cathedral"
    scene.manifest.arenas["tristram"]=scene.manifest.arenas.cathedral.duplicate(true)
    scene.manifest.arenas.tristram.title="Test Tristram"
    for i in range(12):
        scene.manifest.arenas["future"+str(i)]={"title":"Secret Map "+str(i)}
    scene.show_classes()
    var area_scroll=scene.overlay_body.find_child("AreaList",true,false)
    require(area_scroll is ScrollContainer,"Areas must live in a bounded scrolling list")
    var rows=area_scroll.get_child(0)
    require(rows.get_child_count()==14,"Future areas must remain visible as progression slots")
    require(rows.get_child(1).text.contains("Test Tristram"),"Next locked area must reveal its title")
    require(rows.get_child(2).text.contains("????") and not rows.get_child(2).text.contains("Secret Map"),"Later area titles must be concealed")
    scene.select_level("tristram")
    require(scene.selected_arena=="cathedral" and scene.model.state=="classes","Locked area must not be selectable")
    scene.select_character("rogue")
    require(scene.selected_class=="warrior","Locked character must not be selectable")
    scene.show_shop();require(scene.model.state=="shop","Shop must be accessible from menu")
    var shop_before:Dictionary=scene.progress.duplicate(true)
    scene.progress.gold=10000;scene.write_progress(scene.progress);scene.shop_category="Class";scene.ui_state="";scene.update_ui()
    await process_frame;await process_frame
    var shop_size:Vector2=scene.overlay.size
    for purchase in range(2):
        scene.buy("cleave")
        await process_frame;await process_frame
        require(scene.overlay.size==shop_size,"Shop panel size must remain stable after purchases")
        for child in scene.overlay_body.get_children():
            require(scene.overlay.get_global_rect().encloses(child.get_global_rect()),"Shop rows, purchase feedback and Main menu must stay inside panel")
    scene.progress=shop_before;scene.write_progress(shop_before)
    scene.show_classes();scene.start_class("warrior")
    require(scene.model.state=="playing" and scene.model.config.area_id=="cathedral","Play must start selected character and area")
    scene.model.kill_counts={"skeleton":100};scene.model.kills=100;scene.model.elapsed=480;scene.model.state="victory"
    scene.save_run();scene.read_progress()
    require(not Classes.area_unlocked(scene.progress,"tristram") and Classes.difficulty_unlocked(scene.progress,"cathedral","hard"),"Easy completion must unlock Hard without unlocking next area")
    scene.progress.completed_difficulties.cathedral["legendary"]=true;scene.write_progress(scene.progress)
    require(scene.progress.completed_challenges.cathedral["skeleton-100"],"First area challenge must persist")
    scene.show_classes();scene.select_level("tristram");scene.start_class("warrior")
    require(scene.model.config.area_id=="tristram" and scene.model.challenge_results()[0].gold==0 and not scene.model.challenge_results()[0].claimed,"Claimed challenges must be isolated by area")
    scene.show_classes();scene.select_level("cathedral");scene.start_class("sorcerer")
    require(scene.model.config.weapon=="firebolt" and scene.model.challenge_results()[0].claimed,"Menu must support unlocked class and replay progression")
    scene.show_achievements();require(scene.model.state=="achievements" and Classes.achievements(scene.progress).size()==7,"Menu must expose achievement records")
    scene.queue_free()
    if not failed:print("GAMESHIFT_MAIN_MENU_OK")
    quit(1 if failed else 0)
