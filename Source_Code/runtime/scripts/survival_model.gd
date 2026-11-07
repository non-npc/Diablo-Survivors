extends RefCounted
const Ailments=preload("res://scripts/ailments.gd")
const Formations=preload("res://scripts/formations.gd")
var formation_director:RefCounted
var player_conditions:Dictionary={"ailments":{}}
# Independent, seeded gameplay model. Rendering and source-game assets are external.
var portal: Dictionary={}
var kill_counts: Dictionary={}
var pickup_counts: Dictionary={}
var collected_xp := 0
var healing_received := 0.0
var loot_gold := 0
var rare_clock := 30.0
var goblin_appeared:=false
var navigation: RefCounted
var config: Dictionary
var rng := RandomNumberGenerator.new()
var player := Vector2.ZERO
var health := 100.0
var stats: Dictionary
var enemies: Array = []
var projectiles: Array = []
var fire_patches:Array=[]
var corpses: Array = []
var pickups: Array = []
var allies: Array = []
var ally_visible_bounds:=Rect2()
var allies_are_wisps:=true

func constrain_allies() -> void:
    var bounds:Rect2=ally_visible_bounds if ally_visible_bounds.has_area() else Rect2(player-Vector2(560,280),Vector2(1120,560))
    for index in range(allies.size()):
        var ally:Dictionary=allies[index]
        # Both glowing wisps and skeleton sprites need space around their owner.
        var offset:Vector2=ally.position-player
        # Keep minions clear of the full player sprite, including its head.
        var ellipse:=Vector2(offset.x/48.0,offset.y/72.0)
        if ellipse.length()<1.0:
            var direction:Vector2=ellipse.normalized() if ellipse.length()>0.01 else Vector2.from_angle(TAU*index/maxi(1,allies.size()))
            ally.position=player+Vector2(direction.x*48,direction.y*72)
        ally.position=Vector2(clampf(ally.position.x,bounds.position.x,bounds.end.x),clampf(ally.position.y,bounds.position.y,bounds.end.y))
var events: Array = []
var offered: Array = []
var run_upgrades: Dictionary={}
var upgrade_ranks: Dictionary={}
var base_stats: Dictionary={}
var xp_fraction:=0.0
var state := "playing"
var elapsed := 0.0
var level := 1
var xp := 0
var xp_needed := 5
var kills := 0
var attacks := 0
var total_damage := 0.0
var attack_clock := 0.0
var attack_cycle_interval:=1.0
var auto_attack_enabled:=true
var pending_manual_aim:=Vector2.ZERO

func request_manual_attack(target:Vector2) -> bool:
    if auto_attack_enabled or state!="playing" or attack_clock>0 or target.is_equal_approx(player):return false
    pending_manual_aim=(target-player).normalized()
    return true

func attack_interval() -> float:
    return maxf(maxf(0.12,float(stats.cooldown)),float(config.get("attack_interval_floor",0.12)))
var invulnerability := 0.0
var spawn_clock := 0.2
var spawned := 0
var wave := 1
var next_id := 1
var boss_spawned := false
var boss_wave_clock:=0.0
var unique_spawned:Dictionary={}
var arena := Rect2(0,0,2200,1800)
var surge_index:=-1
var surge_spawned:=0
var rerolls_used:=0

func surge_plan() -> Dictionary:
    var fraction:float=clampf(elapsed/float(config.duration_seconds),0,0.999)
    var stage:int=mini(3,int(fraction*4))
    var difficulty:String=config.get("difficulty","easy")
    var scale:float=1.4 if difficulty=="legendary" else 1.2 if difficulty=="hard" else 1.0
    var period:float=40 if difficulty!="easy" else 45
    var active:float=24+stage*4+(3 if difficulty!="easy" else 0)
    return {"stage":stage,"index":int(elapsed/period),"active":fmod(elapsed,period)<active,"limit":mini(300,mini(int(config.director.max_enemies),roundi(lerpf(40,130,fraction)*scale))),"quota":roundi((16+stage*10)*scale),"interval":maxf(0.3,lerpf(1.2,0.5,fraction)*float(config.director.spawn_interval)/1.2)}

func surge_kind() -> String:
    var plan:Dictionary=surge_plan();var melee:Array=[];var ranged:Array=[]
    for kind in config.get("enemy_roster",["skeleton"]):
        if kind==config.get("boss","") or config.get("enemy_definitions",{}).get(kind,{}).get("unique",false):continue
        if config.get("enemy_definitions",{}).get(kind,{}).get("ranged",false):ranged.append(kind)
        else:melee.append(kind)
    if melee.is_empty():return str(ranged[int(plan.index)%ranged.size()]) if not ranged.is_empty() else "" if not str(config.get("boss","")).is_empty() else "skeleton"
    if int(plan.stage)>0 and not ranged.is_empty() and rng.randf()<0.1*int(plan.stage):
        var count:int=mini(ranged.size(),int(plan.stage))
        return str(ranged[int(plan.index)%count])
    var count:int=1 if int(plan.stage)==0 else mini(melee.size(),maxi(1,ceili(melee.size()*float(plan.stage)/3)))
    return str(melee[int(plan.index)%count])

func wrap_position(point:Vector2) -> Vector2:
    return arena.position+Vector2(fposmod(point.x-arena.position.x,arena.size.x),fposmod(point.y-arena.position.y,arena.size.y))

func nearest_position(point:Vector2,reference:Vector2) -> Vector2:
    var offset:=point-reference
    return reference+Vector2(fposmod(offset.x+arena.size.x/2,arena.size.x)-arena.size.x/2,fposmod(offset.y+arena.size.y/2,arena.size.y)-arena.size.y/2)

func align_world() -> void:
    for collection in [enemies,projectiles,enemy_projectiles,pickups,powerups,corpses,fire_patches]:
        for item in collection:
            if item.position.is_finite():item.position=nearest_position(item.position,player)
    if not portal.is_empty():portal.position=nearest_position(portal.position,player)

