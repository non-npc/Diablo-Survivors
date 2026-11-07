extends RefCounted
var rng:=RandomNumberGenerator.new()
var schedule:Array=[]
var shapes:Array=[]
var next_event:=0
var pending:Dictionary={}
var active:Dictionary={}
var elite_used:=false
var events_started:=0
var last_event_time:=-1000.0
func _init(config:Dictionary) -> void:
    rng.seed=int(config.get("seed",1))+7391
    if config.get("mode","")=="cow" or config.get("formations_enabled",true)==false:return
    var duration:float=config.duration_seconds
    if duration<180:return
    var count:int=2 if duration<=480 else rng.randi_range(2,3)
    var choices:Array=["line","pincer","vee","circle","square","diamond"]
    for i in range(count):
        schedule.append(maxf(65,duration*(0.22+float(i)*0.55/maxi(1,count-1)+rng.randf_range(-0.025,0.025))))
        var index:int=rng.randi_range(0,choices.size()-1);shapes.append(choices.pop_at(index))
func eligible(model) -> Array:
    var result:Array=[]
    for kind in model.config.get("enemy_roster",["skeleton"]):
        var definition:Dictionary=model.config.get("enemy_definitions",{}).get(kind,{})
        if kind==model.config.get("boss","") or definition.get("unique",false) or definition.get("stationary",false):continue
        result.append(kind)
    return result
func clear_position(model,point:Vector2) -> Vector2:
    point=model.nearest_position(model.wrap_position(point),model.player)
    if model.navigation==null or model.navigation.can_stand(point):return point
    for i in range(24):
        var candidate:Vector2=point+Vector2.from_angle(TAU*float(i)/8)*float(24+24*(i/8))
        if model.navigation.can_stand(candidate):return candidate
    return Vector2.INF
func tick(model,delta:float) -> void:
    if not active.is_empty():
        active.age+=delta
        if active.age>=22:active.clear()
    if not pending.is_empty():
        pending.warning-=delta
        if pending.warning<=0:
            spawn(model,pending);pending={}
        return
    if model.elapsed>float(model.config.duration_seconds)-45:return
    if model.elapsed-last_event_time<90:return
    if next_event>=schedule.size() or not active.is_empty() or model.elapsed<float(schedule[next_event]):return
    var roster:Array=eligible(model)
    if roster.is_empty():next_event+=1;return
    var shape:String=shapes[next_event]
    var count:int=rng.randi_range(12,18) if shape in ["circle","square","diamond"] else rng.randi_range(8,12)
    if model.enemies.size()+count+1>mini(300,int(model.config.director.max_enemies)):return
    var kind:String=roster[rng.randi_range(0,roster.size()-1)]
    # Use available flying sprites; do not substitute unavailable artwork.
    var flying:Array=roster.filter(func(k):
        var text:String=(str(k)+str(model.config.get("enemy_definitions",{}).get(k,{}))).to_lower()
        return "bat" in text or "gargoyle" in text or "vulture" in text or "crow" in text or "hawk" in text or "flying" in text)
    if not flying.is_empty() and rng.randf()<0.4:kind=flying[rng.randi_range(0,flying.size()-1)]
    var element:String=""
    if rng.randf()<0.35:element=["fire","poison","cold","lightning","chaos"][rng.randi_range(0,4)]
    pending={"shape":shape,"kind":kind,"count":count,"center":model.player,"angle":rng.randf()*TAU,"warning":2.5,"element":element,"elite":not elite_used and shape in ["circle","square","diamond"] and rng.randf()<0.35}
    last_event_time=model.elapsed
    next_event+=1
    model.events.append({"kind":"formation_warning","position":model.player,"shape":shape,"elite":pending.elite})
func spawn(model,event:Dictionary) -> void:
    var radius:float=300+float(event.count-12)*9
    active={"center":event.center,"age":0.0,"shape":event.shape,"radius":radius,"id":next_event}
    var made:=0
    var placements:Array=[]
    for i in range(int(event.count)):
        # An intentionally missing sector provides an escape opening.
        var t:float=float(i)/maxi(1,int(event.count)-1)
        var offset:Vector2
        if event.shape in ["circle","square","diamond"]:
            var angle:float=event.angle+0.35+t*(TAU-0.7)
            offset=Vector2.from_angle(angle)
            if event.shape!="circle":
                if event.shape=="diamond":offset=offset.rotated(PI/4)
                offset/=maxf(absf(offset.x),absf(offset.y))
                if event.shape=="diamond":offset=offset.rotated(-PI/4)
            offset*=radius
        else:
            var along:float=(t-0.5)*float(event.count)*30
            offset=Vector2(along,-radius-(absf(along)*0.5 if event.shape=="vee" else 0))
            if event.shape=="pincer":offset.y=radius if i%2==0 else -radius
            offset=offset.rotated(event.angle)
        var point:Vector2=clear_position(model,event.center+offset)
        if not point.is_finite():continue
        if placements.any(func(slot):return Vector2(slot.point).distance_to(point)<22):continue
        placements.append({"point":point,"offset":offset})
    var minimum:int=12 if event.shape in ["circle","square","diamond"] else 8
    if placements.size()<minimum or model.enemies.size()+placements.size()+(1 if event.elite else 0)>mini(300,int(model.config.director.max_enemies)):
        active.clear();return
    for slot in placements:
        var before:int=model.enemies.size()
        model.spawn_at(slot.point,float(model.config.enemy.health)+model.wave*3,false,event.kind)
        if model.enemies.size()==before:continue
        var enemy:Dictionary=model.enemies.back()
        enemy["formation_id"]=active.id;enemy["formation_offset"]=slot.offset;enemy["element"]=event.element
        made+=1
    if made>0:events_started+=1
    if event.elite:
        var point:Vector2=clear_position(model,event.center)
        if point.is_finite() and model.enemies.size()<mini(300,int(model.config.director.max_enemies)):
            var before:int=model.enemies.size();model.spawn_at(point,float(model.config.enemy.health)*4+model.wave*6,true,event.kind)
            if model.enemies.size()>before:
                var enemy:Dictionary=model.enemies.back();enemy["miniboss"]=true;enemy["element"]=event.element;enemy["reward"]=12;enemy["radius"]=26.0;elite_used=true
func target(model,enemy:Dictionary) -> Vector2:
    if not enemy.has("formation_id"):return model.player
    var reach:float=float(enemy.get("ranged_max",210)) if enemy.get("ranged",false) else float(enemy.radius)+28
    if active.is_empty() or enemy.formation_id!=active.id or enemy.position.distance_to(model.player)<=reach:
        enemy.erase("formation_id");enemy.erase("route_cell");return model.player
    var center:Vector2=model.nearest_position(active.center,model.player)
    var shrinking:bool=active.shape in ["circle","square","diamond"]
    var factor:float=maxf(0.1,1-float(active.age)/12) if shrinking else 1.0
    if not shrinking:center=center.move_toward(model.player,float(active.age)*35)
    return center+Vector2(enemy.formation_offset)*factor
