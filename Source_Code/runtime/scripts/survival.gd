extends Node2D
const Ailments=preload("res://scripts/ailments.gd")
var ailment_hud:RichTextLabel
var spell_light_layer:Node2D
var particle_fx:Node2D
var base_model: RefCounted
var direct_cow := false
var treasure_demo := false
var goblin_texture: Texture2D
var event_notice := ""
var notice_clock := 0.0
const CombatAudio=preload("res://scripts/combat_audio.gd")
var audio_bank:Node2D
const TownNavigation = preload("res://scripts/town_navigation.gd")
var town: Dictionary={}
var character_texture: ImageTexture
var sheet_return := "playing"
var town_floor_texture: ImageTexture
var town_cache: Array=[]
var town_cache_bucket:=Vector2i(999999,999999)
var town_texture: ImageTexture
const Classes = preload("res://scripts/class_progress.gd")
var progress: Dictionary={}
var selected_difficulty:="easy"
const GAME_SPEEDS=[1.0,1.5,2.0,3.0,5.0,10.0]
var game_speed:=1.0
var speed_panel:PanelContainer
var speed_value:Label
var speed_minus:Button
var speed_plus:Button
var speed_reset:Button
const Difficulties=preload("res://scripts/difficulties.gd")
var selected_class := "warrior"
const Model = preload("res://scripts/survival_model.gd")
var selected_arena := "cathedral"
var arena_cache:Dictionary={}
var map_atlas_cache:Dictionary={}
var last_reward:=0
var reward_thread:Thread
var reward_save_pending:=false
var reward_save_attempted:=false
var reward_calculation_scheduled:=false
var achievement_tab:=0
var upgrade_icon_cache:Dictionary={}
var pickup_icons:Dictionary={}
var local_texture_cache:Dictionary={}
func load_local_texture(path:String) -> Texture2D:
	if local_texture_cache.has(path):return local_texture_cache[path]
	if not OS.has_feature("editor") and path.begins_with("res://"):
		var imported:Texture2D=load(path)
		local_texture_cache[path]=imported
		return imported
	var image:=Image.new()
	var result:=image.load_svg_from_string(FileAccess.get_file_as_string(path)) if path.ends_with(".svg") else image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) if path.ends_with(".png") else image.load(path)
	if result!=OK:push_error("Could not load texture: "+path);return null
	var texture:=ImageTexture.create_from_image(image)
	local_texture_cache[path]=texture
	return texture
var spell_icon_texture:Texture2D
var manifest: Dictionary
var model: RefCounted
var visuals := {}
var surface_texture: ImageTexture
var area_scenery:Array=[]
var scenery_texture_cache:Dictionary={}
var floor_texture: ImageTexture
var terrain := {}
var camera := Vector2.ZERO
var facing := 0
var player_age := 0.0
var player_state := "idle"
var attack_animation := 0.0
var attack_animation_span:=0.56
var attack_ready_flash:=0.0
var auto_attack_enabled:=true
var attack_target_id:=-1
var player_walk_reverse:=false
var spell_visuals:Dictionary={}
var impact_visuals:Dictionary={}
var impact_particles:Array=[]
var damage_labels: Array = []
var swings: Array = []
var class_icons: Dictionary={}
const CHARACTER_PREVIEW_ORDER=[5,6,3,4,7,2,1,0] # NE, E, NW, N, SE, W, SW, S
var character_preview_direction:=7
var character_preview:TextureRect
var character_sprite_views:Dictionary={}
var challenge_label: Label
var cow_timer: Label
var hud: Label
var powerup_bars:Dictionary={}
var hp_fill:StyleBoxFlat
var hp_flash:=0.0
var hit_overlay:ColorRect
var preferences:Dictionary={"music_enabled":true,"music_volume":0.5,"sfx_volume":1.0,"screen_shake":true}
var music_player:AudioStreamPlayer
var music_path:=""
var settings_return:="classes"
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var overlay: PanelContainer
var overlay_body: VBoxContainer
var ui_state := ""
var saved := false
var smoke := false
var shop_category := "General"
var shop_message := ""
var ticks := 0
var game_font: Font

func fail(message: String) -> void:
	set_physics_process(false)
	push_error(message)
	get_tree().quit(1)

func load_visual(document: Dictionary,requires_walk:bool=true) -> Dictionary:
	var result := {}
	for state in document.get("clips", {}):
		var info: Dictionary = document.clips[state]
		var source: String = info.get("sheet", "")
		var image: Image
		if source.begins_with("res://"):
			var texture := load_local_texture(source)
			if texture != null: image = texture.get_image()
		else:
			image = Image.load_from_file(source)
		var counts: Array = info.get("frames_per_direction", [])
		if image == null or image.is_empty() or counts.size() not in [1, 8] or info.get("frame_width",0)<=0 or info.get("frame_height",0)<=0 or info.get("frame_seconds",0)<=0:
			fail("Invalid actor clip: " + state)
			return {}
		for count in counts:
			var columns:int=int(info.get("frame_columns",count))
			var rows_per_direction:int=ceili(float(count)/maxi(1,columns))
			if count<=0 or columns<=0 or columns*info.frame_width>image.get_width() or counts.size()*rows_per_direction*info.frame_height>image.get_height():
				fail("Actor animation exceeds texture bounds")
				return {}
		var centers:Array=[]
		if state=="attack":
			var anchor:Array=info.get("anchor",[info.frame_width/2.0,info.frame_height])
			for row in range(counts.size()):
				var rows_per_direction:int=ceili(float(counts[row])/int(info.get("frame_columns",counts[row])))
				var frame_image:=image.get_region(Rect2i(0,row*rows_per_direction*int(info.frame_height),int(info.frame_width),int(info.frame_height)))
				var bounds:=frame_image.get_used_rect()
				centers.append(Vector2(bounds.position)+Vector2(bounds.size)*0.5-Vector2(anchor[0],anchor[1]))
		result[state] = {"texture":ImageTexture.create_from_image(image), "info":info,"centers":centers}
	if not result.has("idle") or (requires_walk and not result.has("walk")):
		fail("Actor requires idle and walk clips")
		return {}
	return result

func _ready() -> void:
	spell_light_layer=Node2D.new()
	var light_material:=CanvasItemMaterial.new()
	light_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	spell_light_layer.material=light_material
	spell_light_layer.draw.connect(draw_spell_lights)
	add_child(spell_light_layer)
	for kind in ["haste","healing","magnet","vacuum"]:
		pickup_icons[kind]=load_local_texture("res://resources/powerups/"+kind+".svg")
	DisplayServer.window_set_title("Diablo Survivors v"+str(ProjectSettings.get_setting("application/config/display_version","0.24 beta")))
	clean_window_title.call_deferred()
	var args := OS.get_cmdline_user_args()
	smoke = args.has("--smoke-test")
	direct_cow=args.has("--cow-event")
	treasure_demo=args.has("--treasure-demo")
	var path := "res://resources/survival_demo.json"
	var index := args.find("--survival-manifest")
	if index>=0 and index+1<args.size():path=args[index+1]
	elif not OS.has_feature("editor"):
		path=preload("res://scripts/cached_manifest.gd").find(OS.get_executable_path().get_base_dir().get_base_dir())
		if path.is_empty():
			OS.alert("No imported asset cache was selected. Start Diablo Survivors.exe in the main application folder and import your game first.","Diablo Survivors — Game assets required")
			fail("No cached asset manifest; start the main launcher.");return
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:fail("Cannot open survival manifest: "+path);return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("schema_version")!=1:
		fail("Invalid survival manifest");return
	manifest=data
	print("ASSET_MANIFEST_LOADED: ",path," [",manifest.get("game_id","unknown"),"]")
	if args.has("--test-progress"):manifest.save_path=args[args.find("--test-progress")+1]
	var config: Dictionary=manifest.get("configuration",{})
	config.upgrades=JSON.parse_string(FileAccess.get_file_as_string("res://resources/upgrades.json"))
	if not config.has_all(["player","enemy","director","upgrades","duration_seconds","seed"]):
		fail("Survival configuration is incomplete");return
	if config.duration_seconds<=0 or config.duration_seconds>3600 or config.upgrades.size()<3 or config.director.get("max_enemies",0)<=0 or config.director.max_enemies>1000 or config.director.get("wave_seconds",0)<=0 or config.director.get("spawn_interval",0)<=0:
		fail("Survival configuration values are invalid");return
	for stat in ["health","speed","damage","cooldown","attack_range","attack_targets","pickup_radius"]:
		if config.player.get(stat,0)<=0:fail("Invalid player stat: "+stat);return
	visuals.player=load_visual(manifest.get("player_visual",{}))
	visuals.enemy=load_visual(manifest.get("enemy_visual",{}))
	if manifest.has("cow_visual"):visuals.cow=load_visual(manifest.cow_visual)
	goblin_texture=load_local_texture("res://resources/treasure_goblin.png")
	if visuals.player.is_empty() or visuals.enemy.is_empty():return
	if not manifest.has("arenas"):
		manifest["arenas"]={"cathedral":{"title":manifest.get("title","Survival"),"terrain":manifest.get("terrain",{}),"map":manifest.get("map",{}),"arena_width":config.get("arena_width",2200),"arena_height":config.get("arena_height",1800),"challenges":config.get("challenges",[])}}
	selected_arena=manifest.get("default_arena","cathedral")
	if direct_cow:
		manifest.arenas={"cow":{"title":"Cow Hunt (playtest)","arena_width":2200,"arena_height":1800}}
		selected_arena="cow"
	if not apply_arena(selected_arena):return
	var ui:Dictionary=manifest.get("ui",{})
	if ui.has("character_panel"):
		var image:=Image.load_from_file(ui.character_panel.texture)
		if image==null or image.get_width()!=320 or image.get_height()!=352:fail("Invalid character panel");return
		character_texture=ImageTexture.create_from_image(image)
	if ui.has("spell_icons"):
		var image:=Image.load_from_file(ui.spell_icons.texture)
		if image!=null:spell_icon_texture=ImageTexture.create_from_image(image)
	for kind in manifest.get("spell_effects",{}):spell_visuals[kind]=load_visual(manifest.spell_effects[kind],false)
	for kind in manifest.get("impact_effects",{}):impact_visuals[kind]=load_visual(manifest.impact_effects[kind])
	game_font=ThemeDB.fallback_font
	build_ui()
	audio_bank=CombatAudio.new();add_child(audio_bank)
	audio_bank.configure(manifest.get("audio",{}));audio_bank.set_muted(smoke)
	audio_bank.visible_position=func(point:Vector2)->bool:return Rect2(Vector2.ZERO,Vector2(1280,720)).has_point(screen(point))
	music_player=AudioStreamPlayer.new();add_child(music_player)
	var settings_file:String=progress_path().get_base_dir()+"/settings.json"
	if FileAccess.file_exists(settings_file):
		var stored=JSON.parse_string(FileAccess.get_file_as_string(settings_file))
		if stored is Dictionary:preferences.merge(stored,true)
	apply_preferences()
	selected_class=manifest.get("default_class","warrior")
	read_progress()
	if not smoke:restore_last_played()
	if not level_unlocked(selected_arena):selected_arena=manifest.get("default_arena","cathedral");apply_arena(selected_arena)
	visuals.player=load_visual(manifest.get("class_visuals",{}).get(selected_class,manifest.player_visual))
	restart()
	if not smoke:show_classes()
	if smoke:
		for key in manifest.get("class_visuals",{}):
			if load_visual(manifest.class_visuals[key]).is_empty():return
		model.config.duration_seconds=3.0
		model.stats.health=10000.0;model.stats.max_health=10000.0;model.base_stats.max_health=10000.0;model.health=10000.0
		if model.navigation!=null:
			for cell_index in model.navigation.available:
				var position:Vector2=model.navigation.world(cell_index)
				if position.distance_to(model.player)>25 and position.distance_to(model.player)<80:
					model.spawn_at(position,1);break
		else:model.spawn_at(model.player+Vector2(45,0),1)

func level_unlocked(key:String) -> bool:
	return smoke or treasure_demo or direct_cow or Classes.area_unlocked(progress,key)

