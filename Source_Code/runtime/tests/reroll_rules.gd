extends SceneTree
const Model=preload("res://scripts/survival_model.gd")
const Classes=preload("res://scripts/class_progress.gd")
var failed:=false
func require(value:bool,message:String) -> void:
    if not value:push_error(message);failed=true
func _initialize() -> void:
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    var model=Model.new(config);model.xp=model.xp_needed;model.check_level_up()
    var level:int=model.level;var xp:int=model.xp
    for index in range(3):
        var old:Array=[]
        for choice in model.offered:old.append(choice.id)
        require(model.reroll_upgrades(),"Each of the first three rerolls must succeed")
        for choice in model.offered:
            require(choice.id not in old,"Reroll must replace current choices with different upgrades")
            require(int(model.upgrade_ranks.get(choice.id,0))<int(choice.max_tier),"Maxed upgrades must never appear")
        require(model.level==level and model.xp==xp and model.state=="upgrade","Rerolls must not change XP, level, or resume gameplay")
    require(model.rerolls_used==3 and not model.reroll_upgrades(),"A fourth reroll must be rejected")
    require(Model.new(config).rerolls_used==0,"A new run must reset the reroll allowance")
    var progress:Dictionary=Classes.migrate({"gold":3000})
    for rank in range(5):
        require(Classes.price(progress,"rerolls")==150*(rank+1),"Permanent reroll costs must increase each rank")
        progress=Classes.purchase(progress,"rerolls")
        require(int(progress.shop.rerolls)==rank+1,"Each purchase must retain the new permanent rank")
    require(Classes.purchase(progress,"rerolls").is_empty(),"Only five additional rerolls may be bought")
    var boosted=Model.new(Classes.configure(config,"warrior",progress))
    boosted.xp=boosted.xp_needed;boosted.check_level_up()
    for index in range(8):require(boosted.reroll_upgrades(),"Maximum permanent rank must allow eight rerolls")
    require(not boosted.reroll_upgrades(),"A ninth reroll must be rejected")
    var scarce=Model.new(config)
    for upgrade in scarce.config.upgrades:scarce.upgrade_ranks[upgrade.id]=upgrade.max_tier
    scarce.xp=scarce.xp_needed;scarce.check_level_up()
    require(not scarce.can_reroll() and scarce.rerolls_used==0,"No available alternatives must disable reroll without spending one")
    if not failed:print("GAMESHIFT_REROLLS_OK")
    quit(1 if failed else 0)