func _init(configuration: Dictionary) -> void:
    config = configuration.duplicate(true)
    formation_director=Formations.new(config)
    var chamber_boss:String=config.get("boss","")
    var ordinary:Array=config.get("enemy_roster",[]).filter(func(kind):return kind!=chamber_boss and not config.get("enemy_definitions",{}).get(kind,{}).get("unique",false))
    config["boss_endurance"]=config.has("enemy_roster") and not chamber_boss.is_empty() and ordinary.is_empty()
    rare_clock=float(config.get("rare_events",{}).get("check_seconds",30))
    stats = config.player.duplicate(true)
    stats["max_health"] = float(stats.health)
    stats["summon_cap"] = int(stats.get("summon_cap",0))
    var defaults:Dictionary={"boost_duration":1.0,"attack_count":1,"area_scale":1.0,"armor":0.0,"regeneration":0.0,"crit_chance":0.05,"crit_multiplier":1.5,"knockback":24.0,"kill_heal":0.0,"heal_drop_chance":0.06,"xp_multiplier":1.0,"ally_damage":14.0,"ally_cooldown":0.7,"dot_damage":0.0,"retaliation":0.0,"projectile_speed":620.0 if config.get("weapon","")=="bow" else 430.0,"splash_ratio":0.6}
    for key in defaults:
        if not stats.has(key):stats[key]=defaults[key]
    for element in Ailments.COLORS:
        if not stats.has(element+"_power"):stats[element+"_power"]=0.0
    base_stats=stats.duplicate(true)
    stats["projectile_count"]=1;stats["projectile_pierce"]=0
    base_stats["projectile_count"]=1;base_stats["projectile_pierce"]=0
    config.director.max_enemies=mini(300,int(config.director.max_enemies))
    health = float(stats.health)
    arena.size = Vector2(config.get("arena_width",2200),config.get("arena_height",1800))
    player = arena.get_center()
    rng.seed = int(config.get("seed",1))

var enemy_projectiles:Array=[]
var powerups:Array=[]
var haste_clock:=0.0
var magnet_clock:=0.0
const POWERUP_DURATION:=35.0
const POWERUP_RESPAWN:=45.0
const POWERUP_SCREEN_SPACING:=Vector2(1344,784) # 1280x720 viewport plus glow/bob margin.
func powerups_share_screen(first:Vector2,second:Vector2) -> bool:
    var offset:Vector2=nearest_position(second,first)-first
    return absf(offset.x)<POWERUP_SCREEN_SPACING.x and absf(offset.y)<POWERUP_SCREEN_SPACING.y
func powerup_position(previous:Vector2) -> Vector2:
    for attempt in range(128):
        var point:Vector2
        if navigation!=null:
            point=navigation.world(navigation.available[rng.randi_range(0,navigation.available.size()-1)])
            if not navigation.can_stand(point):continue
        else:point=Vector2(rng.randf_range(arena.position.x+80,arena.end.x-80),rng.randf_range(arena.position.y+80,arena.end.y-80))
        point=nearest_position(point,player)
        if point.distance_to(player)<150 or (previous.is_finite() and nearest_position(previous,point).distance_to(point)<250):continue
        var crowded:=false
        for powerup in powerups:
            if powerup.active and powerups_share_screen(point,powerup.position):crowded=true;break
        if not crowded:return point
    return Vector2.INF
func update_powerups(delta:float) -> void:
    haste_clock=maxf(0,haste_clock-delta);magnet_clock=maxf(0,magnet_clock-delta)
    if not config.get("powerups_enabled",false):return
    if powerups.is_empty():
        for kind in ["healing","haste","magnet"]:
            var point:=powerup_position(Vector2.INF)
            powerups.append({"kind":kind,"position":point,"active":point.is_finite(),"respawn":POWERUP_RESPAWN if not point.is_finite() else 0.0})
        powerups.append({"kind":"vacuum","position":Vector2.INF,"active":false,"respawn":90.0})
    for powerup in powerups:
        if not powerup.active:
            powerup.respawn=maxf(0,float(powerup.respawn)-delta)
            if powerup.respawn<=0:
                if powerup.kind=="vacuum" and rng.randf()>0.2:
                    powerup.respawn=90.0;continue
                var point:=powerup_position(powerup.position)
                if point.is_finite():powerup.position=point;powerup.active=true
                else:powerup.respawn=1.0
            continue
        if powerup.position.distance_to(player)>26:continue
        match powerup.kind:
            "healing":health=minf(float(stats.max_health),health+float(stats.max_health)*0.35)
            "haste":haste_clock=POWERUP_DURATION*float(stats.boost_duration)
            "magnet":magnet_clock=POWERUP_DURATION*float(stats.boost_duration)
            "vacuum":
                for pickup in pickups:
                    if int(pickup.get("xp",0))>0 and int(pickup.get("gold",0))==0:pickup["magnet_pull"]=true
        powerup.active=false;powerup.respawn=180.0 if powerup.kind=="vacuum" else POWERUP_RESPAWN
        events.append({"kind":"powerup","powerup":powerup.kind,"position":player})
    if magnet_clock>0:
        for pickup in pickups:
            if int(pickup.get("gold",0))==0 and pickup.position.distance_to(player)<650:pickup.position=pickup.position.move_toward(player,800*delta)

func directed_enemy_kind() -> String:
    var boss:String=config.get("boss","")
    if not boss.is_empty() and elapsed>=float(config.duration_seconds)*0.8 and not boss_spawned:return boss
    return surge_kind()

func spawn_at(position: Vector2, hitpoints: float, elite: bool = false, kind:String="skeleton") -> void:
    if navigation!=null and not navigation.can_stand(position):return
    if enemies.size() >= mini(300,int(config.director.max_enemies)): return
    enemies.append({"id":next_id,"position":position,"health":hitpoints,"speed":float(config.enemy.speed)+wave*2,"damage":float(config.enemy.contact_damage)*(2 if elite else 1),"facing":0,"age":0.0,"hit":0.0,"elite":elite,"reward":5 if elite else 1,"radius":22.0 if elite else 16.0})
    var enemy:Dictionary=enemies.back()
    enemy["kind"]=kind;enemy["attack_age"]=0.0
    enemy["ailments"]={};enemy["element"]=""
    if elapsed>65 and config.get("mode","")!="cow" and formation_director.rng.randf()<0.045:
        enemy.element=Ailments.COLORS.keys()[formation_director.rng.randi_range(0,4)]
    var definition:Dictionary=config.get("enemy_definitions",{}).get(kind,{})
    enemy["ranged"]=definition.get("ranged",false);enemy["missile"]=definition.get("missile","spell");enemy["shot_clock"]=rng.randf_range(1,2)
    if definition.get("stationary",false):enemy.speed=0
    var breath:bool=definition.get("ai_reference","")=="AI_MEGA"
    enemy["ranged_min"]=float(definition.get("ranged_min",25 if breath else 80))*0.5;enemy["ranged_max"]=float(definition.get("ranged_max",240 if breath else 420))*0.5
    enemy["shot_interval"]=float(definition.get("shot_interval",2));enemy["projectile_speed"]=float(definition.get("projectile_speed",320 if enemy.missile=="arrow" else 270))
    enemy.health*=float(definition.get("health_scale",1.0));enemy.speed*=float(definition.get("speed_scale",1.0))
    if kind==config.get("boss",""):
        boss_spawned=true;enemy["boss"]=true;enemy.health*=6;enemy.reward=30
    next_id += 1

