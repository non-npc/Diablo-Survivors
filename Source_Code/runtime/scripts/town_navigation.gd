extends RefCounted
var document: Dictionary
var width: int
var height: int
var origin: Vector2
var cells: Array=[]
var available: Array=[]
var distances:=PackedInt32Array()
var target_cell: int=-1
var connections: Array=[]
var positions: Array=[]
var wrap_arena:=Rect2()
func _init(data: Dictionary) -> void:
    document=data;width=int(data.grid_width);height=int(data.grid_height)
    origin=Vector2(data.origin[0],data.origin[1]);cells=data.walkable
    for i in range(cells.size()):
        if int(cells[i])!=0:available.append(i)
        positions.append(world(i))
    for i in range(cells.size()):connections.append(build_neighbors(i))
func world(index: int) -> Vector2:
    var x:=index%width
    var y:=int(index/width)
    return positions[index] if positions.size()==cells.size() else origin+Vector2((x-y)*32,(x+y)*16)
func index_at(position: Vector2) -> int:
    if wrap_arena.size!=Vector2.ZERO:
        position=wrap_arena.position+Vector2(fposmod(position.x-wrap_arena.position.x,wrap_arena.size.x),fposmod(position.y-wrap_arena.position.y,wrap_arena.size.y))
    var point:=position-origin
    var x:=int(round(point.x/64+point.y/32))
    var y:=int(round(point.y/32-point.x/64))
    return y*width+x if x>=0 and y>=0 and x<width and y<height else -1
func open(position: Vector2,missile: bool=false) -> bool:
    var index:=index_at(position)
    if index<0:return wrap_arena.size!=Vector2.ZERO
    return int(document.missile_blocked[index])==0 if missile else int(cells[index])!=0
func can_stand(position: Vector2) -> bool:
    for offset in [Vector2.ZERO,Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
        if not open(position+offset):return false
    return true
func move(position: Vector2,offset: Vector2) -> Vector2:
    var steps:=maxi(1,int(ceil(offset.length()/3)))
    var step:=offset/steps
    for i in range(steps):
        if can_stand(position+step):position+=step
        else:
            # Town cell walls are diagonal in screen space; slide along their faces.
            var best:=Vector2.ZERO
            var best_progress:=0.0
            for tangent in [Vector2(2,1).normalized(),Vector2(2,-1).normalized(),Vector2.RIGHT,Vector2.DOWN]:
                var slide:Vector2=tangent*step.dot(tangent)
                var progress:float=slide.dot(step)
                if progress>best_progress and can_stand(position+slide):best=slide;best_progress=progress
            if best_progress>0:position+=best
            elif can_stand(position+step*0.5):position+=step*0.5
    return position
func clear_attack(start: Vector2,end: Vector2) -> bool:
    var steps:=maxi(1,int(ceil(start.distance_to(end)/3)))
    for i in range(steps+1):
        var point:=start.lerp(end,float(i)/steps)
        if not open(point) or not open(point,true):return false
    return true
func clear_shot(start: Vector2,end: Vector2) -> bool:
    var steps:=maxi(1,int(ceil(start.distance_to(end)/8)))
    for i in range(steps+1):
        if not open(start.lerp(end,float(i)/steps),true):return false
    return true
func neighbors(index: int) -> Array:
    return connections[index]
func build_neighbors(index: int) -> Array:
    var result:Array=[]
    var x:=index%width
    var y:=int(index/width)
    for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var nx:int=x+offset.x
        var ny:int=y+offset.y
        if nx>=0 and ny>=0 and nx<width and ny<height:
            var next:int=ny*width+nx
            if int(cells[next])!=0:result.append(next)
    return result
func update_flow(target: Vector2) -> void:
    var index:=index_at(target)
    if index==target_cell:return
    target_cell=index
    distances.resize(cells.size());distances.fill(-1)
    if index<0 or int(cells[index])==0:return
    var queue:Array=[index];distances[index]=0
    var cursor:=0
    while cursor<queue.size():
        var current:int=queue[cursor];cursor+=1
        for next in neighbors(current):
            if distances[next]<0:distances[next]=distances[current]+1;queue.append(next)
func clear_walk(start: Vector2,end: Vector2) -> bool:
    var steps:=maxi(1,int(ceil(start.distance_to(end)/8)))
    for step in range(steps+1):
        if not can_stand(start.lerp(end,float(step)/steps)):return false
    return true

func pursuit(position: Vector2,target: Vector2,agent: Dictionary={}) -> Vector2:
    if wrap_arena.size!=Vector2.ZERO and (not wrap_arena.has_point(position) or index_at(position)<0) and clear_walk(position,target):return (target-position).normalized()
    var index:=index_at(position)
    if index<0 or distances.is_empty() or distances[index]<0:return Vector2.ZERO
    if position.distance_squared_to(target)<=224*224 and clear_walk(position,target):
        agent.erase("route_cell")
        return (target-position).normalized()
    var waypoint:int=int(agent.get("route_cell",-1))
    if waypoint>=0 and waypoint<distances.size() and (distances[waypoint]<0 or distances[waypoint]>distances[index]):
        agent.erase("route_cell");waypoint=-1
    if waypoint>=0 and waypoint<cells.size() and int(cells[waypoint])!=0 and world(waypoint).distance_to(position)>3:
        if not clear_walk(position,world(waypoint)) and position.distance_to(world(index))>3:
            return (world(index)-position).normalized()
        return (world(waypoint)-position).normalized()
    if index==target_cell:return (target-position).normalized()
    var best:=index
    var choices:Array=[]
    for next in neighbors(index):
        if distances[next]<0:continue
        if distances[next]<distances[best]:
            best=next;choices=[next]
        elif distances[next]==distances[best] and next!=index:choices.append(next)
    # Stable individual preferences spread a crowd across equally short routes.
    if not choices.is_empty():best=choices[posmod(int(agent.get("id",0))*17+index*13,choices.size())]
    agent["route_cell"]=best
    return (world(best)-position).normalized()
