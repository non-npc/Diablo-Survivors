extends SceneTree
const Bank=preload("res://scripts/combat_audio.gd")
var failed:=false
func require(condition:bool,message:String) -> void:
    if not condition:push_error(message);failed=true
func _initialize() -> void:call_deferred("check_audio")
func check_audio() -> void:
    var bank=Bank.new();root.add_child(bank)
    var args:=OS.get_cmdline_user_args()
    var path:String=args[args.find("--test-wave")+1]
    var mappings:Dictionary={"sounds":{}}
    for i in range(12):mappings.sounds["enemy"+str(i)]=[{"path":path}]
    mappings.sounds["player.attack"]=[{"path":path}]
    mappings.sounds["player.hit"]=[{"path":path}]
    mappings.sounds["skeleton.hit"]=[{"path":path}]
    mappings.sounds["skeleton.death"]=[{"path":path}]
    mappings.sounds["loot.xp"]=[{"path":path}]
    bank.configure(mappings)
    require(bank.loaded_count==34 and bank.streams.size()==22,"WAV must load once alongside goblin and player impact OGG files")
    require(bank.streams.get("combat.impact",[]).size()==22,"All twenty-two randomized impact sounds must decode")
    require(bank.streams.get("goblin.spawn",[]).size()==1,"Goblin spawn announcement must decode successfully")
    require(bank.streams.get("goblin.hit",[]).size()==10,"Every goblin hit variant must decode successfully")
    require(bank.streams.has("run.complete"),"Completion chime must be preloaded")
    require(bank.voices.size()==9,"Sound pool must reserve a separate voice for the extra player hit layer")
    bank.follow(Vector2(500,500))
    require(not bank.play_effect("enemy0",Vector2(2000,2000),Vector2.ZERO),"Distant combat must be culled")
    var accepted:=0
    for i in range(12):
        if bank.play_effect("enemy"+str(i),Vector2.ZERO,Vector2.ZERO):accepted+=1
    require(accepted<=4,"Crowd sounds must not consume player-reserved voices")
    require(bank.play_effect("player.attack",Vector2.ZERO,Vector2.ZERO,true),"Player attacks must retain a voice in crowds")
    require(not bank.play_effect("player.attack",Vector2.ZERO,Vector2.ZERO,true),"Repeated events must be throttled")
    require(bank.play_effect("skeleton.hit",Vector2.ZERO,Vector2.ZERO),"Crowd attacks must leave a reserved enemy hit voice")
    require(bank.play_effect("combat.impact",Vector2.ZERO,Vector2.ZERO),"Additional impact must play alongside enemy hit feedback")
    require(bank.voices[2].playing and bank.voices[8].playing,"Player impact must not replace the enemy sound")
    require(bank.play_effect("skeleton.death",Vector2.ZERO,Vector2.ZERO),"Killing blows must retain death feedback alongside hits and player attacks")
    require(bank.voices[2].volume_db>bank.voices[0].volume_db,"Enemy impacts must be audible over the attack swish")
    bank.last_played.erase("skeleton.death")
    require(bank.play_effect("skeleton.death",Vector2.ZERO,Vector2.ZERO),"Impact saturation must not drop the next killing blow")
    require(bank.play_effect("loot.xp",Vector2.ZERO,Vector2.ZERO),"XP pickups must keep a quiet reserved voice in crowds")
    require(not bank.play_effect("loot.xp",Vector2.ZERO,Vector2.ZERO),"Rapid XP pickups must coalesce into a modest sound cadence")
    require(bank.voices[7].volume_db<bank.voices[0].volume_db,"XP sounds must stay quieter than combat feedback")
    bank.stop_all()
    require(bank.play_hit_sequence("skeleton.death",Vector2.ZERO,Vector2.ZERO),"Killing blow must start a hit/death sequence")
    require(bank.voices[8].stream in bank.streams["combat.impact"],"Sequence must begin with a randomized hit sound")
    require(is_zero_approx(bank.voices[8].volume_db) and is_zero_approx(bank.voices[8].attenuation),"Player impact at full SFX volume must retain clip level without distance attenuation")
    bank.set_volume(0.5)
    require(is_equal_approx(bank.voices[8].volume_db,linear_to_db(0.5)),"Hit volume must still follow the user's SFX slider")
    bank.set_volume(1.0)
    require(not bank.voices[2].playing and not bank.voices[3].playing,"Death sound must not start alongside the impact")
    bank.last_played.erase("skeleton.death");bank.follow(Vector2.ZERO)
    bank._process(0.05)
    require(not bank.voices[2].playing,"Death sound must wait for the short stagger")
    bank.pause_effects(true);bank._process(1.0)
    require(bank.delayed_deaths.size()==1,"Pausing must freeze the death sound stagger")
    bank.pause_effects(false);bank._process(0.06)
    require(bank.voices[2].playing and bank.voices[8].playing,"Death sound must overlap the impact after the stagger")
    require(bank.delayed_deaths.is_empty(),"Staggered death sound must play exactly once")
    bank.voices[8].stop();bank.hit_clip_finished()
    require(not bank.hit_sequence_active,"Finished sequence must release its voice")
    bank.set_muted(true)
    require(not bank.play_effect("player.hit",Vector2.ZERO,Vector2.ZERO,true),"Mute must suppress playback")
    if args.has("--audio-manifest"):
        var local:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--audio-manifest")+1]))
        var real_bank=Bank.new();root.add_child(real_bank);real_bank.set_muted(true);real_bank.configure(local)
        require(local.missing.is_empty() and real_bank.streams.size()>=21,"Installed-game combat mappings must load completely")
        real_bank.queue_free()
    bank.queue_free()
    if not failed:print("GAMESHIFT_AUDIO_RULES_OK")
    quit(1 if failed else 0)