func spawn_directed(kind_override:String="") -> void:
    if enemies.size()>=mini(300,int(config.director.max_enemies)):return
    var chosen_kind:String=kind_override if not kind_override.is_empty() else directed_enemy_kind()
    if config.get("mode","")!="cow" and chosen_kind.is_empty():return
    if config.get("mode","")=="cow":
        var position:Vector2=player+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(720,900)
        var before:=enemies.size()
        spawn_at(position,18+minf(12,wave*0.5),false,"cow")
        if enemies.size()>before:
            var cow:Dictionary=enemies.back()
            cow["kind"]="cow";cow.speed=75+minf(35,wave);cow.damage=3;cow.reward=1
        return
    var position := player
    if navigation!=null:
        var found:=false
        for attempt in range(128):
            position=navigation.world(navigation.available[rng.randi_range(0,navigation.available.size()-1)])
            position=nearest_position(position,player)
            var offset:Vector2=position-player
            if offset.length()>=760 and offset.length()<=1200 and (absf(offset.x)>680 or absf(offset.y)>400):found=true;break
        if not found:return
        var elite:=elapsed>=float(config.duration_seconds)*0.5 and spawned%12==11
        spawn_at(position,(float(config.enemy.health)+wave*3)*(3 if elite else 1),elite,chosen_kind)
        spawned+=1
        return
    for attempt in range(24):
        position = player+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(760,900)
        var offset := position-player
        if absf(offset.x)>680 or absf(offset.y)>400: break
    var elite := elapsed>=float(config.duration_seconds)*0.5 and spawned%12==11
    spawn_at(position,(float(config.enemy.health)+wave*3)*(3 if elite else 1),elite,chosen_kind)
    spawned += 1

func direction_index(direction: Vector2) -> int:
    return (int(round((direction.angle()-PI/2)/(PI/4)))+8)%8

func damage_enemy(enemy: Dictionary, amount: float, source: Vector2, effects:bool=true,element:String="") -> void:
    if enemy.health <= 0: return
    var critical:=false
    if effects:
        amount=maxf(1.0,roundf(amount*rng.randf_range(0.85,1.15)))
        critical=rng.randf()<clampf(float(stats.crit_chance),0.0,1.0)
        if critical:amount=roundf(amount*float(stats.crit_multiplier))
    amount*=Ailments.vulnerability(enemy)
    enemy.health -= amount
    if enemy.health>0:
        if not element.is_empty():Ailments.apply(enemy,element,amount*0.12)
        if effects:
            for affinity in Ailments.COLORS:
                if float(stats.get(affinity+"_power",0))>0 and rng.randf()<minf(0.6,float(stats[affinity+"_power"])*0.2):
                    Ailments.apply(enemy,affinity,amount*0.12)
    enemy.hit = 0.16
    var push: Vector2 = enemy.position-source
    if effects:
        enemy.position=navigation.move(enemy.position,push.normalized()*float(stats.knockback)) if navigation!=null else enemy.position+push.normalized()*float(stats.knockback)
        if float(stats.dot_damage)>0:
            Ailments.apply(enemy,"poison",float(stats.dot_damage))
    total_damage += amount
    events.append({"kind":"damage","actor":enemy.get("kind","skeleton"),"fatal":enemy.health<=0,"position":enemy.position,"amount":amount,"critical":critical,"impact":effects})
    if enemy.health <= 0:
        health=minf(float(stats.max_health),health+float(stats.kill_heal))
        kills += 1
        var kind:String=enemy.get("kind","skeleton")
        kill_counts[kind]=int(kill_counts.get(kind,0))+1
        var durations:Array=config.get("death_durations",{}).get(kind,[])
        var duration:float=float(durations[int(enemy.facing)%durations.size()]) if not durations.is_empty() else 3.0
        corpses.append({"kind":kind,"position":enemy.position,"facing":enemy.facing,"age":0.0,"elite":enemy.elite,"animation_duration":duration,"lifetime":maxf(4.0,duration+1.0)})
        # Reclaim finished bodies first; never truncate an active death sequence.
        if corpses.size()>80:
            for corpse_index in range(corpses.size()):
                if corpses[corpse_index].age>=float(corpses[corpse_index].get("animation_duration",3.0)):
                    corpses.remove_at(corpse_index);break
        pickups.append({"position":enemy.position,"xp":enemy.reward,"heal":0})
        if rng.randf()<float(stats.heal_drop_chance): pickups.append({"position":enemy.position+Vector2(12,0),"xp":0,"heal":10})
        events.append({"kind":"kill","actor":enemy.get("kind","skeleton"),"position":enemy.position,"player_impact":effects})
        if enemy.get("kind","")=="goblin":
            pickups.append({"position":enemy.position,"xp":30,"heal":15,"gold":25})
            events.append({"kind":"treasure","position":enemy.position})
            if rng.randf()<float(config.get("rare_events",{}).get("portal_chance",0.01)):
                portal={"position":enemy.position,"remaining":60.0}
                events.append({"kind":"portal","position":enemy.position})

