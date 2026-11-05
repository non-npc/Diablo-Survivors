extends Node2D
var streams:Dictionary={}
var voices:Array=[]
var last_played:Dictionary={}
var listener:AudioListener2D
var muted:=false
var loaded_count:=0
var volume:=1.0
var hit_queue:Array=[]
var hit_followup:Dictionary={}
var hit_sequence_active:=false
var delayed_deaths:Array=[]
var effects_paused:=false
var visible_position:Callable
func set_volume(value:float) -> void:
    var old_db:float=linear_to_db(maxf(0.0001,volume))
    volume=clampf(value,0,1)
    for voice in voices:voice.volume_db+=linear_to_db(maxf(0.0001,volume))-old_db
func _ready() -> void:
    streams["run.complete"]=[completion_chime()]
    streams["loot.treasure"]=[completion_chime()]
    listener=AudioListener2D.new();add_child(listener);listener.make_current()
    for i in range(9):
        var voice:=AudioStreamPlayer2D.new()
        voice.max_distance=650;voice.attenuation=1.5
        voice.panning_strength=0.5;add_child(voice);voices.append(voice)
    voices[8].finished.connect(hit_clip_finished)
    # Successful player hits remain audible at ranged attack distances.
    voices[8].attenuation=0.0
func completion_chime() -> AudioStreamWAV:
    var rate:=22050;var frames:=int(rate*0.65);var data:=PackedByteArray();data.resize(frames*2)
    for frame in range(frames):
        var time:float=float(frame)/rate
        var start:float=0.0 if time<0.18 else 0.18 if time<0.36 else 0.36
        var length:float=0.18 if time<0.36 else 0.29
        var frequency:float=660 if time<0.18 else 880 if time<0.36 else 1320
        var age:float=time-start
        var envelope:float=minf(1,age/0.012)*pow(maxf(0,1-age/length),1.5)
        var sample:int=int((sin(age*TAU*frequency)+0.2*sin(age*TAU*frequency*2))*envelope*7000)
        data[frame*2]=sample&255;data[frame*2+1]=(sample>>8)&255
    var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data
    return stream
func configure(document:Dictionary) -> void:
    var cache:Dictionary={}
    for key in document.get("sounds",{}):
        var variants:Array=[]
        for entry in document.sounds[key]:
            var path:String=entry.path
            if not cache.has(path):
                var stream:=AudioStreamWAV.load_from_file(path)
                if stream==null:continue
                cache[path]=stream;loaded_count+=1
            variants.append(cache[path])
        if not variants.is_empty():streams[key]=variants
    var goblin_sounds:Array=[]
    for index in range(1,11):
        var path:String=extra_audio_path("goblin/PET_TreasureGoblinPet_Clickable_%02d.ogg" % index)
        if not FileAccess.file_exists(path):continue
        var stream:=AudioStreamOggVorbis.load_from_file(path)
        if stream!=null:goblin_sounds.append(stream);loaded_count+=1
    if not goblin_sounds.is_empty():streams["goblin.hit"]=goblin_sounds
    var spawn_path:String=extra_audio_path("goblin/loot-goblin-1.ogg")
    if FileAccess.file_exists(spawn_path):
        var spawn_stream:=AudioStreamOggVorbis.load_from_file(spawn_path)
        if spawn_stream!=null:streams["goblin.spawn"]=[spawn_stream];loaded_count+=1
    var hit_sounds:Array=[]
    for index in range(1,23):
        var path:String=extra_audio_path("hit/hit_%d.ogg" % index)
        if not FileAccess.file_exists(path):continue
        var stream:=AudioStreamOggVorbis.load_from_file(path)
        if stream!=null:hit_sounds.append(stream);loaded_count+=1
    if not hit_sounds.is_empty():streams["combat.impact"]=hit_sounds
func extra_audio_path(relative:String) -> String:
    if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://../extras/"+relative)
    return OS.get_executable_path().get_base_dir().get_base_dir().path_join("extras/"+relative)
func follow(position:Vector2) -> void:
    listener.position=position
func stop_all() -> void:
    hit_queue.clear();hit_followup.clear();delayed_deaths.clear();hit_sequence_active=false
    for voice in voices:voice.stop()
func set_muted(value:bool) -> void:
    muted=value
    if muted:stop_all()