func apply_arena(key:String) -> bool:
	if not manifest.arenas.has(key):return false
	var spec:Dictionary=manifest.arenas[key]
	manifest.title=spec.title
	manifest.configuration.arena_width=spec.get("arena_width",2200)
	manifest.configuration.arena_height=spec.get("arena_height",1800)
	manifest.configuration.challenges=spec.get("challenges",[])
	if spec.has("enemy"):manifest.configuration.enemy=spec.enemy.duplicate(true)
	for field in ["enemy_roster","enemy_definitions","boss","unique_roster"]:
		manifest.configuration[field]=spec.get(field,"" if field=="boss" else {} if field=="enemy_definitions" else [] if field=="unique_roster" else ["skeleton"])
	# Only the selected zone's enemy sheets stay resident.
	for actor in visuals.keys():
		if actor not in ["player","enemy","cow"]:visuals.erase(actor)
	var actors:Array=spec.get("enemy_roster",[]).duplicate()
	if not str(spec.get("boss","")).is_empty():actors.append(spec.boss)
	for actor in actors:
		if manifest.get("enemy_visuals",{}).has(actor):visuals[actor]=load_visual(manifest.enemy_visuals[actor])
	town_cache_bucket=Vector2i(999999,999999);town_cache.clear()
	load_area_scenery(spec,key)
	if arena_cache.has(key):
		var cache:Dictionary=arena_cache[key]
		terrain=cache.terrain;town=cache.town;floor_texture=cache.floor;town_texture=cache.props;town_floor_texture=cache.ground;surface_texture=cache.get("surface",null)
		return true
	floor_texture=null;town_texture=null;town_floor_texture=null;surface_texture=null
	terrain=spec.get("terrain",{})
	if not terrain.is_empty():
		var image := Image.load_from_file(terrain.get("atlas",""))
		if image==null or image.is_empty() or terrain.get("columns",0)<=0 or terrain.get("cell_width",0)!=128 or terrain.get("cell_height",0)<64 or terrain.get("tile_index",-1)<0:
			fail("Invalid terrain texture");return false
		var tile_index:int=terrain.tile_index
		if (tile_index%int(terrain.columns)+1)*128>image.get_width() or (tile_index/int(terrain.columns)+1)*terrain.cell_height>image.get_height():
			fail("Terrain source rectangle exceeds image bounds");return false
		floor_texture=ImageTexture.create_from_image(image)
		if terrain.has("surface_texture"):
			var surface:=Image.load_from_file(terrain.surface_texture)
			if surface==null or surface.is_empty():fail("Missing cached ground surface");return false
			surface_texture=ImageTexture.create_from_image(surface)
	town=spec.get("map",{})
	if not town.is_empty():
		if not town.has_all(["atlas","grid_width","grid_height","pieces","walkable","missile_blocked","origin","spawn_cell","columns"]):fail("Incomplete town map");return false
		var cells:int=int(town.grid_width)*int(town.grid_height)
		if cells<=0 or cells>16384 or town.pieces.size()!=cells or town.walkable.size()!=cells or town.missile_blocked.size()!=cells or town.columns<=0:fail("Invalid town grid");return false
		var image:=Image.load_from_file(town.atlas)
		if image==null or image.is_empty():fail("Missing town atlas");return false
		for piece in town.pieces:
			if piece<0 or (int(piece)%int(town.columns)+1)*64>image.get_width() or (int(piece)/int(town.columns)+1)*256>image.get_height():fail("Town piece outside atlas");return false
		if not map_atlas_cache.has(town.atlas):map_atlas_cache[town.atlas]=ImageTexture.create_from_image(image)
		town_texture=map_atlas_cache[town.atlas]
		if town.has("floor_texture"):
			var floor_image:=Image.load_from_file(town.floor_texture)
			if floor_image==null or floor_image.is_empty():fail("Missing cached town floor");return false
			town_floor_texture=ImageTexture.create_from_image(floor_image)
	if arena_cache.size()>=3:arena_cache.erase(arena_cache.keys()[0])
	arena_cache[key]={"terrain":terrain,"town":town,"floor":floor_texture,"props":town_texture,"ground":town_floor_texture,"surface":surface_texture}
	return true

func load_area_scenery(spec:Dictionary,key:String) -> void:
	area_scenery.clear()
	var choices:Array=spec.get("scenery",[])
	if choices.is_empty():return
	var rng:=RandomNumberGenerator.new();rng.seed=hash(key)
	for y in range(140,int(spec.get("arena_height",2400)),320):
		for x in range(160,int(spec.get("arena_width",3200)),420):
			if rng.randf()>0.7:continue
			var prop:Dictionary=choices[rng.randi_range(0,choices.size()-1)]
			if not scenery_texture_cache.has(prop.texture):
				var image:=Image.load_from_file(prop.texture)
				if image==null or image.is_empty():continue
				scenery_texture_cache[prop.texture]=ImageTexture.create_from_image(image)
			area_scenery.append({"position":Vector2(x+rng.randf_range(-100,100),y+rng.randf_range(-70,70)),"data":prop})

func draw_area_prop(item:Dictionary) -> void:
	var prop:Dictionary=item.data
	var texture:Texture2D=scenery_texture_cache[prop.texture]
	var scale:float=float(prop.get("scale",0.7))
	var anchor:=Vector2(prop.anchor[0],prop.anchor[1])*scale
	var point:=screen(item.position)
	var alpha:float=0.45 if point.distance_to(screen(model.player))<65 else 1.0
	draw_texture_rect(texture,Rect2(point-anchor,texture.get_size()*scale),false,Color(1,1,1,alpha))

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.035,0.055,0.085,0.97)
	style.border_color=Color("546978")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left=26;style.content_margin_right=26;style.content_margin_top=20;style.content_margin_bottom=20
	return style

func build_ui() -> void:
	var canvas := CanvasLayer.new();add_child(canvas)
	ailment_hud=RichTextLabel.new();ailment_hud.position=Vector2(350,105);ailment_hud.size=Vector2(290,115);ailment_hud.bbcode_enabled=true;ailment_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(ailment_hud)
	hud=Label.new();hud.position=Vector2(28,18);hud.add_theme_font_size_override("font_size",20);canvas.add_child(hud)
	cow_timer=Label.new();cow_timer.position=Vector2(1050,20);cow_timer.size=Vector2(180,54);cow_timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cow_timer.pivot_offset=Vector2(90,27);cow_timer.add_theme_font_size_override("font_size",36);cow_timer.add_theme_constant_override("outline_size",4);canvas.add_child(cow_timer)
	build_speed_control(canvas)
	challenge_label=Label.new();challenge_label.position=Vector2(28,165);challenge_label.add_theme_font_size_override("font_size",16);challenge_label.add_theme_color_override("font_color",Color("e8d7a4"));canvas.add_child(challenge_label)
	hp_bar=ProgressBar.new();hp_bar.position=Vector2(28,107);hp_bar.size=Vector2(300,20);hp_bar.show_percentage=false;canvas.add_child(hp_bar)
	hp_fill=StyleBoxFlat.new();hp_fill.bg_color=Color("65d879")
	hp_bar.add_theme_stylebox_override("fill",hp_fill)
	xp_bar=ProgressBar.new();xp_bar.position=Vector2(28,137);xp_bar.size=Vector2(300,12);xp_bar.show_percentage=false;canvas.add_child(xp_bar)
	var xp_fill:=StyleBoxFlat.new();xp_fill.bg_color=Color("87d7ff");xp_fill.set_corner_radius_all(3)
	var xp_background:=StyleBoxFlat.new();xp_background.bg_color=Color("183344");xp_background.set_corner_radius_all(3)
	xp_bar.add_theme_stylebox_override("fill",xp_fill);xp_bar.add_theme_stylebox_override("background",xp_background)
	for kind in ["haste","magnet"]:
		var bar:=ProgressBar.new();bar.size=Vector2(300,22);bar.show_percentage=false;bar.max_value=Model.POWERUP_DURATION
		var fill:=StyleBoxFlat.new();fill.bg_color=Color("a46be8");fill.set_corner_radius_all(3);bar.add_theme_stylebox_override("fill",fill)
		var background:=StyleBoxFlat.new();background.bg_color=Color("21172f");background.set_corner_radius_all(3);bar.add_theme_stylebox_override("background",background)
		canvas.add_child(bar);powerup_bars[kind]=bar
		var label:=Label.new();bar.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",14);label.add_theme_constant_override("outline_size",2)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var help := Label.new();help.position=Vector2(28,679);help.text="WASD / arrows move   •   T auto-attack   •   Space / Esc pause   •   1–3 choose upgrade   •   R restart   •   C character   •   M sound";canvas.add_child(help)
	overlay=PanelContainer.new();overlay.position=Vector2(340,170);overlay.size=Vector2(600,360);overlay.add_theme_stylebox_override("panel",panel_style());canvas.add_child(overlay)
	overlay_body=VBoxContainer.new();overlay_body.add_theme_constant_override("separation",14);overlay.add_child(overlay_body)
	var hit_layer:=CanvasLayer.new();hit_layer.layer=10;add_child(hit_layer)
	hit_overlay=ColorRect.new();hit_layer.add_child(hit_overlay)
	hit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_overlay.color=Color(1,0.05,0.05,0);hit_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE

func build_speed_control(canvas:CanvasLayer) -> void:
	speed_panel=PanelContainer.new();speed_panel.position=Vector2(510,4);speed_panel.size=Vector2(260,74)
	var style:=panel_style();style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=6;style.content_margin_bottom=6
	speed_panel.add_theme_stylebox_override("panel",style);canvas.add_child(speed_panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",3);speed_panel.add_child(column)
	var title:=Label.new();title.text="GAME SPEED · MAX 10×";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",12);column.add_child(title)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);column.add_child(row)
	speed_minus=Button.new();speed_minus.text="−";speed_minus.custom_minimum_size=Vector2(36,32);row.add_child(speed_minus);speed_minus.pressed.connect(change_game_speed.bind(-1))
	speed_value=Label.new();speed_value.custom_minimum_size.x=62;speed_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;speed_value.add_theme_font_size_override("font_size",22);speed_value.add_theme_color_override("font_color",Color("ffdc89"));row.add_child(speed_value)
	speed_plus=Button.new();speed_plus.text="+";speed_plus.custom_minimum_size=Vector2(36,32);row.add_child(speed_plus);speed_plus.pressed.connect(change_game_speed.bind(1))
	speed_reset=Button.new();speed_reset.text="Reset";speed_reset.custom_minimum_size=Vector2(65,32);speed_reset.tooltip_text="Restore gameplay speed to 1×";row.add_child(speed_reset);speed_reset.pressed.connect(set_game_speed.bind(1.0))
	for button in [speed_minus,speed_plus,speed_reset]:button.focus_mode=Control.FOCUS_NONE
	speed_panel.tooltip_text="Changes combat and countdown speed together. Music stays at normal speed."
	set_game_speed(1.0)

func set_game_speed(value:float) -> void:
	game_speed=GAME_SPEEDS[0]
	for speed in GAME_SPEEDS:
		if absf(float(speed)-value)<absf(game_speed-value):game_speed=float(speed)
	if speed_value==null:return
	speed_value.text=("%d×" % int(game_speed)) if is_equal_approx(game_speed,roundf(game_speed)) else "%.1f×" % game_speed
	speed_minus.disabled=game_speed<=1.0;speed_plus.disabled=game_speed>=10.0;speed_reset.disabled=is_equal_approx(game_speed,1.0)

func change_game_speed(direction:int) -> void:
	var index:int=GAME_SPEEDS.find(game_speed)
	set_game_speed(float(GAME_SPEEDS[clampi(index+direction,0,GAME_SPEEDS.size()-1)]))

func restart() -> void:
	set_game_speed(1.0)
	if selected_class=="necromancer" and manifest.has("minion_visual"):visuals["skeleton"]=load_visual(manifest.minion_visual)
	attack_target_id=-1;player_walk_reverse=false
	reward_save_attempted=false
	hp_flash=0.0
	position=Vector2.ZERO
	if hit_overlay!=null:hit_overlay.color.a=0
	if audio_bank!=null:audio_bank.stop_all()
	var configuration:Dictionary=Difficulties.configure(Classes.configure(manifest.configuration,selected_class,progress),selected_difficulty)
	configuration["area_id"]=selected_arena
	configuration["completed_challenges"]=progress.get("completed_challenges",{}).get(Difficulties.slot(selected_arena,selected_difficulty),{}).keys()
	configuration["area_name"]=manifest.get("title","Survival")
	configuration["projectile_visual_offsets"]=visuals.player.get("attack",{}).get("centers",[])
	if not smoke:configuration.seed=int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system())
	configuration.death_durations=enemy_death_durations()
	model=Model.new(configuration)
	play_area_music()
	base_model=null
	if not town.is_empty():
		model.navigation=TownNavigation.new(town)
		model.player=model.navigation.world(int(town.spawn_cell[1])*int(town.grid_width)+int(town.spawn_cell[0]))
		model.navigation.update_flow(model.player)
	camera=model.player;facing=0;player_age=0;player_state="idle";attack_animation=0;attack_target_id=-1;player_walk_reverse=false
	impact_particles.clear();damage_labels.clear();swings.clear();saved=false;reward_save_attempted=false;last_reward=0;ui_state=""
	if treasure_demo:
		model.config["rare_events"]={"portal_chance":1.0,"spawn_chance":0.0}
		if model.navigation!=null:
			for cell_index in model.navigation.available:
				var position:Vector2=model.navigation.world(cell_index)
				if position.distance_to(model.player)>=200 and position.distance_to(model.player)<=300:
					if model.spawn_goblin(position):break
		else:model.spawn_goblin(model.player+Vector2(240,0))
		event_notice="Treasure playtest: this goblin is guaranteed to drop a portal.";notice_clock=8
	if direct_cow:enter_cow_event(true)
	update_ui()

func cow_event() -> bool:
	return model!=null and model.config.get("mode","")=="cow"

func enter_cow_event(force: bool=false) -> void:
	if cow_event() or (not force and (model.state!="playing" or model.portal.is_empty() or model.player.distance_to(model.portal.position)>85)):return
	if audio_bank!=null:audio_bank.stop_all()
	model.portal.clear()
	base_model=model
	var configuration:Dictionary=model.config.duplicate(true)
	configuration["mode"]="cow";configuration["area_id"]="cow";configuration["completed_challenges"]=progress.get("completed_challenges",{}).get("cow",{}).keys();configuration["area_name"]="Cow Hunt";configuration.duration_seconds=480
	configuration["challenges"]=[]
	configuration["projectile_visual_offsets"]=visuals.player.get("attack",{}).get("centers",[])
	for target in [100,250,750]:configuration.challenges.append({"id":"cow-"+str(target),"title":"Defeat %d cows" % target,"enemy":"cow","target":target})
	configuration.arena_width=2200;configuration.arena_height=1800
	configuration.director={"wave_seconds":30,"spawn_interval":0.4,"max_enemies":220}
	configuration.death_durations=enemy_death_durations()
	var event=Model.new(configuration)
	event.stats=model.stats.duplicate(true);event.health=model.health
	event.haste_clock=model.haste_clock;event.magnet_clock=model.magnet_clock
	event.level=model.level;event.xp=model.xp;event.xp_needed=model.xp_needed
	event.run_upgrades=model.run_upgrades.duplicate(true)
	event.rerolls_used=model.rerolls_used
	event.upgrade_ranks=model.upgrade_ranks.duplicate(true);event.base_stats=model.base_stats.duplicate(true);event.xp_fraction=model.xp_fraction
	model=event;camera=model.player;player_age=0;player_state="idle";attack_animation=0;attack_target_id=-1;player_walk_reverse=false
	play_area_music()
	impact_particles.clear();damage_labels.clear();swings.clear();saved=false;reward_save_attempted=false;last_reward=0;ui_state=""
	event_notice="Cow hunt: defeat 500 cows before the eight-minute countdown ends."
	notice_clock=7;update_ui()