func automatic_attack(manual_aim:Vector2=Vector2.ZERO) -> void:
    var nearest: Dictionary = {}
    var distance := float(stats.attack_range)*(float(stats.area_scale) if config.get("weapon","sword")=="sword" else 1.0)+1
    for enemy in enemies:
        if enemy.health <= 0: continue
        var candidate: float = player.distance_to(enemy.position)
        if candidate<distance and (navigation==null or navigation.clear_attack(player,enemy.position)):
            distance=candidate;nearest=enemy
    if nearest.is_empty() and manual_aim==Vector2.ZERO: return
    var aim: Vector2 = manual_aim if manual_aim!=Vector2.ZERO else (nearest.position-player).normalized()
    attacks += 1
    events.append({"kind":"attack","position":player,"direction":aim,"target_id":int(nearest.get("id",-1)) if manual_aim==Vector2.ZERO else -1})
    var repeats:int=maxi(1,int(stats.attack_count))
    var weapon:String=config.get("weapon","sword")
    if weapon!="sword":
        var spell:String=config.get("spell_kind","")
        repeats=clampi(int(stats.projectile_count)+(2 if spell=="firestorm" else 0),1,5)
        for repeat in range(repeats):
            if projectiles.size()>=192:break
            var direction:=aim.rotated((repeat-(repeats-1)*0.5)*(0.2 if spell=="firestorm" else 0.06))
            projectiles.append({"position":player,"velocity":direction*float(stats.projectile_speed),"damage":float(stats.damage),"age":0.0,"distance_travelled":0.0,"max_distance":float(stats.attack_range),"weapon":weapon,"hit_ids":[],"remaining":(int(stats.attack_targets) if weapon=="bow" else 1)+int(stats.projectile_pierce)})
            projectiles.back()['spell']=spell
            projectiles.back()['release_delay']=0.16 if not spell.is_empty() else 0.0
            if spell=='bonespear':projectiles.back().remaining=maxi(2,int(stats.attack_targets)+1)+int(stats.projectile_pierce)
            if spell=='firestorm':
                projectiles.back().velocity=direction*float(stats.projectile_speed)*0.56
                projectiles.back()['heading']=direction
                projectiles.back()['phase']=float(repeat)*2.1
                projectiles.back()['trail_clock']=0.0
            var offsets:Array=config.get("projectile_visual_offsets",[])
            projectiles.back()["visual_offset"]=offsets[direction_index(aim)%offsets.size()] if not offsets.is_empty() else Vector2(0,-28)
    else:
        var reach:float=float(stats.attack_range)*float(stats.area_scale)
        var half_angle:float=minf(PI,acos(0.15)*float(stats.area_scale))
        for repeat in range(repeats):
            var count:=0
            for enemy in enemies:
                if enemy.health<=0:continue
                var offset:Vector2=enemy.position-player
                if offset.length()<=reach and offset.normalized().dot(aim)>=cos(half_angle) and (navigation==null or navigation.clear_attack(player,enemy.position)):
                    damage_enemy(enemy,float(stats.damage),player);count+=1
                    if count>=int(stats.attack_targets):break
            if repeat>0:events.append({"kind":"extra_strike","position":player,"direction":aim.rotated(repeat*0.07)})
    attack_cycle_interval=attack_interval()
    attack_clock=attack_cycle_interval


func eligible_upgrades() -> Array:
    var pool:Array=[]
    for upgrade in config.upgrades:
        var rank:int=int(upgrade_ranks.get(upgrade.id,0))
        if rank>=int(upgrade.get("max_tier",5)):continue
        if upgrade.has("classes") and config.get("archetype",config.get("class_id","warrior")) not in upgrade.classes:continue
        if upgrade.has("requires") and int(upgrade_ranks.get(upgrade.requires,0))<=0:continue
        var choice:Dictionary=upgrade.duplicate(true)
        choice["tier"]=rank+1;choice["previous_tier"]=rank
        pool.append(choice)
    return pool

func tier_value(upgrade:Dictionary,tier:int) -> float:
    var baseline:float=float(base_stats.get(upgrade.stat,0))
    var step:float=float(upgrade.get("step",upgrade.get("add",0)))
    var result:=baseline+step*tier
    if upgrade.get("mode","")=="multiply":result=baseline*(1+step*tier)
    elif upgrade.get("mode","")=="reduce":result=baseline*(1-step*tier)
    if upgrade.stat in ["cooldown","ally_cooldown"]:result=maxf(0.12,result)
    return result

func check_level_up() -> void:
    if xp < xp_needed or state != "playing": return
    xp -= xp_needed;level += 1;xp_needed=ceili(xp_needed*1.75)
    roll_upgrade_choices()
    state="upgrade"

func roll_upgrade_choices(exclude:Array=[]) -> void:
    var pool:Array=eligible_upgrades()
    pool=pool.filter(func(upgrade):return upgrade.id not in exclude)
    offered.clear()
    # Include one new and one owned upgrade when both groups are available.
    for group in ["owned","new","any"]:
        var candidates:Array=[]
        for i in range(pool.size()):
            var owned:bool=pool[i].previous_tier>0
            if group=="any" or (group=="owned" and owned) or (group=="new" and not owned):candidates.append(i)
        if candidates.is_empty():continue
        var index:int=candidates[rng.randi_range(0,candidates.size()-1)]
        offered.append(pool.pop_at(index))
    while offered.size()<3 and not pool.is_empty():offered.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
    if offered.is_empty():offered.append({"id":"recovery","title":"Recovery","description":"All eligible upgrades are maxed. Restore 25 health.","recovery":true,"icon":1})
    state="upgrade"

func reroll_limit() -> int:
    return clampi(int(config.get("reroll_limit",3)),3,8)

func can_reroll() -> bool:
    if state!="upgrade" or rerolls_used>=reroll_limit():return false
    var ids:Array=[]
    for upgrade in offered:ids.append(upgrade.id)
    for upgrade in eligible_upgrades():
        if upgrade.id not in ids:return true
    return false

func reroll_upgrades() -> bool:
    if not can_reroll():return false
    var excluded:Array=[]
    for upgrade in offered:excluded.append(upgrade.id)
    roll_upgrade_choices(excluded);rerolls_used+=1
    return true

func choose_upgrade(index: int) -> bool:
    if state!="upgrade" or index<0 or index>=offered.size():return false
    var upgrade:Dictionary=offered[index]
    if upgrade.get("recovery",false):health=minf(float(stats.max_health),health+25)
    else:
        var tier:int=int(upgrade_ranks.get(upgrade.id,0))+1
        if tier>int(upgrade.get("max_tier",5)):return false
        upgrade_ranks[upgrade.id]=tier;run_upgrades[upgrade.title]=tier
        var previous_boost_duration:float=stats.boost_duration
        stats[upgrade.stat]=tier_value(upgrade,tier)
        if upgrade.stat=="boost_duration":
            var extension:float=POWERUP_DURATION*(float(stats.boost_duration)-previous_boost_duration)
            if haste_clock>0:haste_clock+=extension
            if magnet_clock>0:magnet_clock+=extension
        health=minf(float(stats.max_health),health+float(upgrade.get("heal",0)))
    offered.clear();state="playing";check_level_up()
    return true

