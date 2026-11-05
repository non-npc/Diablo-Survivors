extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    config.powerups_enabled=false
    var model=Model.new(config);model.spawn_clock=999;model.attack_clock=999
    model.health=50;model.magnet_clock=10
    model.pickups=[{"position":model.player+Vector2(80,0),"xp":30,"heal":15,"gold":25,"magnet_pull":true}]
    var position:Vector2=model.pickups[0].position
    for step in range(20):model.tick(0.02,Vector2.ZERO)
    assert(model.pickups.size()==1 and model.pickups[0].position==position,"Treasure must ignore pickup range, magnet and global orb pull")
    model.player=position;model.tick(0.02,Vector2.ZERO)
    assert(model.pickups.is_empty() and model.loot_gold==25,"Walking onto treasure must collect its gold")
    var notices:Array=model.events.filter(func(event):return event.kind=="treasure_collected")
    assert(notices.size()==1 and notices[0].gold==25 and notices[0].xp==30 and notices[0].healing==15,"Collection must report the actual gold, XP and healing")
    print("TREASURE_PICKUP_OK");quit()