func pause_effects(value:bool) -> void:
    effects_paused=value
    for voice in voices:voice.stream_paused=value

func _process(delta:float) -> void:
    if visible_position.is_valid():
        for voice in voices:
            if voice.playing and voice.get_meta("visible_only",false) and not visible_position.call(voice.position):
                voice.stop()
                if voice==voices[8]:hit_sequence_active=false;hit_followup.clear();start_next_hit()
    if effects_paused:return
    for index in range(delayed_deaths.size()-1,-1,-1):
        delayed_deaths[index].remaining-=delta
        if delayed_deaths[index].remaining>0:continue
        var sound:Dictionary=delayed_deaths[index];delayed_deaths.remove_at(index)
        play_effect(sound.key,sound.position,listener.position)

func play_hit_sequence(death_key:String,position:Vector2,player:Vector2) -> bool:
    if visible_position.is_valid() and not visible_position.call(position):return false
    if muted or volume<=0 or position.distance_squared_to(player)>650*650:return false
    if not streams.has("combat.impact"):
        return play_effect(death_key,position,player) if not death_key.is_empty() else false
    # Keep the crowd audio backlog bounded; accepted pairs always finish in order.
    if hit_queue.size()>=8:return false
    hit_queue.append({"death_key":death_key,"position":position})
    if not hit_sequence_active:start_next_hit()
    return true

func start_next_hit() -> void:
    while not hit_queue.is_empty() and visible_position.is_valid() and not visible_position.call(hit_queue[0].position):hit_queue.pop_front()
    if hit_queue.is_empty():hit_sequence_active=false;return
    hit_sequence_active=true
    hit_followup=hit_queue.pop_front()
    play_sequence_clip("combat.impact",hit_followup.position,0)
    var death_key:String=hit_followup.get("death_key","")
    if not death_key.is_empty() and streams.has(death_key):
        delayed_deaths.append({"key":death_key,"position":hit_followup.position,"remaining":0.1})

func play_sequence_clip(key:String,position:Vector2,db:float) -> void:
    var voice:AudioStreamPlayer2D=voices[8]
    voice.stream=streams[key][randi()%streams[key].size()]
    voice.position=position;voice.pitch_scale=randf_range(0.97,1.03)
    voice.set_meta("visible_only",true)
    voice.volume_db=db+linear_to_db(maxf(0.0001,volume));voice.play()

func hit_clip_finished() -> void:
    hit_followup.clear();start_next_hit()

func play_effect(key:String,position:Vector2,player:Vector2,priority:bool=false) -> bool:
    var visible_only:bool=key not in ["goblin.spawn","run.complete"]
    if visible_only and visible_position.is_valid() and not visible_position.call(position):return false
    if key=="combat.impact":return play_hit_sequence("",position,player)
    if muted or volume<=0 or not streams.has(key) or (not priority and position.distance_squared_to(player)>650*650):return false
    var now:=Time.get_ticks_msec()
    var xp_pickup:=key=="loot.xp"
    var player_impact:=key=="combat.impact"
    if now-int(last_played.get(key,-1000))<(160 if xp_pickup else 40 if priority else 120):return false
    # Reserve impact voices so crowd attacks cannot swallow hit/death feedback.
    var impact:=not priority and (key.ends_with(".hit") or key.ends_with(".death"))
    var first:=8 if player_impact else 7 if xp_pickup else 0 if priority else (2 if impact else 4)
    var last:=9 if player_impact else 8 if xp_pickup else 2 if priority else (4 if impact else 7)
    var selected:AudioStreamPlayer2D
    for i in range(first,last):
        if not voices[i].playing:selected=voices[i];break
    if selected==null:
        if not priority and not impact and not player_impact:return false
        selected=voices[first];selected.stop()
    last_played[key]=now
    selected.stream=streams[key][randi()%streams[key].size()]
    selected.position=position;selected.volume_db=(-13 if key.ends_with(".attack") else -9) if priority else (-7 if impact else -23 if xp_pickup else -18)
    selected.set_meta("visible_only",visible_only)
    if key=="run.complete":selected.volume_db=-2
    if player_impact:selected.volume_db=-10
    selected.volume_db+=linear_to_db(maxf(0.0001,volume))
    selected.pitch_scale=randf_range(0.97,1.03);selected.stream_paused=false;selected.play()
    return true