func tick(delta: float, movement: Vector2) -> void:
    events.clear()
    if state!="playing":return
    if navigation!=null:navigation.wrap_arena=arena
    align_world()
    elapsed=minf(elapsed+delta,float(config.duration_seconds))
    if elapsed>=float(config.duration_seconds):
        state="cow_complete" if config.get("mode","")=="cow" else "victory"
        events.append({"kind":"run_complete","position":player})
        return
    wave = int(elapsed/float(config.director.wave_seconds))+1
    var plan:Dictionary=surge_plan()
    if config.get("mode","")!="cow":
        wave=int(plan.index)+1
        if surge_index!=int(plan.index):surge_index=int(plan.index);surge_spawned=0
    formation_director.tick(self,delta)
    var ailment_damage:float=Ailments.tick(player_conditions,delta)
    if ailment_damage>0:
        health=maxf(0,health-ailment_damage*Ailments.vulnerability(player_conditions))
        if health<=0:
            state="dead";events.append({"kind":"player_death","position":player});return
    update_powerups(delta)
    var displacement:=movement.limit_length()*float(stats.speed)*Ailments.speed(player_conditions)*(1.35 if haste_clock>0 else 1.0)*delta
    player=navigation.move(player,displacement) if navigation!=null else player+displacement
    var unwrapped_player:Vector2=player
    player=wrap_position(player)
    var seam_shift:Vector2=player-unwrapped_player
    if seam_shift!=Vector2.ZERO:
        for ally in allies:ally.position+=seam_shift
        if ally_visible_bounds.has_area():ally_visible_bounds.position+=seam_shift
    align_world()
    if navigation!=null:navigation.update_flow(player)
    health=minf(float(stats.max_health),health+float(stats.regeneration)*delta)
    invulnerability=maxf(0,invulnerability-delta)
    attack_clock-=delta
    spawn_clock-=delta
    if spawn_clock<=0:
        if config.get("mode","")=="cow":
            spawn_directed();spawn_clock=maxf(0.25,float(config.director.spawn_interval)-wave*0.075)
        else:
            if plan.active and enemies.size()<int(plan.limit) and surge_spawned<int(plan.quota):
                var before:int=enemies.size();spawn_directed()
                if enemies.size()>before:surge_spawned+=1
            spawn_clock=float(plan.interval)
    if config.get("mode","")!="cow" and not boss_spawned and elapsed>=float(config.duration_seconds)*0.8:
        var previous_count := enemies.size()
        spawn_directed()
        if enemies.size()>previous_count:
            enemies.back().health=500.0*float(config.get("difficulty_health_scale",1));enemies.back().elite=true;enemies.back().reward=20;enemies.back().damage=14.0*float(config.get("difficulty_damage_scale",1))
        boss_spawned=true
    var uniques:Array=config.get("unique_roster",[])
    if config.get("boss_endurance",false):
        var live_boss:bool=enemies.any(func(enemy):return enemy.health>0 and enemy.kind==config.boss)
        if live_boss:boss_wave_clock=60.0
        else:boss_wave_clock=maxf(0,boss_wave_clock-delta)
        if not live_boss and elapsed>=5 and boss_wave_clock<=0:spawn_directed(str(config.boss))
    for index in range(uniques.size()):
        var kind:String=uniques[index]
        var threshold:float=float(config.get("enemy_definitions",{}).get(kind,{}).get("spawn_after",float(config.duration_seconds)*(0.5+0.04*index)))
        if unique_spawned.has(kind) or elapsed<threshold:continue
        var before:int=enemies.size();spawn_directed(kind)
        if enemies.size()>before:
            unique_spawned[kind]=true;enemies.back().elite=true;enemies.back().reward=15
    var crowd_bins:Dictionary={}
    for member in enemies:
        if member.health<=0 or member.get("kind","")=="goblin":continue
        var bin:=Vector2i(floori(member.position.x/64.0),floori(member.position.y/64.0))
        if not crowd_bins.has(bin):crowd_bins[bin]=[]
        crowd_bins[bin].append({"id":member.id,"position":member.position,"radius":member.radius})
    for enemy in enemies:
        if enemy.health<=0:continue
        var status_damage:float=Ailments.tick(enemy,delta)
        if status_damage>0:
            damage_enemy(enemy,status_damage,enemy.position,false)
            if enemy.health<=0:continue
        if float(enemy.get("dot_remaining",0))>0:
            enemy.dot_remaining=maxf(0,float(enemy.dot_remaining)-delta)
            enemy.dot_clock=float(enemy.dot_clock)-delta
            if enemy.dot_clock<=0:
                damage_enemy(enemy,float(enemy.dot_dps)*0.5,enemy.position,false);enemy.dot_clock=0.5
                if enemy.health<=0:continue
        if enemy.get("kind","")=="goblin":
            update_goblin(enemy,delta);continue
        var direction: Vector2 = player-enemy.position
        var destination:Vector2=formation_director.target(self,enemy)
        var heading:Vector2=(destination-enemy.position).normalized()
        if navigation!=null and (not enemy.has("formation_id") or not navigation.clear_walk(enemy.position,destination)):
            heading=navigation.pursuit(enemy.position,player,enemy)
        var travel:Vector2=heading*float(enemy.speed)*Ailments.speed(enemy)*delta
        travel=crowd_heading(enemy,travel,crowd_bins)*travel.length()
        enemy.shot_clock=float(enemy.get("shot_clock",0))-delta
        var in_range:bool=enemy.get("ranged",false) and direction.length()<=float(enemy.ranged_max)
        var clear:bool=not in_range or navigation==null or navigation.clear_shot(enemy.position,player)
        var firing:bool=in_range and direction.length()>=float(enemy.ranged_min) and clear
        # Hold position when the player closes the gap; do not chase or auto-retreat.
        if in_range and clear:travel=Vector2.ZERO
        if firing:
            travel=Vector2.ZERO
            if enemy.shot_clock<=0 and enemy_projectiles.size()<96:
                enemy_projectiles.append({"position":enemy.position,"velocity":direction.normalized()*float(enemy.projectile_speed),"damage":float(enemy.damage),"age":0.0,"distance_travelled":0.0,"max_distance":float(enemy.ranged_max),"missile":enemy.missile,"element":enemy.get("element","") if not str(enemy.get("element","")).is_empty() else {"fire":"fire","firebolt":"fire","fireball":"fire","acid":"poison","poison":"poison","ice":"cold","lightning":"lightning"}.get(str(enemy.missile),"")})
                enemy.shot_clock=float(enemy.shot_interval);enemy["attack_age"]=0.35
                events.append({"kind":"enemy_attack","actor":enemy.kind,"position":enemy.position})
        if float(enemy.get("attack_age",0))>0:travel=Vector2.ZERO
        enemy.position=navigation.move(enemy.position,travel) if navigation!=null else enemy.position+travel
        enemy.facing=direction_index(direction);enemy.age+=delta;enemy.hit=maxf(0,enemy.hit-delta)
    if auto_attack_enabled and attack_clock<=0:automatic_attack()
    elif not auto_attack_enabled and pending_manual_aim!=Vector2.ZERO and attack_clock<=0:automatic_attack(pending_manual_aim)
    pending_manual_aim=Vector2.ZERO
    for i in range(projectiles.size()-1,-1,-1):
        var shot: Dictionary=projectiles[i]
        if float(shot.get('release_delay',0))>0:
            shot.release_delay=maxf(0,float(shot.release_delay)-delta)
            if shot.release_delay>0:continue
            shot.position=player
        var start: Vector2=shot.position
        if shot.get('spell','')=='firestorm':shot.velocity=shot.heading.rotated(sin(shot.age*8.0+shot.phase)*0.32)*float(stats.projectile_speed)*0.56
        var remaining_distance:float=maxf(0,float(shot.get("max_distance",stats.attack_range))-float(shot.get("distance_travelled",0)))
        var shot_step:Vector2=(shot.velocity*delta).limit_length(remaining_distance)
        shot.position+=shot_step;shot.age+=delta
        shot["distance_travelled"]=float(shot.get("distance_travelled",0))+shot_step.length()
        var reached_limit:bool=float(shot.distance_travelled)>=float(shot.get("max_distance",stats.attack_range))-0.001
        if navigation!=null and not navigation.clear_shot(start,shot.position):projectiles.remove_at(i);continue
        if shot.get('spell','')=='firestorm':
            shot.trail_clock-=delta
            if shot.trail_clock<=0:
                if fire_patches.size()<192:fire_patches.append({'position':shot.position,'age':0.0,'lifetime':1.65,'damage':shot.damage*0.2,'radius':22.0*float(stats.area_scale)})
                shot.trail_clock=0.12
            if reached_limit:projectiles.remove_at(i)
            continue
        var hits:Array=[]
        for enemy in enemies:
            if enemy.health<=0 or enemy.id in shot.hit_ids:continue
            var closest:=Geometry2D.get_closest_point_to_segment(enemy.position,start,shot.position)
            if closest.distance_to(enemy.position)<=float(enemy.radius)+5:hits.append({"enemy":enemy,"distance":start.distance_to(closest)})
        hits.sort_custom(func(a,b):return a.distance<b.distance)
        var spent:=false
        for collision in hits:
            var struck:Dictionary=collision.enemy
            if shot.weapon=="firebolt" and shot.get("spell","")!="bonespear":events.append({"kind":"firebolt_impact","position":struck.position})
            var impact:Vector2=struck.position
            damage_enemy(struck,shot.damage,start,true,"fire" if shot.get("spell","")=="firebolt" else "")
            shot.hit_ids.append(struck.id);shot.remaining-=1
            if shot.weapon=="firebolt" and shot.get("spell","")!="bonespear":
                var targets:=1
                for enemy in enemies:
                    if targets>=int(stats.attack_targets):break
                    if enemy!=struck and enemy.health>0 and enemy.position.distance_to(impact)<float(stats.get("splash_radius",65))*float(stats.area_scale) and (navigation==null or navigation.clear_attack(impact,enemy.position)):
                        damage_enemy(enemy,shot.damage*float(stats.splash_ratio),impact,true,"fire")
                        targets+=1
                        if targets>=int(stats.attack_targets):break
            if shot.remaining<=0:spent=true;break
        if spent or reached_limit:projectiles.remove_at(i)
    for i in range(fire_patches.size()-1,-1,-1):
        fire_patches[i].age+=delta
        if fire_patches[i].age>=fire_patches[i].lifetime:fire_patches.remove_at(i)
    if not fire_patches.is_empty():
        for enemy in enemies:
            enemy['firestorm_clock']=maxf(0,float(enemy.get('firestorm_clock',0))-delta)
            if enemy.health<=0 or enemy.firestorm_clock>0:continue
            for patch in fire_patches:
                if enemy.position.distance_to(patch.position)<=float(enemy.radius)+float(patch.radius) and (navigation==null or navigation.clear_attack(patch.position,enemy.position)):
                    damage_enemy(enemy,float(patch.damage),patch.position,false,"fire")
                    enemy.firestorm_clock=0.25;break
    for i in range(enemy_projectiles.size()-1,-1,-1):
        var shot:Dictionary=enemy_projectiles[i];var start:Vector2=shot.position
        var shot_limit:float=float(shot.get("max_distance",shot.velocity.length()))
        var enemy_step:Vector2=(shot.velocity*delta).limit_length(maxf(0,shot_limit-float(shot.get("distance_travelled",0))))
        shot.position+=enemy_step;shot.age+=delta
        shot["distance_travelled"]=float(shot.get("distance_travelled",0))+enemy_step.length()
        if navigation!=null and not navigation.clear_shot(start,shot.position):
            enemy_projectiles.remove_at(i);continue
        if Geometry2D.get_closest_point_to_segment(player,start,shot.position).distance_to(player)<15:
            enemy_projectiles.remove_at(i)
            if invulnerability<=0:
                var received:=maxf(1,float(shot.damage)-float(stats.armor))
                health-=received*Ailments.vulnerability(player_conditions);invulnerability=0.7
                Ailments.apply(player_conditions,str(shot.get("element","")),received*0.12)
                events.append({"kind":"player_hit","position":player,"amount":received})
                if health<=0:
                    events.append({"kind":"player_death","position":player});health=0;state="dead";return
        elif float(shot.distance_travelled)>=shot_limit-0.001:enemy_projectiles.remove_at(i)
    for enemy in enemies:
        enemy["attack_age"]=maxf(0,float(enemy.get("attack_age",0))-delta)
        if enemy.get("kind","")=="goblin":continue
        if enemy.health>0 and player.distance_to(enemy.position)<float(enemy.radius)+12 and invulnerability<=0 and (navigation==null or navigation.clear_attack(enemy.position,player)):
            var received:=maxf(1,float(enemy.damage)-float(stats.get("armor",0)))
            health-=received*Ailments.vulnerability(player_conditions);invulnerability=0.7
            Ailments.apply(player_conditions,str(enemy.get("element","")),received*0.12)
            if float(stats.retaliation)>0:
                for nearby in enemies:
                    if nearby.health>0 and nearby.position.distance_to(player)<90 and (navigation==null or navigation.clear_attack(player,nearby.position)):damage_enemy(nearby,float(stats.retaliation),player,false)
            enemy["attack_age"]=0.35
            events.append({"kind":"enemy_attack","actor":enemy.get("kind","skeleton"),"position":enemy.position})
            events.append({"kind":"player_hit","position":player,"amount":received})
            if health<=0:
                events.append({"kind":"player_death","position":player})
                health=0;state="dead";return
    for i in range(enemies.size()-1,-1,-1):
        if enemies[i].health<=0:enemies.remove_at(i)
    for corpse in corpses:corpse.age+=delta
    for i in range(corpses.size()-1,-1,-1):
        if corpses[i].age>float(corpses[i].get("lifetime",4.0)):corpses.remove_at(i)
    for i in range(pickups.size()-1,-1,-1):
        var pickup: Dictionary = pickups[i]
        var offset: Vector2 = player-pickup.position
        if int(pickup.get("gold",0))==0:
            if pickup.get("magnet_pull",false):pickup.position=pickup.position.move_toward(player,650*delta)
            elif offset.length()<float(stats.pickup_radius):pickup.position=pickup.position.move_toward(player,370*delta)
        offset=player-pickup.position
        if offset.length()<18:
            var kind: String="treasure" if pickup.get("gold",0)>0 else "healing" if pickup.heal>0 else "xp"
            if pickup.get("gold",0)>0:pass # Treasure gets its own reward chime after amounts are calculated.
            elif pickup.heal>0:events.append({"kind":"healing_pickup","position":player})
            elif pickup.xp>0:events.append({"kind":"xp_pickup","position":player})
            pickup_counts[kind]=int(pickup_counts.get(kind,0))+1
            xp_fraction+=float(pickup.xp)*float(stats.xp_multiplier)
            var gained:int=int(floor(xp_fraction));xp_fraction-=gained
            xp+=gained;collected_xp+=gained;loot_gold+=int(pickup.get("gold",0))
            var healed:float=minf(float(stats.max_health),health+float(pickup.heal))
            if kind=="treasure":events.append({"kind":"treasure_collected","position":player,"gold":int(pickup.get("gold",0)),"xp":gained,"healing":healed-health})
            healing_received+=healed-health;health=healed;pickups.remove_at(i)
    if pickups.size()>2000:
        for pickup_index in range(pickups.size()):
            if int(pickups[pickup_index].get("gold",0))==0:
                pickups.remove_at(pickup_index);break
    while allies.size()<int(stats.summon_cap):
        var slot:int=allies.size()
        var formation:Vector2=Vector2.from_angle(TAU*slot/maxi(1,int(stats.summon_cap)))*40
        allies.append({"position":player+formation,"age":0.0,"cooldown":float(stats.ally_cooldown)*slot/maxi(1,int(stats.summon_cap)),"health":30.0,"owner":"player"})
    var claimed_targets:Dictionary={}
    for ally_index in range(allies.size()):
        var ally:Dictionary=allies[ally_index]
        ally["previous_position"]=ally.position
        ally["attack_age"]=float(ally.get("attack_age",10.0))+delta
        ally.age+=delta;ally.cooldown-=delta
        var target: Dictionary={}
        var best_score:=INF
        for enemy in enemies:
            var distance:float=ally.position.distance_to(enemy.position)
            if enemy.health<=0 or distance>=320:continue
            if ally_visible_bounds.has_area() and not ally_visible_bounds.has_point(enemy.position):continue
            var score:float=distance+(400 if claimed_targets.has(enemy.id) else 0)
            if int(ally.get("target_id",-1))==int(enemy.id):score-=35
            if score<best_score:target=enemy;best_score=score
        var formation:=Vector2.from_angle(TAU*ally_index/maxi(1,allies.size())+(elapsed*0.35 if allies_are_wisps else 0.0))
        # Resting positions sit comfortably beyond the owner's exclusion edge.
        var goal:Vector2=player+Vector2(formation.x*72,formation.y*96)
        if not target.is_empty():
            claimed_targets[target.id]=true;ally["target_id"]=target.id
            goal=target.position+formation*28
        else:ally.erase("target_id")
        var goal_offset:Vector2=goal-player
        var goal_ellipse:=Vector2(goal_offset.x/64.0,goal_offset.y/88.0)
        if goal_ellipse.length()<1.0:
            var goal_direction:Vector2=goal_ellipse.normalized() if goal_ellipse.length()>0.01 else formation
            goal=player+Vector2(goal_direction.x*64,goal_direction.y*88)
        var travel:Vector2=(goal-ally.position).limit_length(170*delta)
        var relative:Vector2=ally.position-player
        var next_relative:Vector2=relative+travel
        if Vector2(next_relative.x/48.0,next_relative.y/72.0).length()<1.0:
            # Follow the edge of the owner's space instead of cutting through it.
            var normal:=Vector2(relative.x/(48.0*48.0),relative.y/(72.0*72.0)).normalized()
            if normal.length()<0.01:normal=formation
            var tangent:=Vector2(-normal.y,normal.x)
            if tangent.dot(goal-ally.position)<0:tangent=-tangent
            var inward:float=travel.dot(normal)
            if inward<0:travel-=normal*inward
            # Use a tangent only to route to a goal on the far side of the owner.
            if normal.dot(goal-player)<0:travel=tangent*170*delta
        ally.position=navigation.move(ally.position,travel) if navigation!=null else ally.position+travel
        var nearest:float=ally.position.distance_to(target.position) if not target.is_empty() else INF
        if not target.is_empty() and nearest<45 and ally.cooldown<=0 and (navigation==null or navigation.clear_attack(ally.position,target.position)):
            ally["attack_age"]=0.0;ally["look_direction"]=target.position-ally.position
            damage_enemy(target,float(stats.ally_damage)+level*2,ally.position,false);ally.cooldown=float(stats.ally_cooldown)
    for first in range(allies.size()):
        for second in range(first+1,allies.size()):
            var offset:Vector2=allies[second].position-allies[first].position
            if offset.length()>=24:continue
            var direction:Vector2=offset.normalized() if offset.length()>0.01 else Vector2.RIGHT
            var push:Vector2=direction*(24-offset.length())*0.5
            allies[first].position=navigation.move(allies[first].position,-push) if navigation!=null else allies[first].position-push
            allies[second].position=navigation.move(allies[second].position,push) if navigation!=null else allies[second].position+push
    for i in range(allies.size()-1,-1,-1):
        if allies[i].age>=60 or allies[i].health<=0:allies.remove_at(i)
    constrain_allies()
    for ally in allies:
        var ally_displacement:Vector2=ally.position-ally.get("previous_position",ally.position)
        ally["moving"]=ally_displacement.length()>maxf(0.01,delta*2.0)
        if ally.moving and float(ally.get("attack_age",10.0))>0.3:ally["look_direction"]=ally_displacement
    if not portal.is_empty():
        portal.remaining-=delta
        if portal.remaining<=0:portal.clear()
    if config.get("mode","")!="cow":
        rare_clock-=delta
        if rare_clock<=0:
            rare_clock=float(config.get("rare_events",{}).get("check_seconds",30))
            if rng.randf()<float(config.get("rare_events",{}).get("spawn_chance",0.08)):spawn_rare()
    if elapsed>=float(config.duration_seconds):state="cow_complete" if config.get("mode","")=="cow" else "victory";return
    check_level_up()

