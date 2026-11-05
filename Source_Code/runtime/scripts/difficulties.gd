extends RefCounted
const ORDER=["easy","hard","legendary"]
static func title(difficulty:String) -> String:
    return {"easy":"Normal","hard":"Nightmare","legendary":"Hell"}.get(difficulty,difficulty.capitalize())
const MODES={
    "easy":{"seconds":480,"health":1.0,"damage":1.0,"speed":1.0,"spawn":1.0,"challenge":1.0},
    "hard":{"seconds":720,"health":1.3,"damage":1.2,"speed":1.04,"spawn":0.8,"challenge":1.75},
    "legendary":{"seconds":960,"health":1.65,"damage":1.4,"speed":1.08,"spawn":0.65,"challenge":2.75}
}
static func slot(area:String,difficulty:String="easy") -> String:
    return area if difficulty=="easy" or area=="cow" else area+"@"+difficulty
static func challenges(base:Array,difficulty:String,boss:String="") -> Array:
    var result:Array=base.duplicate(true)
    for challenge in result:
        if challenge.get("single_spawn",false):continue
        if challenge.get("enemy","")==boss and not boss.is_empty():continue
        var old_target:int=int(challenge.target)
        challenge.target=maxi(1,int(ceil(float(old_target)*float(MODES[difficulty].challenge))))
        challenge.title=str(challenge.title).replace(str(old_target),str(challenge.target))
    return result
static func configure(base:Dictionary,difficulty:String) -> Dictionary:
    var result:Dictionary=base.duplicate(true)
    var mode:Dictionary=MODES[difficulty]
    result["difficulty"]=difficulty;result.duration_seconds=mode.seconds
    result["difficulty_health_scale"]=mode.health;result["difficulty_damage_scale"]=mode.damage
    result.enemy.health*=mode.health;result.enemy.contact_damage*=mode.damage;result.enemy.speed*=mode.speed
    result.director.spawn_interval*=mode.spawn
    result.challenges=challenges(result.get("challenges",[]),difficulty,str(result.get("boss","")))
    return result