func return_from_cow_event() -> void:
	if base_model==null:return
	if not saved and not smoke:
		save_run()
		if not saved:return
	audio_bank.stop_all()
	var event=model
	model=base_model;base_model=null
	model.stats=event.stats.duplicate(true);model.health=event.health
	model.haste_clock=event.haste_clock;model.magnet_clock=event.magnet_clock
	model.level=event.level;model.xp=event.xp;model.xp_needed=event.xp_needed
	model.run_upgrades=event.run_upgrades.duplicate(true)
	model.rerolls_used=event.rerolls_used
	model.upgrade_ranks=event.upgrade_ranks.duplicate(true);model.base_stats=event.base_stats.duplicate(true);model.xp_fraction=event.xp_fraction
	if event.state=="dead":model.state="dead"
	else:model.state="playing"
	camera=model.player;player_age=0;player_state="idle";attack_animation=0;attack_target_id=-1;player_walk_reverse=false
	play_area_music()
	impact_particles.clear();damage_labels.clear();swings.clear();saved=false;reward_save_attempted=false;last_reward=0;ui_state="";update_ui()

func progress_path() -> String:
	return manifest.get("save_path","user://profiles/"+manifest.get("profile_id","demo")+"/runs.json")

func read_progress() -> bool:
	var document:Dictionary={}
	if FileAccess.file_exists(progress_path()):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(progress_path()))
		if not parsed is Dictionary:
			push_warning("Cannot read progress; keeping the current profile instead of replacing it.")
			return false
		document=parsed
	progress=Classes.migrate(document)
	progress["area_order"]=manifest.get("area_order",Classes.AREA_ORDER).duplicate()
	progress["available_classes"]=playable_classes().duplicate()
	if manifest.get("game_id","")=="diablo2" and progress.get("d2_shop_version",0)!=1:
		for pair in [["cleave","barbarian_cleave"],["archery","amazon_archery"],["blast","sorceress_blast"]]:
			progress.shop[pair[1]]=maxi(int(progress.shop[pair[1]]),int(progress.shop[pair[0]]))
		progress["d2_shop_version"]=1
	return true

func restore_last_played() -> void:
	var last:Dictionary=progress.get("last_played",{})
	var character:String=str(last.get("character",manifest.get("default_class","warrior")))
	selected_class=character if character in playable_classes() and Classes.unlocked(progress,character) else manifest.get("default_class","warrior")
	if not direct_cow and not treasure_demo:
		var area:String=str(last.get("area",selected_arena))
		selected_arena=area if manifest.arenas.has(area) and level_unlocked(area) else str(manifest.get("default_arena","cathedral"))
	selected_difficulty=str(last.get("difficulty","easy"))
	if not Classes.difficulty_unlocked(progress,selected_arena,selected_difficulty):selected_difficulty="easy"
	apply_arena(selected_arena)

func show_classes() -> void:
	if model.state=="victory" and model.config.get("difficulty","easy")=="legendary" and saved:
		var order:Array=manifest.get("area_order",Classes.AREA_ORDER)
		var completed_index:int=order.find(model.config.get("area_id",selected_arena))
		if completed_index>=0 and completed_index+1<order.size():
			selected_arena=str(order[completed_index+1]);selected_difficulty="easy"
	model.state="classes";play_area_music();ui_state="";update_ui()

func start_class(key: String) -> void:
	if not smoke and FileAccess.file_exists(progress_path()) and not read_progress():return
	if key not in playable_classes() or not Classes.unlocked(progress,key) or not level_unlocked(selected_arena) or (not smoke and not direct_cow and not treasure_demo and not Classes.difficulty_unlocked(progress,selected_arena,selected_difficulty)):return
	if not apply_arena(selected_arena):return
	selected_class=key
	if not smoke and not direct_cow and not treasure_demo:
		var candidate:Dictionary=progress.duplicate(true)
		candidate["last_played"]={"character":selected_class,"area":selected_arena,"difficulty":selected_difficulty}
		if not write_progress(candidate):push_warning("Could not save last played selections.")
	visuals.player=load_visual(manifest.get("class_visuals",{}).get(key,manifest.player_visual))
	restart()

func upgrade_preview(upgrade:Dictionary) -> String:
	var labels:Dictionary={"fire_power":"Scorch chance tier","poison_power":"Poison chance tier","cold_power":"Chill chance tier","lightning_power":"Shock chance tier","chaos_power":"Chaos chance tier","damage":"Damage","cooldown":"Attack interval","max_health":"Maximum HP","speed":"Movement speed","pickup_radius":"Pickup reach","projectile_count":"Projectiles per attack","projectile_pierce":"Enemies pierced","attack_count":"Attacks per cycle","area_scale":"Attack area multiplier","attack_targets":"Targets per attack","armor":"Armor","regeneration":"HP per second","crit_chance":"Critical chance","crit_multiplier":"Critical damage multiplier","knockback":"Knockback","kill_heal":"HP per kill","heal_drop_chance":"Healing-drop chance","xp_multiplier":"XP multiplier","summon_cap":"Allied minions","ally_damage":"Minion damage","ally_cooldown":"Minion attack interval","boost_duration":"Boost duration","dot_damage":"Damage per second","retaliation":"Retaliation damage","projectile_speed":"Projectile speed","splash_ratio":"Splash damage multiplier"}
	var old:float=model.stats.get(upgrade.stat,0)
	var next:float=model.tier_value(upgrade,upgrade.tier)
	if upgrade.stat in ["projectile_count","projectile_pierce","attack_count","attack_targets","summon_cap","armor","max_health"]:return "%s: %d → %d" % [labels[upgrade.stat],int(old),int(next)]
	if upgrade.stat=="boost_duration":return "Boost duration: %.0fs → %.0fs" % [old*Model.POWERUP_DURATION,next*Model.POWERUP_DURATION]
	if upgrade.stat in ["crit_chance","heal_drop_chance"]:return "%s: %.0f%% → %.0f%%" % [labels[upgrade.stat],old*100,next*100]
	if upgrade.stat in ["cooldown","ally_cooldown"]:return "%s: %.2fs → %.2fs" % [labels[upgrade.stat],old,next]
	return "%s: %s → %s" % [labels.get(upgrade.stat,"Effect"),str(snappedf(old,0.01)),str(snappedf(next,0.01))]

func upgrade_icon(index:int,upgrade_id:String="") -> Texture2D:
	if spell_icon_texture==null:return class_icon(selected_class)
	var indices:Dictionary=manifest.get("ui",{}).get("spell_icons",{}).get("upgrade_indices",{})
	if indices.has(upgrade_id):index=int(indices[upgrade_id])
	elif manifest.get("game_id","")=="diablo2":
		# Shared upgrade IDs include Diablo I icons beyond the smaller D2 sheet.
		if index==31:index=10
		# D2 frames 0/1 are empty slots; health and on-kill healing need distinct art.
		if index in [0,1]:index=14 if upgrade_id=="kill_heal" else 16 if index==1 else 4
		index=posmod(index,maxi(1,int(spell_icon_texture.get_width())/56))
	if upgrade_icon_cache.has(index):return upgrade_icon_cache[index]
	var texture:=AtlasTexture.new();texture.atlas=spell_icon_texture
	texture.region=Rect2(index*56,0,56,56);upgrade_icon_cache[index]=texture
	return texture