func spawn_goblin(position: Vector2) -> bool:
    if config.get("mode","")=="cow" or goblin_appeared:return false
    for enemy in enemies:
        if enemy.health>0 and enemy.get("kind","")=="goblin":return false
    var before:=enemies.size()
    spawn_at(position,60)
    if before==enemies.size():return false
    goblin_appeared=true
    var goblin:Dictionary=enemies.back()
    goblin["kind"]="goblin";goblin.speed=135.0;goblin.damage=0;goblin.reward=5;goblin["lifetime"]=45.0
    events.append({"kind":"goblin_spawn","position":position})
    return true

func spawn_rare() -> void:
    for attempt in range(128):
        var position:Vector2
        if navigation!=null:position=navigation.world(navigation.available[rng.randi_range(0,navigation.available.size()-1)])
        else:position=player+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(300,550)
        if position.distance_to(player)>=280 and position.distance_to(player)<=600:
            if spawn_goblin(position):return

func update_goblin(enemy: Dictionary,delta: float) -> void:
    enemy.age+=delta;enemy.hit=maxf(0,enemy.hit-delta);enemy.lifetime-=delta
    if enemy.lifetime<=0:enemy.health=0;return
    var direction:Vector2=(enemy.position-player).normalized().rotated(sin(enemy.age*2)*0.65)
    if navigation!=null:
        var index:int=navigation.index_at(enemy.position)
        if index>=0:
            var goal:int=int(enemy.get("flee_cell",index))
            if not enemy.has("flee_cell") or navigation.world(goal).distance_to(enemy.position)<4:
                goal=index
                for next in navigation.neighbors(index):
                    if navigation.distances[next]>navigation.distances[goal]:goal=next
                enemy["flee_cell"]=goal
            direction=(navigation.world(goal)-enemy.position).normalized()
    if fmod(enemy.age,1.8)>1.3:direction=Vector2.ZERO
    var offset:Vector2=direction*float(enemy.speed)*delta
    enemy.position=navigation.move(enemy.position,offset) if navigation!=null else enemy.position+offset
    if direction!=Vector2.ZERO:enemy.facing=direction_index(direction)

