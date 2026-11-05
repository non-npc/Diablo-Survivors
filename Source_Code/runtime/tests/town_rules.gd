extends SceneTree
const Navigation=preload("res://scripts/town_navigation.gd")
var failed:=false
func require(condition:bool,message:String) -> void:
    if not condition:push_error(message);failed=true
func _initialize() -> void:
    var cells:Array=[]
    for y in range(7):
        for x in range(7):cells.append(0 if x==0 or y==0 or x==6 or y==6 or (x==3 and y<4) else 1)
    var blocked:Array=[]
    for cell in cells:blocked.append(1-int(cell))
    var data={"grid_width":7,"grid_height":7,"origin":[300,100],"walkable":cells,"missile_blocked":blocked}
    var navigation=Navigation.new(data)
    for index in navigation.available:require(navigation.index_at(navigation.world(index))==index,"Projection must round trip")
    var start:Vector2=navigation.world(2+2*7)
    var end:Vector2=navigation.world(4+2*7)
    require(not navigation.clear_attack(start,end),"Melee must not pass through solid scenery")
    require(not navigation.clear_shot(start,end),"Projectile must stop at solid scenery")
    var stopped:Vector2=navigation.move(start,end-start)
    require(stopped.distance_to(end)>20 and navigation.can_stand(stopped),"Movement must not tunnel through wall")
    navigation.update_flow(end)
    var position:=start
    var agent:Dictionary={}
    for i in range(400):position=navigation.move(position,navigation.pursuit(position,end,agent)*2)
    require(position.distance_to(end)<8,"Flow routing must reach target around wall")
    var open_data=data.duplicate(true)
    open_data.walkable.fill(1);open_data.missile_blocked.fill(0)
    var open_map=Navigation.new(open_data)
    var enemy_position:Vector2=open_map.world(3+3*7)
    var approaching:Vector2=open_map.world(3+5*7)
    var stale_agent:Dictionary={"route_cell":3+2*7}
    for step in range(4):
        open_map.update_flow(approaching)
        var heading:Vector2=open_map.pursuit(enemy_position,approaching,stale_agent)
        require(heading.dot((approaching-enemy_position).normalized())>0.99,"Nearby approaching player must override old waypoint")
        approaching=approaching.move_toward(enemy_position,6)
    var large_cells:Array=[];large_cells.resize(225);large_cells.fill(1)
    var large_blocked:Array=[];large_blocked.resize(225);large_blocked.fill(0)
    var large=Navigation.new({"grid_width":15,"grid_height":15,"origin":[0,0],"walkable":large_cells,"missile_blocked":large_blocked})
    var distant:Vector2=large.world(13+13*15)
    var origin_point:Vector2=large.world(1+1*15)
    large.update_flow(distant)
    var routes:Dictionary={}
    for identity in range(8):
        var individual:Dictionary={"id":identity}
        large.pursuit(origin_point,distant,individual)
        routes[individual.route_cell]=true
        var walking:=origin_point
        for step in range(500):walking=large.move(walking,large.pursuit(walking,distant,individual)*2)
        require(walking.distance_to(distant)<8,"Individual routes must still reach the target")
    require(routes.size()==2,"Equally short routes must vary across enemies")
    var crowd_model=load("res://scripts/survival_model.gd").new(JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration)
    var crowd_enemy={"id":1,"position":Vector2(100,100),"radius":16}
    var bins={Vector2i(1,1):[{"id":2,"position":Vector2(103,100),"radius":16}]}
    var separated:Vector2=crowd_model.crowd_heading(crowd_enemy,Vector2.RIGHT,bins)
    require(separated.x>0.8 and absf(separated.y)>0.1,"Crowd spacing must spread enemies without retreating")
    require(not navigation.open(Vector2(-999,-999)),"Map bounds must be solid")
    var edge:Vector2=navigation.world(2+2*7)
    var original_edge:=edge
    for i in range(40):edge=navigation.move(edge,Vector2.RIGHT*2)
    require(edge.distance_to(original_edge)>35 and navigation.can_stand(edge),"Movement must slide along diagonal wall instead of sticking")
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival_demo.json")).configuration
    var fighter=load("res://scripts/survival_model.gd").new(config)
    fighter.navigation=navigation;fighter.player=start;fighter.stats.attack_range=200
    fighter.spawn_at(end,100)
    fighter.automatic_attack()
    require(fighter.enemies[0].health==100 and fighter.attacks==0,"Blocked enemy must not trigger or receive melee attack")
    fighter.enemies.clear();fighter.spawn_at(start+Vector2(0,-4),100)
    fighter.automatic_attack()
    require(fighter.enemies[0].health<100,"Visible adjacent enemy must remain attackable")
    var args:=OS.get_cmdline_user_args()
    if args.has("--map-document"):
        var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--map-document")+1]))
        var imported=Navigation.new(original)
        var destination:Vector2=imported.world(int(original.spawn_cell[1])*int(original.grid_width)+int(original.spawn_cell[0]))
        imported.update_flow(destination)
        for sample in range(10):
            var candidate:Vector2=imported.world(imported.available[int(sample*(imported.available.size()-1)/9)])
            var route:Dictionary={}
            for i in range(5000):
                if candidate.distance_to(destination)<8:break
                candidate=imported.move(candidate,imported.pursuit(candidate,destination,route)*2)
            require(candidate.distance_to(destination)<8,"Imported town route must reach player")
    if not failed:print("GAMESHIFT_TOWN_RULES_OK")
    quit(1 if failed else 0)
