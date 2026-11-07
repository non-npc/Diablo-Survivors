extends RefCounted
const COLORS={"fire":Color("ff784e"),"poison":Color("68db71"),"cold":Color("97ddff"),"lightning":Color("ffeb86"),"chaos":Color("bc88ee")}
const NAMES={"fire":"Scorched","poison":"Poisoned","cold":"Chilled","lightning":"Shocked","chaos":"Chaos-afflicted"}
const DURATIONS={"fire":3.0,"poison":5.0,"cold":2.5,"lightning":2.0,"chaos":3.0}
static func apply(target:Dictionary,element:String,power:float) -> void:
    if element not in COLORS:return
    if not target.has("ailments"):target["ailments"]={}
    var current:Dictionary=target.ailments.get(element,{})
    # Refresh a bounded duration and strongest potency, never add stacks.
    target.ailments[element]={"remaining":DURATIONS[element],"pulse_clock":float(current.get("pulse_clock",0)),"power":maxf(float(current.get("power",0)),maxf(0,power))}
static func tick(target:Dictionary,delta:float) -> float:
    var damage:=0.0
    for element in target.get("ailments",{}).keys():
        var effect:Dictionary=target.ailments[element]
        var step:float=minf(delta,float(effect.remaining))
        if element in ["fire","poison","chaos"]:
            var interval:float=0.75 if element=="chaos" else 0.5
            effect["pulse_clock"]=float(effect.get("pulse_clock",0))+step
            while effect.pulse_clock>=interval-0.000001:
                damage+=minf(12,float(effect.power))*interval;effect.pulse_clock=maxf(0,float(effect.pulse_clock)-interval)
            if float(effect.remaining)<=delta and element!="chaos":
                damage+=minf(12,float(effect.power))*float(effect.pulse_clock)
        effect.remaining=maxf(0,float(effect.remaining)-delta)
        if effect.remaining<=0:target.ailments.erase(element)
    return damage
static func speed(target:Dictionary) -> float:
    return 0.75 if target.get("ailments",{}).has("cold") else 1.0
static func vulnerability(target:Dictionary) -> float:
    return 1.15 if target.get("ailments",{}).has("lightning") else 1.0