func challenge_results() -> Array:
    var results:Array=[]
    var unlocked:=true
    for definition in config.get("challenges",[]):
        var count:int=int(kill_counts.get(definition.enemy,0))
        var claimed:bool=definition.id in config.get("completed_challenges",[])
        var current_complete:bool=count>=int(definition.target)
        var complete:bool=claimed or (unlocked and current_complete)
        var earned:int=1 if complete and not claimed and state in ["victory","cow_complete"] and elapsed>=float(config.duration_seconds) else 0
        results.append({"id":definition.id,"title":definition.title,"count":count,"target":definition.target,"unlocked":unlocked,"claimed":claimed,"current_complete":unlocked and current_complete,"complete":complete,"gold":earned})
        unlocked=complete
    return results

func summary() -> Dictionary:
    return {"difficulty":config.get("difficulty","easy"),"challenges":challenge_results(),"area_id":config.get("area_id","cathedral"),"area":config.get("area_name","Survival"),"kill_counts":kill_counts.duplicate(),"pickup_counts":pickup_counts.duplicate(),"collected_xp":collected_xp,"healing_received":snappedf(healing_received,0.01),"upgrade_ranks":upgrade_ranks.duplicate(),"upgrades":run_upgrades.duplicate(),"mode":config.get("mode","survival"),"loot_gold":loot_gold,"class_id":config.get("class_id","warrior"),"outcome":state,"seconds":snappedf(elapsed,0.01),"kills":kills,"level":level,"damage":snappedf(total_damage,0.01),"seed":config.seed,"wave":wave}

