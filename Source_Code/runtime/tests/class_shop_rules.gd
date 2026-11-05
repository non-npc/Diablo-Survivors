extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_shop")
func check_shop() -> void:
    var scene=load("res://scenes/survival.tscn").instantiate();root.add_child(scene);scene.set_physics_process(false);scene.smoke=true
    scene.manifest.game_id="diablo2";scene.manifest.available_classes=Classes.D2_CLASSES
    scene.shop_category="Class";scene.show_shop()
    var scroll:ScrollContainer
    for child in scene.overlay_body.get_children():
        if child is ScrollContainer:scroll=child
    require(scroll!=null and scroll.get_child(0).get_child_count()==7,"LoD shop must have all seven class rows in a scrolling list")
    for button in scroll.get_child(0).get_children():
        require(not button.text.contains("Warrior:") and not button.text.contains("Rogue:") and not button.text.contains("Sorcerer:"),"D1 classes must be hidden in D2 shop")
    scene.manifest.available_classes=Classes.D2_CLASSES.slice(0,5);scene.ui_state="";scene.update_ui()
    for child in scene.overlay_body.get_children():
        if child is ScrollContainer:require(child.get_child(0).get_child_count()==5,"Base D2 shop must hide Assassin and Druid")
    var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    var generic:Dictionary=Classes.configure(base,"warrior",{"shop":{"learning":2,"duration":2,"precision":2,"recovery":2,"harvest":2}})
    require(is_equal_approx(generic.player.xp_multiplier,1.1) and is_equal_approx(generic.player.boost_duration,1.2),"General upgrades must increase XP and boost duration")
    require(is_equal_approx(generic.player.crit_chance,0.09) and is_equal_approx(generic.player.regeneration,0.4) and is_equal_approx(generic.player.kill_heal,0.5),"Critical chance and defensive recovery bonuses must apply")
    require(Classes.SHOP.haste.category=="General","Fleet feet must live in General rather than its own tab")
    var mappings:Dictionary={"barbarian":["barbarian_cleave","attack_targets"],"amazon":["amazon_archery","damage"],"paladin":["paladin_guard","armor"],"necromancer":["necromancer_minions","ally_damage"],"sorceress":["sorceress_blast","splash_radius"],"assassin":["assassin_strikes","damage"],"druid":["druid_recovery","regeneration"]}
    for owner in mappings:
        var key:String=mappings[owner][0];var stat:String=mappings[owner][1]
        var plain:Dictionary=Classes.configure(base,owner)
        var boosted:Dictionary=Classes.configure(base,owner,{"shop":{key:1}})
        require(float(boosted.player.get(stat,0))>float(plain.player.get(stat,0)),"Bonus must apply to owner: "+owner)
        for other in Classes.D2_CLASSES:
            if other==owner:continue
            require(Classes.configure(base,other,{"shop":{key:1}}).player==Classes.configure(base,other).player,"Class bonus must not leak to "+other)
    scene.queue_free();await process_frame
    if not failed:print("GAMESHIFT_CLASS_SHOP_OK")
    quit(1 if failed else 0)