func menu_button(parent:Control,text:String,callback:Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(410,62)
	button.add_theme_font_size_override("font_size",18);button.pressed.connect(callback);parent.add_child(button)
	return button

func menu_action_icon(button:Button,texture:Texture2D) -> void:
	var icon:=TextureRect.new();icon.texture=texture
	button.add_child(icon)
	icon.anchor_top=0.5;icon.anchor_bottom=0.5
	icon.offset_left=20;icon.offset_right=53.6
	icon.offset_top=-16.8;icon.offset_bottom=16.8
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE

func select_character(key:String) -> void:
	if key not in playable_classes() or not Classes.unlocked(progress,key):return
	selected_class=key;ui_state="";update_ui()
func select_level(key:String) -> void:
	if not level_unlocked(key):return
	selected_arena=key
	if not Classes.difficulty_unlocked(progress,key,selected_difficulty):selected_difficulty="easy"
	ui_state="";update_ui()
func menu_label(parent:Control,text:String,size:int=20) -> void:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size);parent.add_child(label)
func highlight_selection(button:Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("1b343d") if state=="hover" else Color("11252d")
		style.border_color=Color("8ae7ef") if state in ["hover","focus"] else Color("54bfc9")
		style.set_border_width_all(2);style.set_corner_radius_all(4)
		style.content_margin_left=8;style.content_margin_right=8
		style.content_margin_top=4;style.content_margin_bottom=4
		button.add_theme_stylebox_override(state,style)

func apply_preferences() -> void:
	audio_bank.set_volume(float(preferences.sfx_volume))
	music_player.volume_db=linear_to_db(maxf(0.0001,float(preferences.music_volume)))
	music_player.stream_paused=not preferences.music_enabled or float(preferences.music_volume)<=0
	if not preferences.screen_shake:position=Vector2.ZERO

func change_preference(key:String,value:Variant) -> void:
	preferences[key]=value;apply_preferences()
	if smoke:return
	var path:String=progress_path().get_base_dir()+"/settings.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(preferences));file.flush()

func play_area_music() -> void:
	if music_player==null:return
	var area:String="cow" if model!=null and cow_event() else selected_arena
	if model!=null and (model.state in ["classes","shop","achievements","reset_confirm"] or (model.state=="settings" and settings_return=="classes")):area="menu"
	var path:String=manifest.get("music",{}).get(area,{}).get("path","")
	if path==music_path:return
	music_path=path;music_player.stop()
	if path.is_empty():return
	var stream:=AudioStreamWAV.load_from_file(path)
	if stream==null:return
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=int(stream.get_length()*stream.mix_rate)
	music_player.stream=stream;music_player.play();apply_preferences()

func show_settings() -> void:
	settings_return=model.state;model.state="settings";ui_state="";update_ui()

func build_settings() -> void:
	overlay_label("Settings",30)
	var music:=CheckButton.new();music.text="Music";music.button_pressed=preferences.music_enabled
	music.toggled.connect(func(value):change_preference("music_enabled",value));overlay_body.add_child(music)
	for key in ["music_volume","sfx_volume"]:
		var label:=Label.new();label.text=("Music volume" if key=="music_volume" else "SFX volume")+" — %d%%" % roundi(float(preferences[key])*100);overlay_body.add_child(label)
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=float(preferences[key])*100
		slider.value_changed.connect(func(value):change_preference(key,value/100.0);label.text=("Music volume" if key=="music_volume" else "SFX volume")+" — %d%%" % int(value));overlay_body.add_child(slider)
	var shake:=CheckButton.new();shake.text="Screen shake when damaged";shake.button_pressed=preferences.screen_shake
	shake.toggled.connect(func(value):change_preference("screen_shake",value));overlay_body.add_child(shake)
	overlay_button("Back",func():model.state=settings_return;ui_state="";update_ui())

func build_main_menu() -> void:
	overlay_label("Diablo Survivors",32)
	var profile_row:=HBoxContainer.new();overlay_body.add_child(profile_row)
	menu_label(profile_row,"Gold: %d  •  Lifetime kills: %d" % [int(progress.gold),int(progress.total_kills)],18)
	if manifest.has("game_id"):
		var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;profile_row.add_child(spacer)
		var source:=Button.new();source.text=("Diablo II + LoD" if manifest.get("source_game",{}).get("expansion",false) else "Diablo II" if manifest.game_id=="diablo2" else "Diablo I")+" • Change game"
		source.icon=load_local_texture("res://resources/menu/settings.svg")
		source.add_theme_constant_override("h_separation",8)
		for state in ["normal","hover","pressed","focus"]:
			var style:=StyleBoxFlat.new()
			style.bg_color=Color("24565f") if state=="hover" else Color("102e35") if state=="pressed" else Color("193f48")
			style.border_color=Color("85d5df") if state in ["hover","focus"] else Color("4b929f")
			style.set_border_width_all(1);style.set_corner_radius_all(4)
			style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=5;style.content_margin_bottom=5
			source.add_theme_stylebox_override(state,style)
		source.add_theme_color_override("font_color",Color("e1f6fa"))
		source.pressed.connect(func():get_tree().quit(20));profile_row.add_child(source)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",30);overlay_body.add_child(row)
	var characters:=VBoxContainer.new();characters.add_theme_constant_override("separation",12);row.add_child(characters)
	var levels:=VBoxContainer.new();levels.add_theme_constant_override("separation",8);row.add_child(levels)
	menu_label(characters,"Choose a character")
	var choices:Control=characters
	if playable_classes().size()>3:
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(410,420);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;characters.add_child(scroll)
		var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",12);scroll.add_child(rows);choices=rows
	for key in playable_classes():
		var available:bool=Classes.unlocked(progress,key)
		var detail:String={"warrior":"Sword cleave","rogue":"Automatic bow","sorcerer":"Firebolt","barbarian":"Weapon cleave","amazon":"Piercing arrows","paladin":"Cleave and regeneration","necromancer":"Bone Spear and skeletal ally","sorceress":"Firebolt","assassin":"Twin strikes","druid":"Firestorm and regeneration"}[key]
		if not available:detail="Locked: "+Classes.requirement(key)
		var button:=menu_button(choices,("✓ " if selected_class==key else "")+class_title(key)+"\n"+detail,select_character.bind(key))
		button.custom_minimum_size=Vector2(380 if choices!=characters else 410,94);button.icon=class_icon(key);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",78);button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;button.disabled=not available
		if key==selected_class and available:highlight_selection(button)
	menu_label(levels,"Choose an area")
	var area_scroll:=ScrollContainer.new();area_scroll.name="AreaList"
	area_scroll.custom_minimum_size=Vector2(410,145)
	area_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	levels.add_child(area_scroll)
	var area_rows:=VBoxContainer.new();area_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	area_rows.add_theme_constant_override("separation",10);area_scroll.add_child(area_rows)
	var revealed_locked:=false
	for key in manifest.arenas:
		var available:bool=level_unlocked(key)
		var completed:bool=progress.get("completed_areas",{}).get(key,false)
		var undiscovered:bool=not available and revealed_locked
		var title:String="????" if undiscovered else manifest.arenas[key].title
		var status:String="Undiscovered area" if undiscovered else "Completed" if completed else "Nightmare complete" if available and progress.get("completed_difficulties",{}).get(key,{}).get("hard",false) else "Normal complete" if available and progress.get("completed_difficulties",{}).get(key,{}).get("easy",false) else "Unlocked" if available else "Locked: finish prior area on Hell"
		var button:=menu_button(area_rows,("✓ " if selected_arena==key else "")+title+"\n"+status,select_level.bind(key))
		button.custom_minimum_size.x=380;button.disabled=not available
		if key==selected_arena and available:highlight_selection(button)
		if available:
			button.custom_minimum_size.y=96
			button.text=""
			var details:=VBoxContainer.new();button.add_child(details)
			details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			details.offset_left=12;details.offset_right=-12;details.offset_top=8;details.offset_bottom=-8
			details.alignment=BoxContainer.ALIGNMENT_CENTER
			details.add_theme_constant_override("separation",4)
			details.mouse_filter=Control.MOUSE_FILTER_IGNORE
			for line in [("✓ " if selected_arena==key else "")+title,status]:
				var label:=Label.new();label.text=line
				label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				label.add_theme_font_size_override("font_size",18)
				label.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(label)
			var badges:=HBoxContainer.new();details.add_child(badges)
			badges.alignment=BoxContainer.ALIGNMENT_CENTER;badges.mouse_filter=Control.MOUSE_FILTER_IGNORE
			for difficulty in Difficulties.ORDER:
				var badge:=Label.new();badge.text=Difficulties.title(difficulty)+ (" ✓" if progress.get("completed_difficulties",{}).get(key,{}).get(difficulty,false) else " ·")
				badge.add_theme_font_size_override("font_size",12)
				var style:=StyleBoxFlat.new();style.bg_color=Color("294c38") if progress.get("completed_difficulties",{}).get(key,{}).get(difficulty,false) else Color("202833")
				style.set_corner_radius_all(8);style.content_margin_left=7;style.content_margin_right=7
				badge.add_theme_stylebox_override("normal",style);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badges.add_child(badge)
		if key==selected_arena:area_scroll.ensure_control_visible.call_deferred(button)
		if not available:revealed_locked=true
	var mode_row:=HBoxContainer.new();levels.add_child(mode_row)
	for difficulty in Difficulties.ORDER:
		var choice:=Button.new();choice.text=("✓ " if selected_difficulty==difficulty else "")+Difficulties.title(difficulty)
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		choice.disabled=not Classes.difficulty_unlocked(progress,selected_arena,difficulty)
		choice.pressed.connect(select_difficulty.bind(difficulty));mode_row.add_child(choice)
	var play:=menu_button(levels,"Play — %d minutes" % (int(Difficulties.MODES[selected_difficulty].seconds)/60),start_class.bind(selected_class))
	menu_action_icon(play,load_local_texture("res://resources/menu/play.svg"))
	play.disabled=not Classes.unlocked(progress,selected_class) or not level_unlocked(selected_arena)
	menu_action_icon(menu_button(levels,"Permanent shop",show_shop),load_local_texture("res://resources/menu/shop.svg"))
	menu_action_icon(menu_button(levels,"Achievements & records",show_achievements),load_local_texture("res://resources/menu/achievements.svg"))
	menu_button(levels,"Reset Progress",show_reset_confirmation)
	menu_button(levels,"Settings",show_settings)
	menu_button(levels,"Exit",func():get_tree().quit())
	# Keep menu actions visible independently of how many maps are listed.
	for control in levels.get_children():
		if control is Button:control.custom_minimum_size.y=42
	if treasure_demo:menu_label(characters,"Treasure playtest: guaranteed portal",16)

func show_achievements() -> void:
	model.state="achievements";ui_state="";update_ui()
func build_achievements() -> void:
	overlay_label("Achievements & records",30)
	var tabs:=TabBar.new();tabs.add_tab("Achievements");tabs.add_tab("Challenge records");tabs.current_tab=achievement_tab
	tabs.tab_changed.connect(func(index):achievement_tab=index;ui_state="";update_ui());overlay_body.add_child(tabs)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(880,350);overlay_body.add_child(scroll)
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",12);scroll.add_child(content)
	menu_label(content,"Lifetime kills: %d  •  Best run: %d kills" % [int(progress.total_kills),int(progress.get("best_kills",0))],18)
	if achievement_tab==0:
		var achievements:Array=Classes.achievements(progress)
		if manifest.get("game_id","")=="diablo2":
			for achievement in achievements:
				achievement.title=str(achievement.title).replace("Rogue","Amazon").replace("Sorcerer","Sorceress")
			for key in playable_classes():
				if key not in ["barbarian","amazon","sorceress"]:achievements.append({"title":class_title(key)+" unlocked","description":Classes.requirement(key),"complete":Classes.unlocked(progress,key)})
		for achievement in achievements:menu_label(content,("✓ " if achievement.complete else "○ ")+achievement.title+" — "+achievement.description,18)
		for area in manifest.arenas:
			if not level_unlocked(area):continue
			menu_label(content,str(manifest.arenas[area].title),22)
			for difficulty in Difficulties.ORDER:
				menu_label(content,Difficulties.title(difficulty)+" clears: "+str(progress.get("area_clear_counts",{}).get(Difficulties.slot(area,difficulty),0)),18)
		menu_label(content,"Cow Hunt clears: "+str(progress.get("area_clear_counts",{}).get("cow",0)),18)
	else:
		var definitions:Dictionary={}
		for area in manifest.arenas:
			if not level_unlocked(area):continue
			for difficulty in Difficulties.ORDER:
				definitions[Difficulties.slot(area,difficulty)]=Difficulties.challenges(manifest.arenas[area].get("challenges",[]),difficulty,str(manifest.arenas[area].get("boss","")))
		definitions["cow"]=[]
		for target in [100,250,750]:definitions.cow.append({"id":"cow-"+str(target),"title":"Defeat %d cows" % target})
		definitions.cow.append({"id":"cow-500-bonus","title":"500-cow special challenge"})
		for area in definitions:
			var key:String=str(area).get_slice("@",0)
			var difficulty:String=str(area).get_slice("@",1) if "@" in str(area) else "easy"
			menu_label(content,"Cow Hunt" if key=="cow" else str(manifest.arenas.get(key,{}).get("title",key))+" — "+Difficulties.title(difficulty),22)
			for challenge in definitions[area]:
				var count:int=progress.get("challenge_counts",{}).get(area,{}).get(challenge.id,0)
				var claimed:bool=progress.get("completed_challenges",{}).get(area,{}).get(challenge.id,false)
				if challenge.id=="cow-500-bonus":claimed=progress.get("cow_bonus_claimed",false)
				menu_label(content,"%s — completed %d times — %s" % [challenge.title,count,"gold claimed" if claimed else "first-time gold available"],18)
	overlay_button("Main menu",show_classes)

func class_icon(key: String) -> Texture2D:
	if class_icons.has(key):return class_icons[key]
	var document:Dictionary=manifest.get("class_visuals",{}).get(key,manifest.player_visual)
	var clip:Dictionary=document.clips.get("idle",document.clips.walk)
	var texture:Texture2D
	if str(clip.sheet).begins_with("res://"):texture=load(clip.sheet) as Texture2D
	else:
		var image:=Image.load_from_file(clip.sheet)
		if image==null:return null
		texture=ImageTexture.create_from_image(image)
	var icon:=AtlasTexture.new();icon.atlas=texture;icon.region=Rect2(0,0,clip.frame_width,clip.frame_height)
	class_icons[key]=icon
	return icon

func earned_gold() -> int:
	return last_reward if saved else Classes.reward_for_progress(progress,model.summary())

func rewards_text() -> String:
	var summary:Dictionary=model.summary()
	var text:="%s  •  %s  •  %.0f seconds\n%d kills  •  Level %d\n" % [summary.area+" — "+Difficulties.title(str(summary.difficulty)),class_title(selected_class),summary.seconds,model.kills,model.level]
	var kinds:Array=model.kill_counts.keys();kinds.sort()
	for kind in kinds:
		var name:String=str(model.config.get("enemy_definitions",{}).get(kind,{}).get("name",manifest.configuration.get("enemy_definitions",{}).get(kind,{}).get("name",str(kind).capitalize())))
		if kind=="goblin":name="Treasure Goblin"
		elif kind=="cow":name="Hell Bovine" if manifest.get("game_id","")=="diablo2" else "Cow"
		text+="%s defeated: %d\n" % [name,model.kill_counts[kind]]
	text+="\nCollected XP: %d\nXP drops: %d  •  Healing drops: %d  •  Treasure bundles: %d\nHealing restored: %.0f HP  •  Loot gold: %d\n\nGold earned: %d  •  Balance: %d\n%s" % [model.collected_xp,int(model.pickup_counts.get("xp",0)),int(model.pickup_counts.get("healing",0)),int(model.pickup_counts.get("treasure",0)),model.healing_received,model.loot_gold,earned_gold(),int(progress.gold),"Rewards saved locally." if saved else "Saving rewards…" if reward_save_pending else "Rewards could not be saved."]
	text+="\n\nMap challenges (+1 gold each at expiry)\n"
	for challenge in model.challenge_results():text+="%s: %d/%d — %s — %d gold\n" % [challenge.title,mini(challenge.count,challenge.target),challenge.target,"previously completed" if challenge.get("claimed",false) else "complete" if challenge.complete else "locked" if not challenge.unlocked else "incomplete",challenge.gold]
	if cow_event():text+="\nCow challenge: %d / 500 — %s" % [model.kills,"complete" if model.state=="cow_complete" and model.kills>=500 else "not completed"]
	return text

func campaign_finished() -> bool:
	var final_area:String=manifest.get("final_arena","hell-16")
	if model.state!="victory" or selected_arena!=final_area:return false
	if not progress.get("completed_difficulties",{}).get(final_area,{}).get("legendary",false):return false
	var area:Dictionary=manifest.arenas.get(final_area,{})
	for difficulty in Difficulties.ORDER:
		var claimed:Dictionary=progress.get("completed_challenges",{}).get(Difficulties.slot(final_area,difficulty),{})
		for challenge in Difficulties.challenges(area.get("challenges",[]),difficulty,str(area.get("boss",""))):
			if not claimed.get(challenge.id,false):return false
	return true

func show_rewards() -> void:
	if not smoke and not saved:
		overlay_label("AREA COMPLETE" if model.state in ["victory","cow_complete"] else "RUN ENDED",27)
		overlay_label("Calculating rewards…",22)
		if not reward_calculation_scheduled:
			reward_calculation_scheduled=true
			calculate_rewards_after_frame()
		if reward_save_attempted and not reward_save_pending:
			overlay_label("Rewards could not be saved.",18)
			overlay_button("Exit",func():get_tree().quit())
		return
	if campaign_finished():
		overlay_label("Game Over, You beat the lords of hell",26)
		overlay_body.get_child(overlay_body.get_child_count()-1).add_theme_color_override("font_color",Color("ffdc73"))
	overlay_label("AREA COMPLETE — REWARDS" if model.state in ["victory","cow_complete"] else "RUN ENDED — REWARDS",27)
	overlay_label("Gold earned: %d  •  Balance: %d" % [earned_gold(),int(progress.gold)],23)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(540,190);overlay_body.add_child(scroll)
	var label:=Label.new();label.text=rewards_text();label.add_theme_font_size_override("font_size",18);scroll.add_child(label)
	if cow_event():overlay_button("Return to survival",return_from_cow_event)
	else:
		overlay_button("Play again (R)",restart)
		overlay_button("Choose class / shop",show_classes)
	overlay_button("Exit",func():get_tree().quit())
	if reward_save_pending:
		for child in overlay_body.get_children():
			if child is Button:child.disabled=true

func calculate_rewards_after_frame() -> void:
	# Present the frozen world and completion message before preparing reward data.
	await get_tree().process_frame
	await get_tree().process_frame
	begin_reward_save()
	ui_state=""

func overlay_label(text: String, size: int=22) -> void:
	var label := Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",size);overlay_body.add_child(label)

func overlay_button(text: String, callback: Callable) -> void:
	var button := Button.new();button.text=text;button.custom_minimum_size=Vector2(520,54);button.add_theme_font_size_override("font_size",19);button.pressed.connect(callback);overlay_body.add_child(button)

func show_character() -> void:
	if model.state=="character":model.state=sheet_return;ui_state="";update_ui();return
	if model.state not in ["playing","paused"]:return
	sheet_return=model.state;model.state="character";ui_state="";update_ui()

func character_value(parent:Control,position:Vector2,text:String,width:int=90) -> void:
	var label:=Label.new();label.position=position;label.size=Vector2(width,19);label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",14);parent.add_child(label)

func build_character_sheet() -> void:
	overlay_label(class_title(selected_class)+" — character and boosts",26)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;overlay_body.add_child(row)
	var text:="Current stats\nSpeed: %.0f   Damage: %.1f\nAttack interval: %.2fs   Range: %.0f\nTargets: %d   XP pickup range: %.0f\nArmor: %d   Gold: %d\n\nPermanent bonuses\n" % [model.stats.speed,model.stats.damage,model.stats.cooldown,model.stats.attack_range,int(model.stats.attack_targets),model.stats.pickup_radius,int(model.stats.get("armor",0)),int(progress.gold)]
	var bonuses:=0
	for key in Classes.SHOP:
		var item:Dictionary=Classes.SHOP[key]
		if item.has("class") and item["class"]!=selected_class:continue
		var rank:int=progress.shop.get(key,0)
		if rank>0:text+="%s: rank %d\n" % [item.title,rank];bonuses+=1
	if bonuses==0:text+="None purchased yet.\n"
	text+="\nRun upgrades\n"
	if model.run_upgrades.is_empty():text+="None chosen yet."
	else:
		for title in model.run_upgrades:text+="%s — Tier %d\n" % [title,model.run_upgrades[title]]
	text+="\n\nAttack count: %d  •  Area: +%.0f%%\nCritical chance: %.0f%%  •  Regen: %.1f HP/s" % [int(model.stats.attack_count),(float(model.stats.area_scale)-1)*100,float(model.stats.crit_chance)*100,float(model.stats.regeneration)]
	var scroll:=ScrollContainer.new();scroll.name="CharacterDetails";scroll.custom_minimum_size=Vector2(0,352);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
	var label:=Label.new();label.text=text;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",18);scroll.add_child(label)
	if visuals.player.has("idle"):
		var preview_column:=VBoxContainer.new();preview_column.name="CharacterPreview";preview_column.custom_minimum_size.x=220;row.add_child(preview_column)
		var title:=Label.new();title.text="Character preview";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;preview_column.add_child(title)
		character_preview=TextureRect.new();character_preview.custom_minimum_size=Vector2(220,270);character_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;character_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;character_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview_column.add_child(character_preview)
		var controls:=HBoxContainer.new();preview_column.add_child(controls)
		var left:=Button.new();left.text="◀";left.custom_minimum_size=Vector2(36,32);left.focus_mode=Control.FOCUS_NONE;left.pressed.connect(rotate_character_preview.bind(-1));controls.add_child(left)
		var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(spacer)
		var right:=Button.new();right.text="▶";right.custom_minimum_size=Vector2(36,32);right.focus_mode=Control.FOCUS_NONE;right.pressed.connect(rotate_character_preview.bind(1));controls.add_child(right)
		var hint:=Label.new();hint.text="← / → Rotate";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",14);preview_column.add_child(hint)
		rotate_character_preview(0)
	overlay_button("Close (C)",show_character)

func rotate_character_preview(step:int) -> void:
	character_preview_direction=posmod(character_preview_direction+step,8)
	if not is_instance_valid(character_preview):return
	var clip:Dictionary=visuals.player.idle
	var info:Dictionary=clip.info
	var direction:int=CHARACTER_PREVIEW_ORDER[character_preview_direction] if info.frames_per_direction.size()==8 else 0
	var key:String=str(info.sheet)+"@"+str(direction)
	if not character_sprite_views.has(key):
		var columns:int=int(info.get("frame_columns",info.frames_per_direction[direction]))
		var rows:int=ceili(float(info.frames_per_direction[direction])/columns)
		var image:Image=clip.texture.get_image().get_region(Rect2i(0,direction*rows*int(info.frame_height),int(info.frame_width),int(info.frame_height)))
		var bounds:Rect2i=image.get_used_rect()
		if bounds.has_area():image=image.get_region(bounds)
		character_sprite_views[key]=ImageTexture.create_from_image(image)
	character_preview.texture=character_sprite_views[key]

func choose(index: int) -> void:
	model.choose_upgrade(index);update_ui()

func update_ui() -> void:
	if ailment_hud!=null and model!=null:
		ailment_hud.text=""
		for element in model.player_conditions.ailments:
			var effect:Dictionary=model.player_conditions.ailments[element]
			ailment_hud.text+="[color=#%s]● %s  %.1fs[/color]\n" % [Ailments.COLORS[element].to_html(false),Ailments.NAMES[element],effect.remaining]
		ailment_hud.visible=model.state in ["playing","paused","upgrade","character"]
	var remaining:int=maxi(0,int(ceil(float(model.config.duration_seconds)-model.elapsed)))
	hud.text="%s — %s (%s)\nHP %d / %d   •   Level %d   •   Wave %d\n%d kills" % [manifest.get("title","Survival"),class_title(selected_class),Difficulties.title(str(model.config.get("difficulty","easy"))),int(model.health),int(model.stats.max_health),model.level,model.wave,model.kills]
	if not cow_event():
		var plan:Dictionary=model.surge_plan()
		hud.text=hud.text.replace("Wave %d" % model.wave,"Surge %d%s" % [model.wave," — recovery" if not plan.active or model.surge_spawned>=int(plan.quota) else ""])
	var menu_open:bool=model.state in ["classes","shop","achievements","reset_confirm","settings"]
	hud.visible=not menu_open;hp_bar.visible=not menu_open;xp_bar.visible=not menu_open
	var buff_row:=0
	var buff_top:float=xp_bar.position.y+xp_bar.size.y+12
	for kind in powerup_bars:
		var seconds:float=model.haste_clock if kind=="haste" else model.magnet_clock
		var bar:ProgressBar=powerup_bars[kind];bar.visible=not menu_open and seconds>0
		if bar.visible:
			bar.position=Vector2(28,buff_top+buff_row*32);bar.max_value=Model.POWERUP_DURATION*float(model.stats.boost_duration);bar.value=seconds
			bar.get_child(0).text=("Speed boost" if kind=="haste" else "XP Magnet")+" — %.1fs" % seconds
			buff_row+=1
	challenge_label.position.y=buff_top+buff_row*32+8
	cow_timer.visible=not menu_open
	speed_panel.visible=not menu_open and model.state in ["playing","paused","upgrade","character"]
	cow_timer.text="%02d:%02d" % [remaining/60,remaining%60]
	var urgent:bool=remaining<=60
	var pulse:=0.5+0.5*sin(float(Time.get_ticks_msec())*0.009) if urgent and model.state=="playing" and remaining>0 else 0.5
	cow_timer.add_theme_color_override("font_color",Color(1,0.2+0.15*pulse,0.2+0.12*pulse) if urgent else Color("fff0ce"))
	cow_timer.add_theme_color_override("font_outline_color",Color("530b13") if urgent else Color("151c16"))
	cow_timer.scale=Vector2.ONE*(1+0.045*pulse if urgent and remaining>0 else 1.0)
	if cow_event():hud.text="Cow Hunt — %s\nHP %d / %d   •   Level %d\nCows %d / 500   •   Reward at zero: 2 gold" % [class_title(selected_class),int(model.health),int(model.stats.max_health),model.level,model.kills]
	elif not model.portal.is_empty():hud.text+="   •   Cow portal: approach and press E"
	challenge_label.visible=model.state in ["playing","paused"]
	challenge_label.text=""
	var active:Dictionary={}
	var complete_count:=0
	for challenge in model.challenge_results():
		if challenge.complete:complete_count+=1
		elif challenge.unlocked:active=challenge
	if not active.is_empty():challenge_label.text="Challenge: %s  %d/%d  •  +1 gold at area end" % [active.title,mini(active.count,active.target),active.target]
	elif complete_count>0:challenge_label.text="All map challenges complete  •  %d gold pending at area end" % complete_count
	hp_bar.max_value=model.stats.max_health;hp_bar.value=model.health
	hp_fill.bg_color=health_bar_color(model.health/maxf(1.0,model.stats.max_health))
	xp_bar.max_value=model.xp_needed;xp_bar.value=model.xp
	if model.state==ui_state:return
	ui_state=model.state
	for child in overlay_body.get_children():overlay_body.remove_child(child);child.queue_free()
	# Reserve space for all class rows, purchase feedback and navigation on every rebuild.
	overlay.custom_minimum_size=Vector2(600,520) if model.state=="shop" else Vector2(960,640) if model.state=="classes" else Vector2.ZERO
	overlay.position=Vector2(160,25) if model.state=="classes" else Vector2(160,50) if model.state=="achievements" else Vector2(240,90) if model.state=="upgrade" else Vector2(220,100) if model.state=="character" else Vector2(320,70) if model.state in ["victory","dead","cow_complete"] else Vector2(340,150)
	overlay.size=Vector2(960,600) if model.state in ["classes","achievements"] else Vector2(800,520) if model.state=="upgrade" else Vector2(840,480) if model.state=="character" else Vector2(640,550) if model.state in ["victory","dead","cow_complete"] else Vector2(600,360)
	overlay.visible=model.state!="playing"
	if model.state=="character":build_character_sheet()
	elif model.state=="classes":build_main_menu()
	elif model.state=="achievements":build_achievements()
	elif model.state=="reset_confirm":
		overlay_label("Reset game progress?",27)
		overlay_label("All gold, permanent upgrades, unlocks, challenges, achievements and records will return to their starting values.",18)
		overlay_button("Yes",reset_progress)
		overlay_button("No",show_classes)
	elif model.state=="shop":
		overlay_label("Permanent upgrades — %d gold" % int(progress.gold),27)
		overlay_label("Bonuses apply next run. Class bonuses name their owner.",18)
		var tabs:=TabBar.new()
		var categories: Array=["General","Defense","Class"]
		for category in categories:tabs.add_tab(category)
		tabs.current_tab=categories.find(shop_category)
		tabs.tab_changed.connect(func(index):shop_category=categories[index];ui_state="";update_ui())
		overlay_body.add_child(tabs)
		var shop_rows:Control=overlay_body
		if shop_category!="Class" or playable_classes().size()>3:
			var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(540,250);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;overlay_body.add_child(scroll)
			var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",12);scroll.add_child(rows);shop_rows=rows
		for key in Classes.SHOP:
			var item:Dictionary=Classes.SHOP[key]
			if item.category!=shop_category:continue
			if item.has("class") and item["class"] not in playable_classes():continue
			var class_locked:bool=item.has("class") and not Classes.unlocked(progress,str(item["class"]))
			var rank:int=progress.shop[key]
			var cost:int=Classes.price(progress,key)
			var button:=Button.new();button.text="%s %d/%d — %s\n%s" % [item.title,rank,item.cap,"LOCKED" if class_locked else "MAX" if rank>=item.cap else str(cost)+" gold",item.effect]
			button.custom_minimum_size=Vector2(520,62);button.add_theme_font_size_override("font_size",19);button.pressed.connect(buy.bind(key));shop_rows.add_child(button)
			button.disabled=class_locked or rank>=item.cap or progress.gold<cost
		if not shop_message.is_empty():overlay_label(shop_message,17)
		overlay_button("Main menu",show_classes)
	elif model.state=="upgrade":
		overlay_label("LEVEL %d — choose your upgrade" % model.level,27)
		for i in range(model.offered.size()):
			var upgrade:Dictionary=model.offered[i]
			var title:String=str(upgrade.title).replace(Classes.archetype(selected_class).capitalize()+":",class_title(selected_class)+":")
			if not upgrade.get("recovery",false):title+=" — Tier %d/%d" % [upgrade.tier,upgrade.max_tier]
			var detail:String=upgrade.description
			if not upgrade.get("recovery",false):detail+="\n"+upgrade_preview(upgrade)
			overlay_button("%d. %s\n%s" % [i+1,title,detail],choose.bind(i))
			var button:=overlay_body.get_child(overlay_body.get_child_count()-1) as Button
			button.custom_minimum_size=Vector2(740,110);button.add_theme_font_size_override("font_size",16)
			button.icon=upgrade_icon(int(upgrade.get("icon",0)),str(upgrade.get("id","")));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",56);button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.text=""
			var copy:=VBoxContainer.new();button.add_child(copy)
			copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			copy.offset_left=72;copy.offset_right=-8;copy.alignment=BoxContainer.ALIGNMENT_CENTER
			copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var heading:=Label.new();heading.text="%d. %s" % [i+1,title]
			heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;heading.add_theme_font_size_override("font_size",22)
			heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.add_child(heading)
			var description:=Label.new();description.text=detail
			description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;description.add_theme_font_size_override("font_size",16)
			description.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.add_child(description)
		var rerolls_remaining:int=maxi(0,model.reroll_limit()-model.rerolls_used)
		overlay_button("Reroll upgrades — %d remaining" % rerolls_remaining if rerolls_remaining>0 else "No rerolls remaining",reroll_upgrades)
		(overlay_body.get_child(overlay_body.get_child_count()-1) as Button).disabled=not model.can_reroll()
	elif model.state=="settings":build_settings()
	elif model.state=="paused":
		overlay_label("Paused",30)
		overlay_button("Resume",func():model.state="playing";update_ui())
		overlay_button("Settings",show_settings)
		overlay_button("Exit game",func():get_tree().quit())
	elif model.state in ["dead","victory","cow_complete"]:show_rewards()

func reroll_upgrades() -> void:
	if model.reroll_upgrades():ui_state="";update_ui()

func write_progress(candidate: Dictionary) -> bool:
	var path:=progress_path()
	var absolute:=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:return false
	var output:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if output==null:return false
	output.store_string(JSON.stringify(candidate,"  "));output.flush()
	var error:=output.get_error();output.close()
	if error!=OK:return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:return false
	progress=candidate
	return true

func save_run() -> void:
	if saved or smoke:return
	if not read_progress():return
	var candidate:Dictionary=Classes.record(progress,model.summary())
	var earned:int=candidate.runs.back().gold_earned
	saved=write_progress(candidate)
	if saved:last_reward=earned
	if not saved:push_warning("Unable to save run progress")

func begin_reward_save() -> void:
	if saved or smoke or reward_save_attempted:return
	reward_save_attempted=true;reward_save_pending=true
	reward_thread=Thread.new()
	var job:=preload("res://scripts/reward_writer.gd").save.bind(ProjectSettings.globalize_path(progress_path()),model.summary().duplicate(true),progress.duplicate(true))
	if reward_thread.start(job)!=OK:
		reward_save_pending=false;reward_thread=null

func poll_reward_save() -> void:
	if not reward_save_pending or reward_thread==null or reward_thread.is_alive():return
	var result:Dictionary=reward_thread.wait_to_finish()
	reward_thread=null;reward_save_pending=false;saved=result.get("ok",false)
	if saved:progress=result.progress;last_reward=int(result.earned)
	ui_state=""

func _exit_tree() -> void:
	if reward_thread!=null and reward_thread.is_started():reward_thread.wait_to_finish()

func show_shop() -> void:
	if FileAccess.file_exists(progress_path()):read_progress()
	model.state="shop";ui_state="";shop_message="";update_ui()

func buy(key: String) -> void:
	if not Classes.SHOP.has(key):return
	if Classes.SHOP[key].has("class") and Classes.SHOP[key]["class"] not in playable_classes():return
	# Refresh disk state so an older window cannot purchase from a stale balance/rank.
	if FileAccess.file_exists(progress_path()) and not read_progress():
		shop_message="Could not read your save. Purchase cancelled.";ui_state="";update_ui();return
	var candidate:Dictionary=Classes.purchase(progress,key)
	if candidate.is_empty():return
	if not candidate.get("purchase_history") is Array:candidate["purchase_history"]=[]
	candidate.purchase_history.append({"upgrade":key,"rank":candidate.shop[key],"cost":Classes.price(progress,key),"gold_after":candidate.gold,"time":Time.get_unix_time_from_system()})
	if write_progress(candidate):shop_message="Purchased "+str(Classes.SHOP[key].title).replace(str(Classes.SHOP[key].get("class","")).capitalize()+":",class_title(shop_class(str(Classes.SHOP[key].get("class",""))))+":")+". Applies to your next run."
	else:shop_message="Could not save purchase. Your gold was kept."
	ui_state="";update_ui()

func _unhandled_input(event:InputEvent) -> void:
	if model==null or auto_attack_enabled or model.state!="playing":return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		model.auto_attack_enabled=false
		model.request_manual_attack(camera+get_local_mouse_position()-Vector2(640,360))

func _unhandled_key_input(event: InputEvent) -> void:
	if model==null or not event is InputEventKey or not event.pressed or event.echo:return
	if model.state=="character" and event.physical_keycode in [KEY_LEFT,KEY_RIGHT]:
		rotate_character_preview(-1 if event.physical_keycode==KEY_LEFT else 1);get_viewport().set_input_as_handled();return
	if reward_save_pending:return
	if event.physical_keycode==KEY_M:audio_bank.set_muted(not audio_bank.muted)
	elif event.physical_keycode==KEY_T:
		auto_attack_enabled=not auto_attack_enabled;model.auto_attack_enabled=auto_attack_enabled
		if not auto_attack_enabled:attack_target_id=-1
	elif event.physical_keycode==KEY_E:enter_cow_event()
	elif event.physical_keycode==KEY_C:show_character()
	elif model.state=="upgrade":
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:choose(event.physical_keycode-KEY_1)
	elif event.physical_keycode==KEY_R and model.state in ["dead","victory"]:restart()
	elif event.physical_keycode in [KEY_ESCAPE,KEY_SPACE]:
		if model.state=="playing":model.state="paused"
		elif model.state=="paused":model.state="playing"
		update_ui()

func movement_for_animation(requested: Vector2) -> Vector2:
	return requested

func update_attack_facing(movement:Vector2) -> void:
	var tracking:=false
	if attack_target_id>=0:
		for enemy in model.enemies:
			if enemy.id!=attack_target_id or enemy.health<=0:continue
			var offset:Vector2=enemy.position-model.player
			var reach:float=float(model.stats.attack_range)*(float(model.stats.area_scale) if model.config.get("weapon","sword")=="sword" else 1.0)
			if offset.length()<=reach and (model.navigation==null or model.navigation.clear_attack(model.player,enemy.position)):
				facing=model.direction_index(offset);tracking=true
			break
	if not tracking:
		attack_target_id=-1
		if movement!=Vector2.ZERO and attack_animation<=0:facing=model.direction_index(movement)
	var forward:=Vector2.from_angle(PI/2+facing*PI/4)
	player_walk_reverse=movement!=Vector2.ZERO and movement.normalized().dot(forward)<-0.15

func clean_window_title() -> void:
	await get_tree().process_frame
	DisplayServer.window_set_title("Diablo Survivors v"+str(ProjectSettings.get_setting("application/config/display_version","0.24 beta")))

func health_bar_color(ratio:float) -> Color:
	if ratio<=0.15:return Color("ef4e4e")
	if ratio<=0.30:return Color("f29b38")
	if ratio<=0.50:return Color("f2cc58")
	return Color("65d879")

func update_hit_feedback() -> void:
	var hit_strength:float=hp_flash/0.22 if model.state in ["playing","dead"] else 0.0
	position=Vector2(sin((0.22-hp_flash)*95),cos((0.22-hp_flash)*121))*4.0*hit_strength if preferences.screen_shake else Vector2.ZERO
	hit_overlay.color.a=0.18*hit_strength

func impact_event(event:Dictionary) -> void:
	if event.kind not in ["damage","kill","player_hit"]:return
	if event.kind=="damage" and (event.get("fatal",false) or not event.get("impact",true)):return
	var kind:String="blood" if event.kind=="player_hit" else manifest.configuration.get("enemy_definitions",{}).get(event.get("actor","skeleton"),{}).get("impact","bone" if event.get("actor","")=="skeleton" else "blood")
	if not impact_visuals.has(kind):return
	var death:bool=event.kind=="kill"
	impact_particles.append({"position":event.get("position",model.player),"kind":kind,"death":death,"age":0.0,"lifetime":6.0 if death and kind!="bone" else 0.65})
	if impact_particles.size()>96:impact_particles.pop_front()

func draw_impact_effect(particle:Dictionary) -> void:
	var clip:Dictionary=impact_visuals[particle.kind]["walk" if particle.death else "idle"]
	var info:Dictionary=clip.info
	var frame:=mini(int(particle.age/float(info.frame_seconds)),int(info.frames_per_direction[0])-1)
	var size:=Vector2(info.frame_width,info.frame_height)
	var position:Vector2=screen(particle.position)+Vector2(0,-16 if particle.death else -35)
	var color:=Color.WHITE;color.a=minf(1.0,(float(particle.lifetime)-float(particle.age))/0.3)
	draw_texture_rect_region(clip.texture,Rect2(position-size/2,size),Rect2(frame*size.x,0,size.x,size.y),color)

func sound_event(event:Dictionary) -> void:
	if event.kind in ["damage","kill","firebolt_impact"] and not Rect2(Vector2.ZERO,Vector2(1280,720)).has_point(screen(event.get("position",model.player))):return
	var key:=""
	var priority:=false
	match event.kind:
		"attack":key=selected_class+".attack";priority=true
		"damage":
			if event.get("fatal",false) and event.get("impact",true):
				var death_key:String="goblin.hit" if event.get("actor","")=="goblin" else event.get("actor","skeleton")+".death"
				if death_key.ends_with(".death") and randf()>=0.5:death_key=""
				audio_bank.play_hit_sequence(death_key,event.get("position",model.player),model.player)
				return
			if event.get("impact",true):audio_bank.play_effect("combat.impact",event.get("position",model.player),model.player)
			if event.get("actor","")=="goblin":key="goblin.hit"
			elif not event.get("fatal",false):key=event.get("actor","skeleton")+".hit"
		"kill":
			if event.get("player_impact",false):return
			if randf()>=0.5:return
			key=event.get("actor","skeleton")+".death"
		"enemy_attack":key=event.get("actor","skeleton")+".attack"
		"player_hit":key=selected_class+".hit";priority=true
		"player_death":key=selected_class+".death";priority=true
		"firebolt_impact":key="firebolt.impact"
		"powerup":key="loot.powerup";priority=true
		"xp_pickup":key="loot.xp"
		"healing_pickup":key="loot.healing";priority=true
		"gold_pickup":key="loot.gold";priority=true
		"treasure_collected":key="loot.treasure";priority=true
		"portal":key="portal.open"
		"run_complete":key="run.complete";priority=true
		"goblin_spawn":key="goblin.spawn";priority=true
	if key=="goblin.spawn":
		# Announce the spawn at the listener even when the goblin is offscreen.
		audio_bank.play_effect(key,model.player,model.player,true)
		return
	if not key.is_empty():audio_bank.play_effect(key,event.get("position",model.player),model.player,priority)

func _physics_process(delta: float) -> void:
	if model==null:return
	if smoke or model.state!="playing" or game_speed==1.0:
		simulation_step(delta)
		return
	# Small simulation steps retain collision and attack timing at high speed.
	var remaining:float=delta*game_speed
	while remaining>0.000001 and model.state=="playing":
		var slice:float=minf(remaining,1.0/60.0)
		simulation_step(slice,false);remaining-=slice
	update_powerup_particles();update_ui();queue_redraw()

func simulation_step(delta:float,refresh:bool=true) -> void:
	if model==null:return
	poll_reward_save()
	audio_bank.follow(model.player)
	audio_bank.pause_effects(model.state in ["paused","upgrade","character","classes","shop","achievements","settings"])
	ticks+=1
	var step:=0.05 if smoke else delta
	hp_flash=maxf(0.0,hp_flash-delta)
	var movement:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	if smoke:movement=Vector2(0.1,0)
	movement=movement_for_animation(movement)
	if model.state=="playing":
		reward_calculation_scheduled=false
		var walk_info:Dictionary=visuals.player.walk.info
		var walk_step:float=float(walk_info.frame_seconds)*float(walk_info.frames_per_direction.max())/2.0
		model.config.attack_interval_floor=0.22+walk_step+0.05
		attack_ready_flash=maxf(0,attack_ready_flash-step)
		var previous_attack_clock:float=model.attack_clock
		notice_clock=maxf(0,notice_clock-step)
		model.ally_visible_bounds=Rect2(camera-Vector2(560,280),Vector2(1120,560))
		model.allies_are_wisps=selected_class!="necromancer"
		model.auto_attack_enabled=auto_attack_enabled
		model.tick(step,movement)
		if previous_attack_clock>0 and model.attack_clock<=0:attack_ready_flash=0.25
		attack_animation=maxf(0,attack_animation-step)
		audio_bank.follow(model.player)
		for event in model.events:
			if event.kind=="player_hit":hp_flash=0.22
			sound_event(event)
			impact_event(event)
			if event.kind=="extra_strike":swings.append({"position":event.position,"direction":event.direction,"age":0.0})
			elif event.kind=="attack":
				attack_target_id=int(event.get("target_id",-1))
				facing=model.direction_index(event.direction)
				attack_animation_span=minf(0.56,model.attack_interval()-walk_step-0.05)
				attack_animation=attack_animation_span;attack_ready_flash=0.25;player_age=0
				swings.append({"position":event.position,"direction":event.direction,"age":0.0})
			elif event.kind=="formation_warning":
				event_notice="Incoming %s formation%s" % [event.shape," — elite arrival marked!" if event.elite else "!"];notice_clock=3
			elif event.kind in ["goblin_spawn","treasure","portal"]:
				event_notice={"goblin_spawn":"A treasure goblin appeared!","treasure":"Treasure dropped: collect its XP and gold!","portal":"A rare cow portal opened! Approach and press E."}[event.kind];notice_clock=6
			elif event.kind=="powerup":
				event_notice={"healing":"Healing collected: +35% maximum HP","haste":"Speed boost collected: +35% movement","magnet":"XP Magnet collected: draws nearby loot","vacuum":"Orb Harvest! All XP orbs are flying to you."}[event.powerup];notice_clock=3
			elif event.kind=="treasure_collected":
				event_notice="Treasure collected! +%d gold • +%d XP • +%d HP" % [event.gold,event.xp,int(event.healing)];notice_clock=7
			elif event.kind=="damage":damage_labels.append({"position":event.position,"amount":event.amount,"critical":event.get("critical",false),"age":0.0})
		for particle in impact_particles:particle.age+=step
		impact_particles=impact_particles.filter(func(particle):return particle.age<particle.lifetime)
		for label in damage_labels:label.age+=step
		for swing in swings:swing.age+=step
		damage_labels=damage_labels.filter(func(label):return label.age<0.7)
		swings=swings.filter(func(swing):return swing.age<0.2)
	if model.state=="playing":update_attack_facing(movement)
	var desired:="death" if model.state=="dead" else "attack" if attack_animation>0 else "walk" if movement!=Vector2.ZERO else "idle"
	if desired!=player_state:player_state=desired;player_age=0
	elif model.state in ["playing","dead","victory"]:player_age+=step
	camera=model.nearest_position(camera,model.player)
	camera=camera.lerp(model.player,1-exp(-10*delta))
	model.ally_visible_bounds=Rect2(camera-Vector2(560,280),Vector2(1120,560))
	model.constrain_allies()
	update_hit_feedback()
	if smoke and model.state=="upgrade":model.choose_upgrade(0)
	if refresh:
		update_powerup_particles()
		update_ui();queue_redraw()
	if smoke and model.state in ["victory","cow_complete"]:
		if model.kills<1:fail("Survival smoke produced no combat")
		else:
			print("GAMESHIFT_SURVIVAL_OK: resources, pursuit, combat, pickups, victory")
			print("GAMESHIFT_SMOKE_OK")
			get_tree().quit(0)
	elif smoke and ticks>600:fail("Survival smoke timed out")

func screen(position: Vector2) -> Vector2:
	return model.nearest_position(position,camera)-camera+Vector2(640,360)

func visible_town_pieces() -> Array:
	if cow_event():return []
	var bucket:=Vector2i(int(floor(camera.x/128)),int(floor(camera.y/64)))
	if bucket==town_cache_bucket:return town_cache
	town_cache_bucket=bucket
	town_cache.clear()
	var center:=Vector2(bucket.x*128+64,bucket.y*64+32)
	for repeat_y in range(-1,2):
		for repeat_x in range(-1,2):
			var sample_center:Vector2=center+Vector2(repeat_x,repeat_y)*model.arena.size
			var min_x:=int(town.grid_width)
			var max_x:=0
			var min_y:=int(town.grid_height)
			var max_y:=0
			var origin:=Vector2(town.origin[0],town.origin[1])
			for offset in [Vector2(-800,-450),Vector2(800,-450),Vector2(-800,720),Vector2(800,720)]:
				var point:Vector2=sample_center+offset-origin
				var gx:=int(round(point.x/64+point.y/32))
				var gy:=int(round(point.y/32-point.x/64))
				min_x=mini(min_x,gx);max_x=maxi(max_x,gx);min_y=mini(min_y,gy);max_y=maxi(max_y,gy)
			for y in range(maxi(0,min_y-1),mini(int(town.grid_height),max_y+2)):
				for x in range(maxi(0,min_x-1),mini(int(town.grid_width),max_x+2)):
					var position:Vector2=model.nearest_position(origin+Vector2((x-y)*32,(x+y)*16),center)
					if absf(position.x-center.x)>800 or position.y<center.y-450 or position.y>center.y+720:continue
					var piece:int=town.pieces[y*int(town.grid_width)+x]
					var bounds:Array=town.get("upper_bounds",[])[piece] if town.has("upper_bounds") else [0,0,64,224]
					if town_floor_texture!=null and bounds.is_empty():continue
					town_cache.append({"kind":"terrain","position":position,"piece":piece,"bounds":bounds})
	town_cache.sort_custom(func(a,b):return a.position.y<b.position.y)
	return town_cache

func draw_town_piece(item: Dictionary,upper: bool) -> void:
	var source:=Vector2(item.piece%int(town.columns)*64,int(item.piece/int(town.columns))*256)
	if upper:
		var bounds:Array=item.get("bounds",[0,0,64,224])
		if bounds.is_empty():return
		var offset:=Vector2(bounds[0],bounds[1])
		var size:=Vector2(bounds[2]-bounds[0],bounds[3]-bounds[1])
		draw_texture_rect_region(town_texture,Rect2(screen(item.position)-Vector2(32,240)+offset,size),Rect2(source+offset,size))
	else:draw_texture_rect_region(town_texture,Rect2(screen(item.position)-Vector2(32,16),Vector2(64,32)),Rect2(source+Vector2(0,224),Vector2(64,32)))

func draw_floor() -> void:
	if surface_texture!=null and not cow_event():
		for y in range(-1,2):
			for x in range(-1,2):draw_texture(surface_texture,Vector2(x,y)*model.arena.size-camera+Vector2(640,360))
		return
	if not town.is_empty() and not cow_event():
		# Fill the rectangular repeat cell around the original irregular map footprint.
		var ground_piece:int=town.pieces[model.navigation.available[0]] if model.navigation!=null and not model.navigation.available.is_empty() else town.pieces[0]
		for row in range(floori((camera.y-440)/16)-1,ceili((camera.y+440)/16)+2):
			for column in range(floori((camera.x-720)/64)-1,ceili((camera.x+720)/64)+2):
				var point:=Vector2(column*64+posmod(row,2)*32,row*16)
				var source:=Vector2(ground_piece%int(town.columns)*64,int(ground_piece/int(town.columns))*256+224)
				draw_texture_rect_region(town_texture,Rect2(point-camera+Vector2(640,360)-Vector2(32,16),Vector2(64,32)),Rect2(source,Vector2(64,32)))
		if town_floor_texture!=null:
			for y in range(-1,2):
				for x in range(-1,2):draw_texture(town_floor_texture,Vector2(x,y)*model.arena.size-camera+Vector2(640,360))
		else:
			for item in visible_town_pieces():draw_town_piece(item,false)
		return
	var begin:=camera-Vector2(720,440)
	var end:=camera+Vector2(720,440)
	var source:=Rect2()
	if floor_texture!=null:
		var index:int=terrain.tile_index
		source=Rect2(index%int(terrain.columns)*128,index/int(terrain.columns)*terrain.cell_height+terrain.cell_height-64,128,64)
	for row in range(int(begin.y/32)-1,int(end.y/32)+2):
		for column in range(int(begin.x/128)-1,int(end.x/128)+2):
			var position:=Vector2(column*128+(row%2)*64,row*32)
			var target:=position-camera+Vector2(640,360)-Vector2(64,32)
			if floor_texture!=null and not cow_event():
				var variants:Array=terrain.get("tile_indices",[terrain.tile_index])
				var canonical:Vector2=model.wrap_position(position)
				var tile:int=int(variants[posmod(floori(canonical.x/128)*17+floori(canonical.y/32)*31,variants.size())])
				var tile_source:=Rect2(tile%int(terrain.columns)*128,int(tile/int(terrain.columns))*terrain.cell_height+terrain.cell_height-64,128,64)
				draw_texture_rect_region(floor_texture,Rect2(target,Vector2(128,64)),tile_source)
			else:draw_colored_polygon(PackedVector2Array([target+Vector2(64,0),target+Vector2(128,32),target+Vector2(64,64),target+Vector2(0,32)]),(Color("344327") if (column+row)%2==0 else Color("2f3d23")) if cow_event() else (Color("152c35") if (column+row)%2==0 else Color("1b3540")))

func enemy_death_durations() -> Dictionary:
	var durations:Dictionary={}
	for kind in visuals:
		if not visuals[kind].has("death"):continue
		var info:Dictionary=visuals[kind].death.info
		var frames:Array=[]
		for count in info.frames_per_direction:frames.append(float(count)*float(info.frame_seconds))
		durations[kind]=frames
	return durations

func draw_actor(kind:String,state:String,position:Vector2,direction:int,age:float,color:Color=Color.WHITE,scale_factor:float=1.0,reverse_playback:bool=false,continuous_position:bool=false) -> void:
	if state=="death" and visuals[kind].has("dead"):
		var death_info:Dictionary=visuals[kind].death.info
		var death_row:int=direction if death_info.frames_per_direction.size()==8 else 0
		var death_duration:float=float(death_info.frames_per_direction[death_row])*float(death_info.frame_seconds)
		if age>=death_duration:state="dead";age-=death_duration
	var clip:Dictionary=visuals[kind].get(state,visuals[kind].walk)
	var info:Dictionary=clip.info
	var row:=direction if info.frames_per_direction.size()==8 else 0
	var count:int=info.frames_per_direction[row]
	if kind=="player" and state=="attack":age=age*float(count)*float(info.frame_seconds)/maxf(0.01,attack_animation_span)
	var frame:int=int(age/float(info.frame_seconds))
	frame=frame%count if state in ["walk","idle"] else mini(frame,count-1)
	if state=="walk" and reverse_playback:frame=count-1-frame
	var dimensions:=Vector2(info.frame_width,info.frame_height)
	var columns:int=int(info.get("frame_columns",count))
	var rows_per_direction:int=ceili(float(count)/columns)
	var source:=Rect2((frame%columns)*info.frame_width,(row*rows_per_direction+frame/columns)*info.frame_height,dimensions.x,dimensions.y)
	var anchor:Array=info.get("anchor",[dimensions.x/2,dimensions.y])
	var point:Vector2=position-camera+Vector2(640,360) if continuous_position else screen(position)
	draw_texture_rect_region(clip.texture,Rect2(point-Vector2(anchor[0],anchor[1])*scale_factor,dimensions*scale_factor),source,color)

func draw_goblin(position:Vector2,direction:int,age:float,color:Color=Color.WHITE) -> void:
	if goblin_texture==null:return
	var row:=0
	if direction in [1,2,3]:row=1
	elif direction in [5,6,7]:row=2
	if direction==4:row=3
	var cell:=goblin_texture.get_size()/4
	var source:=Rect2(Vector2(int(age/0.12)%4,row)*cell,cell)
	draw_texture_rect_region(goblin_texture,Rect2(screen(position)-Vector2(38,73),Vector2(76,76)),source,color)

func draw_cow(position:Vector2,direction:int,age:float,color:Color=Color.WHITE) -> void:
	if visuals.has("cow"):draw_actor("cow","walk",position,direction,age,color)
	else:
		var point:=screen(position)
		draw_circle(point+Vector2(0,-18),20,Color("f0ead7")*color)
		draw_circle(point+Vector2(9,-21),7,Color("504237")*color)
		draw_circle(point+Vector2(-17,-12),9,Color("f0ead7")*color)
		for x in [-13,12]:draw_line(point+Vector2(x,-9),point+Vector2(x,3),Color("635448")*color,5)

func update_powerup_particles() -> void:
	if particle_fx==null:
		particle_fx=preload("res://scripts/powerup_particles.gd").new();add_child(particle_fx)
	particle_fx.sync(self)

func powerup_color(kind:String) -> Color:
	return {"healing":Color("39ff88"),"haste":Color("ff43d5"),"magnet":Color("38eaff"),"vacuum":Color("b78aff")}[kind]
func draw_spell_sprite(kind:String,point:Vector2,direction:int,age:float,opacity:float=1.0,velocity:Vector2=Vector2.ZERO,light_pass:bool=false) -> bool:
	if not spell_visuals.has(kind):return false
	var clip:Dictionary=spell_visuals[kind].idle
	var info:Dictionary=clip.info
	if bool(info.get("additive",false))!=light_pass:return not light_pass
	var painter:Node2D=spell_light_layer if light_pass else self
	var rotated:bool=info.get("rotate_to_velocity",false) and velocity!=Vector2.ZERO
	var row:int=int(info.get("forward_row",0)) if rotated else (direction if info.frames_per_direction.size()==8 else 0)
	var count:int=info.frames_per_direction[row]
	var frame:int=int(age/float(info.frame_seconds))
	frame=posmod(frame,count) if info.get("loop",true) else mini(frame,count-1)
	var columns:int=int(info.get("frame_columns",count))
	var rows:int=ceili(float(count)/columns)
	var size:=Vector2(info.frame_width,info.frame_height)
	var anchor:Array=info.get("anchor",[size.x/2,size.y/2])
	if rotated:painter.draw_set_transform(point,velocity.angle())
	painter.draw_texture_rect_region(clip.texture,Rect2((Vector2.ZERO if rotated else point)-Vector2(anchor[0],anchor[1]),size),Rect2(Vector2(frame%columns,row*rows+frame/columns)*size,size),Color(1,1,1,opacity))
	if rotated:painter.draw_set_transform(Vector2.ZERO)
	return true

func ailment_tint(target:Dictionary) -> Color:
	var effects:Dictionary=target.get("ailments",{})
	if effects.is_empty():return Color.WHITE
	return Color.WHITE.lerp(Ailments.COLORS[effects.keys()[0]],0.28)

func draw_formation_warning() -> void:
	var warning:Dictionary=model.formation_director.pending
	if warning.is_empty():return
	var center:Vector2=screen(model.nearest_position(warning.center,model.player))
	var color:=Color(1,0.65,0.3,0.25+0.15*sin(model.elapsed*7))
	if warning.shape in ["circle","square","diamond"]:
		var radius:float=300+float(warning.count-12)*9
		if warning.shape=="circle":draw_arc(center,radius,warning.angle+0.35,warning.angle+TAU-0.35,48,color,2,true)
		else:
			var points:=PackedVector2Array()
			for i in range(5):points.append(center+Vector2.from_angle(PI/4+TAU*float(i)/4+(PI/4 if warning.shape=="diamond" else 0))*radius*1.414)
			draw_polyline(points,color,2,true)
	else:
		var incoming:Vector2=center+Vector2(0,-280).rotated(warning.angle)
		draw_arc(incoming,25,0,TAU,20,color,3,true)
	if warning.elite:
		draw_arc(center,36,0,TAU,24,Color(1,0.25,0.2,0.8),3,true)
		draw_line(center-Vector2(12,0),center+Vector2(12,0),color,2)
		draw_line(center-Vector2(0,12),center+Vector2(0,12),color,2)

func draw_spell_lights() -> void:
	if model==null:return
	for shot in model.projectiles:
		if float(shot.get("release_delay",0))>0 or shot.get("spell","")=="firestorm":continue
		var point:Vector2=screen(shot.position)+Vector2(shot.get("visual_offset",Vector2(0,-28)))
		draw_spell_sprite(str(shot.get("spell","")),point,model.direction_index(shot.velocity),shot.age,1.0,shot.velocity,true)

func enemy_spell_color(kind:String) -> Color:
	return {"fire":Color("ff7b29"),"lightning":Color("65caff"),"acid":Color("8cff43"),"ice":Color("a6f3ff"),"spell":Color("c778ff")}.get(kind,Color("c778ff"))
func powerup_screen(powerup:Dictionary) -> Vector2:
	var phase:float={"healing":0.0,"haste":2.1,"magnet":4.2,"vacuum":6.3}[powerup.kind]
	return screen(powerup.position)+Vector2(0,sin(model.elapsed*2.2+phase)*3.0)
func draw_powerup(powerup:Dictionary) -> void:
	if not powerup.active:return
	var point:=powerup_screen(powerup);var color:=powerup_color(powerup.kind)
	var pulse:float=0.75+sin(model.elapsed*4)*0.25
	var border:=Rect2(point-Vector2(16,16),Vector2(32,32))
	# Layer translucent strokes around the square for a renderer-independent glow.
	for layer in [{"width":16.0,"alpha":0.035},{"width":10.0,"alpha":0.075},{"width":6.0,"alpha":0.18}]:
		draw_rect(border,Color(color,float(layer.alpha)*pulse),false,float(layer.width),true)
	draw_rect(border,Color(color,0.9),false,3,true)
	draw_rect(border,color.lerp(Color.WHITE,0.65),false,1,true)
	var icon:Texture2D=pickup_icons.get(powerup.kind)
	if icon!=null:draw_texture_rect(icon,Rect2(point-Vector2(14,14),Vector2(28,28)),false)
	else:draw_circle(point,8,color)
func goblin_minimap_marker() -> Dictionary:
	var goblin:Dictionary={}
	for enemy in model.enemies:
		if enemy.get("kind","")!="goblin" or enemy.health<=0:continue
		if goblin.is_empty() or int(enemy.id)<int(goblin.id):goblin=enemy
	if goblin.is_empty():return {}
	# Resolve exactly one wrapped position for the single goblin indicator.
	var offset:Vector2=model.nearest_position(goblin.position,model.player)-model.player
	return {"id":goblin.id,"offset":(offset/450.0*78.0).limit_length(70.0)}

func draw_minimap() -> void:
	if model.state in ["classes","shop","achievements","reset_confirm","settings","dead","victory","cow_complete"] or not model.config.get("powerups_enabled",false):return
	var center:=Vector2(1138,172);var radius:=78.0;var reach:=450.0
	draw_circle(center,radius+5,Color(0.02,0.03,0.05,0.85));draw_arc(center,radius+5,0,TAU,48,Color("64748c"),1)
	if model.navigation!=null:
		var cell:int=model.navigation.index_at(model.player)
		var width:int=model.navigation.width
		for y in range(maxi(0,int(cell/width)-15),mini(model.navigation.height,int(cell/width)+16)):
			for x in range(maxi(0,cell%width-15),mini(width,cell%width+16)):
				var index:int=y*width+x
				var offset:Vector2=model.navigation.world(index)-model.player
				if offset.length()<=reach and int(model.navigation.cells[index])!=0:draw_circle(center+offset/reach*radius,1,Color("495363"))
	for powerup in model.powerups:
		if powerup.active and powerup.position.distance_to(model.player)<=reach:
			var point:Vector2=center+(powerup.position-model.player)/reach*radius
			draw_circle(point,5,Color(powerup_color(powerup.kind),0.2));draw_circle(point,3,powerup_color(powerup.kind))
	var goblin_marker:Dictionary=goblin_minimap_marker()
	if not goblin_marker.is_empty():
		var point:Vector2=center+goblin_marker.offset
		var star:=PackedVector2Array()
		for index in range(10):star.append(point+Vector2.from_angle(-PI/2+index*PI/5)*(7 if index%2==0 else 3))
		draw_circle(point,11,Color(1,0.8,0.1,0.2));draw_colored_polygon(star,Color("ffdc43"))
	draw_circle(center,3,Color.WHITE)
	draw_string(game_font,center+Vector2(-63,103),"Nearby collectibles",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("cbd3e3"))

func draw_attack_cooldown() -> void:
	if model.state not in ["playing","paused","upgrade","character"]:return
	var progress_value:float=clampf(1-model.attack_clock/maxf(0.01,model.attack_cycle_interval),0,1)
	var ready:bool=model.attack_clock<=0
	var color:=Color("ffd078") if ready else Color("d18a42")
	var bar:=Rect2(480,644,320,12)
	draw_style_box(panel_style(),Rect2(465,619,350,51))
	draw_rect(bar,Color("241b14"))
	if progress_value>0:draw_rect(Rect2(bar.position,Vector2(bar.size.x*progress_value,bar.size.y)),color)
	draw_rect(bar,Color("b88c55"),false,1)
	var tip:=Vector2(bar.position.x+bar.size.x*progress_value,650)
	draw_circle(tip,8,Color(1,0.7,0.3,0.12))
	draw_line(tip-Vector2(0,6),tip+Vector2(0,6),Color("fff0bd"),2)
	if attack_ready_flash>0:draw_rect(bar.grow(3),Color(1,0.8,0.4,attack_ready_flash*2),false,2)
	var text:="ATTACK READY" if ready else "NEXT ATTACK  %.1fs" % model.attack_clock
	if not auto_attack_enabled:text="CLICK TO ATTACK" if ready else "MANUAL ATTACK  %.1fs" % model.attack_clock
	draw_string(game_font,Vector2(480,637),text,HORIZONTAL_ALIGNMENT_CENTER,320,14,Color("ffe0a6"))

func _draw() -> void:
	if spell_light_layer!=null:spell_light_layer.queue_redraw()
	if model==null:return
	draw_floor()
	draw_formation_warning()
	for patch in model.fire_patches:
		draw_spell_sprite("firestorm",screen(patch.position),0,patch.age,clampf((float(patch.lifetime)-float(patch.age))/0.17,0,1))
	for corpse in model.corpses:
		if corpse.get("kind","")=="goblin":draw_goblin(corpse.position,corpse.facing,corpse.age,Color(1,1,1,maxf(0,1-corpse.age*2)))
		elif corpse.get("kind","")=="cow":draw_cow(corpse.position,corpse.facing,0,Color(1,1,1,maxf(0,1-corpse.age*2)))
		else:draw_actor(corpse.get("kind","enemy") if visuals.has(corpse.get("kind","")) else "enemy","death",corpse.position,corpse.facing,corpse.age,Color(1,1,1,clampf(float(corpse.get("lifetime",4.0))-corpse.age,0,1)))
	var scenery:Array=visible_town_pieces() if not town.is_empty() else []
	var scenery_index:=0
	var actors:Array=[]
	for prop in area_scenery:
		var point:=screen(prop.position)
		if point.x > -250 and point.x < 1530 and point.y > -100 and point.y < 1120:actors.append({"kind":"scenery","position":prop.position,"data":prop.data})
	for powerup in model.powerups:
		if powerup.active:actors.append({"kind":"powerup","position":powerup.position,"data":powerup})
	for particle in impact_particles:
		if particle.death:actors.append({"kind":"impact","position":particle.position,"data":particle})
	for enemy in model.enemies:
		if enemy.health>0:actors.append({"kind":"enemy","position":enemy.position,"data":enemy})
	actors.append({"kind":"player","position":model.player})
	actors.sort_custom(func(a,b):return screen(a.position).y<screen(b.position).y if not area_scenery.is_empty() else a.position.y<b.position.y)
	for item in actors:
		while scenery_index<scenery.size() and scenery[scenery_index].position.y<=item.position.y:
			draw_town_piece(scenery[scenery_index],true);scenery_index+=1
		if item.kind=="scenery":draw_area_prop(item)
		elif item.kind=="powerup":draw_powerup(item.data)
		elif item.kind=="impact":draw_impact_effect(item.data)
		elif item.kind=="player":
			draw_circle(screen(model.player),12,Color(0.35,0.9,0.8,0.14))
			draw_actor("player",player_state,model.player,facing,player_age,Color("ffb3b3") if model.invulnerability>0 else ailment_tint(model.player_conditions),1.0,player_walk_reverse)
			if model.player_conditions.ailments.has("fire"):
				for patch in range(4):
					var spot:Vector2=screen(model.player)+Vector2(sin(float(patch)*2.7+model.elapsed)*8,-15-float(patch)*9)
					draw_circle(spot,2.2,Color(1,0.18,0.04,0.7))
		else:
			var enemy:Dictionary=item.data
			var position:=screen(enemy.position)
			if position.x < -160 or position.x > 1440 or position.y < -160 or position.y > 880:continue
			var hit_strength:float=clampf(float(enemy.hit)/0.16,0,1)
			var draw_position:Vector2=enemy.position+Vector2(sin((0.16-float(enemy.hit))*110)*3.0,cos((0.16-float(enemy.hit))*90)*1.5)*hit_strength
			var tint:Color=Color("ff6464") if enemy.hit>0 else Ailments.COLORS.get(enemy.get("element",""),Color("ffdc89") if enemy.elite else ailment_tint(enemy))
			if enemy.get("kind","")=="goblin":draw_goblin(draw_position,enemy.facing,enemy.age,tint);continue
			if enemy.get("kind","")=="cow":draw_cow(draw_position,enemy.facing,enemy.age,tint);continue
			draw_actor(enemy.get("kind","enemy") if visuals.has(enemy.get("kind","")) else "enemy","hit" if enemy.hit>0 else "attack" if enemy.get("attack_age",0)>0 else "walk",draw_position,enemy.facing,0.35-float(enemy.attack_age) if enemy.get("attack_age",0)>0 else enemy.age,tint,1.6 if enemy.get("miniboss",false) else 1.3 if enemy.elite else 1.0)
	while scenery_index<scenery.size():
		draw_town_piece(scenery[scenery_index],true);scenery_index+=1
	if not model.portal.is_empty():
		var point:=screen(model.portal.position)
		draw_circle(point,30,Color(0.1,0.4,0.9,0.5));draw_arc(point,32,model.elapsed*2,model.elapsed*2+TAU*0.8,28,Color("74e5ff"),4)
		draw_string(game_font,point+Vector2(-55,-44),"E: cow portal",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("baf5ff"))
	if notice_clock>0:
		var notice_y:float=challenge_label.position.y+(challenge_label.size.y if challenge_label.visible else 0)+26
		draw_string(game_font,Vector2(28,notice_y),event_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffdf88"))
	for ally in model.allies:
		if selected_class=="necromancer" and visuals.has("skeleton"):
			var attacking:bool=float(ally.get("attack_age",10.0))<0.3
			var state:String="attack" if attacking else "walk" if ally.get("moving",false) else "idle"
			var direction:int=model.direction_index(ally.get("look_direction",Vector2.DOWN))
			draw_actor("skeleton",state,ally.position,direction,float(ally.attack_age) if attacking else ally.age,Color.WHITE,1.0,false,true)
		else:
			var index:int=model.allies.find(ally)
			var pulse:float=0.5+0.5*sin(ally.age*4+index*PI)
			var point:Vector2=ally.position-camera+Vector2(640,360)+Vector2(0,-9+sin(ally.age*3+index*PI)*2)
			for layer in [{"radius":18.0,"alpha":0.035},{"radius":12.0,"alpha":0.09},{"radius":7.0,"alpha":0.22}]:
				draw_circle(point,float(layer.radius)*(0.9+0.15*pulse),Color(1,0.36,0.06,float(layer.alpha)))
			draw_circle(point,3+1.2*pulse,Color("ffbe72"))
	for particle in impact_particles:
		if not particle.death:draw_impact_effect(particle)
	for pickup in model.pickups:
		var point:=screen(pickup.position)
		if int(pickup.get("gold",0))>0:
			var pulse:float=0.7+0.3*sin(model.elapsed*4)
			draw_circle(point,30,Color(1,0.65,0.1,0.12*pulse));draw_circle(point,19,Color(1,0.85,0.25,0.2*pulse))
			for coin in range(7):
				var coin_point:Vector2=point+Vector2((coin%3-1)*7,-(coin/3)*5)
				draw_circle(coin_point,5,Color("bd730d"));draw_circle(coin_point+Vector2(0,-2),4,Color("ffdb64"))
			draw_string(game_font,point+Vector2(-47,-32),"TREASURE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffe79c"))
			continue
		var color:=Color("ffdc73") if pickup.get("gold",0)>0 else Color("6ce8f0") if pickup.xp>0 else Color("f06683")
		draw_circle(point,10,Color(color,0.16))
		if pickup.get("magnet_pull",false):
			var heading:Vector2=(model.player-pickup.position).normalized()
			draw_line(point-heading*15,point,Color(0.65,0.5,1,0.55),3,true)
		draw_circle(point,7 if pickup.get("gold",0)>0 else 5,color)
		draw_arc(point,5,0,TAU,16,color.lerp(Color.WHITE,0.6),1,true)
	for shot in model.enemy_projectiles:
		var point:=screen(shot.position)
		if shot.missile=="arrow":draw_line(point-shot.velocity.normalized()*14,point,Color("f2b58e"),3)
		elif shot.missile=="quill":draw_line(point-shot.velocity.normalized()*9,point,Color("e1ca9d"),2)
		elif shot.missile=="lightning":
			var forward:Vector2=shot.velocity.normalized();var side:=forward.orthogonal()
			var zigzag:=PackedVector2Array([point-forward*22,point-forward*15+side*5,point-forward*9-side*4,point])
			draw_polyline(zigzag,Color(0.2,0.6,1,0.2),8,true);draw_polyline(zigzag,Color("bbedff"),2,true)
		else:
			var forward:Vector2=shot.velocity.normalized();var side:=forward.orthogonal();var color:=enemy_spell_color(shot.missile)
			draw_circle(point,10,Color(color,0.1))
			draw_colored_polygon(PackedVector2Array([point+forward*6,point+side*4,point-forward*12,point-side*4]),color)
			draw_line(point-forward*3,point+forward*4,color.lerp(Color.WHITE,0.8),2,true)
	for shot in model.projectiles:
		if float(shot.get("release_delay",0))>0 or shot.get("spell","")=="firestorm":continue
		var point:Vector2=screen(shot.position)+Vector2(shot.get("visual_offset",Vector2(0,-28)))
		if draw_spell_sprite(str(shot.get("spell","firebolt" if shot.weapon=="firebolt" else "")),point,model.direction_index(shot.velocity),shot.age,1.0,shot.velocity):continue
		if shot.weapon=="bow":draw_line(point-shot.velocity.normalized()*18,point,Color("efdc98"),3)
		else:draw_circle(point,7,Color("cce5d5") if selected_class=="necromancer" else Color("ff8c43"));draw_circle(point,3,Color("fff1a0"))
	for swing in swings:
		if model.config.get("weapon","sword")!="sword":continue
		var angle:float=swing.direction.angle()
		draw_arc(screen(swing.position),float(model.stats.attack_range)*float(model.stats.area_scale),angle-minf(PI,0.9*float(model.stats.area_scale)),angle+minf(PI,0.9*float(model.stats.area_scale)),18,Color(1,0.86,0.55,1-swing.age/0.2),3)
	draw_minimap()
	for label in damage_labels:
		var point:Vector2=screen(label.position)+Vector2(-8,-60-label.age*50)
		var critical:bool=label.get("critical",false)
		var color:=Color("ff6666") if critical else Color("ffe8a6")
		color.a=1-label.age/0.7
		draw_string(game_font,point,str(int(label.amount)),HORIZONTAL_ALIGNMENT_LEFT,-1,24 if critical else 19,color)
		if critical:draw_string(game_font,point+Vector2(-12,-24),"CRIT",HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
	draw_attack_cooldown()

func show_reset_confirmation() -> void:
	model.state="reset_confirm";ui_state="";update_ui()
func reset_progress() -> void:
	if model.state!="reset_confirm":return
	var fresh:Dictionary=Classes.migrate({})
	fresh["area_order"]=manifest.get("area_order",Classes.AREA_ORDER).duplicate()
	fresh["available_classes"]=playable_classes().duplicate()
	fresh["last_played"]={"character":manifest.get("default_class","warrior"),"area":manifest.get("default_arena","cathedral"),"difficulty":"easy"}
	if not write_progress(fresh):
		push_warning("Could not reset progress; your existing profile was kept.")
		return
	selected_class=manifest.get("default_class","warrior");selected_arena=manifest.get("default_arena","cathedral");selected_difficulty="easy"
	visuals.player=load_visual(manifest.get("class_visuals",{}).get(selected_class,manifest.player_visual))
	apply_arena(selected_arena);restart();show_classes()

func select_difficulty(difficulty:String) -> void:
	if not Classes.difficulty_unlocked(progress,selected_arena,difficulty):return
	selected_difficulty=difficulty;ui_state="";update_ui()

func playable_classes() -> Array:
	return manifest.get("available_classes",Classes.CLASSES)
func class_title(key:String) -> String:
	return str(manifest.get("class_names",{}).get(key,key.capitalize()))
func shop_class(key:String) -> String:
	if manifest.get("game_id","")!="diablo2":return key
	return {"warrior":"barbarian","rogue":"amazon","sorcerer":"sorceress"}.get(key,key)