func crowd_heading(enemy:Dictionary,travel:Vector2,bins:Dictionary) -> Vector2:
    if travel.is_zero_approx():return Vector2.ZERO
    var forward:=travel.normalized()
    var lateral:=Vector2(-forward.y,forward.x)
    var push:=0.0
    if float(enemy.get("crowd_refresh",-1))>elapsed:
        var cached:Vector2=(forward+lateral*float(enemy.get("crowd_push",0))).normalized()
        if navigation!=null and not navigation.can_stand(enemy.position+cached*6):return forward
        return cached
    enemy["crowd_refresh"]=elapsed+0.15
    var inspected:=0
    var bin:=Vector2i(floori(enemy.position.x/64.0),floori(enemy.position.y/64.0))
    for y in range(-1,2):
        for x in range(-1,2):
            for other in bins.get(bin+Vector2i(x,y),[]):
                if other.id==enemy.id:continue
                var away:Vector2=enemy.position-other.position
                var distance:=away.length()
                var spacing:=float(enemy.radius)+float(other.radius)+8.0
                if distance>=spacing:continue
                inspected+=1
                var side:=away.dot(lateral)
                if absf(side)<0.01:side=1.0 if int(enemy.id)>int(other.id) else -1.0
                push+=signf(side)*(1.0-distance/spacing)
                if inspected>=16:break
            if inspected>=16:break
        if inspected>=16:break
    # Sideways separation keeps forward progress; the player is never an obstacle.
    enemy["crowd_push"]=clampf(push,-0.65,0.65)
    var heading:Vector2=(forward+lateral*float(enemy.crowd_push)).normalized()
    if navigation!=null and not navigation.can_stand(enemy.position+heading*6):return forward
    return heading
