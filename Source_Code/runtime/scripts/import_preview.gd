extends Node2D
# Generic local resource validation scene. No source-game identifiers or assets.
var sheet: ImageTexture
var atlas: ImageTexture
var actor: Dictionary
var terrain: Dictionary
var player := Vector2(640,390)
var elapsed := 0.0
var facing := 0
var clips := {}
var playing := "walk"
var animation_time := 0.0
var ticks := 0
var smoke := false

func fail(message: String) -> void:
    set_process(false)
    push_error(message)
    get_tree().quit(1)

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    smoke = args.has("--smoke-test")
    var index := args.find("--preview-manifest")
    if index < 0 or index+1 >= args.size():
        fail("Missing resource preview manifest")
        return
    var file := FileAccess.open(args[index+1],FileAccess.READ)
    if file == null:
        fail("Cannot read preview manifest")
        return
    var document = JSON.parse_string(file.get_as_text())
    if not document is Dictionary or document.get("schema_version") != 1:
        fail("Invalid preview manifest")
        return
    actor = document.get("actor",{})
    terrain = document.get("terrain",{})
    var actor_image := Image.load_from_file(actor.get("sheet",""))
    var terrain_image := Image.load_from_file(terrain.get("atlas",""))
    if actor_image == null or terrain_image == null or actor_image.is_empty() or terrain_image.is_empty():
        fail("Imported PNG resources could not be loaded")
        return
    var counts: Array = actor.get("frames_per_direction",[])
    if counts.size() != 8 or actor.get("frame_width",0) <= 0 or actor.get("frame_height",0) <= 0:
        fail("Invalid actor direction/frame metadata")
        return
    for count in counts:
        if count <= 0 or count*actor.frame_width > actor_image.get_width():
            fail("Sprite frames exceed texture bounds")
            return
    if actor.frame_height*8 > actor_image.get_height() or actor.get("preview_frame_seconds",0) <= 0:
        fail("Invalid sprite rows or timing")
        return
    if terrain.get("columns",0) <= 0 or terrain.get("cell_width",0) != 128 or terrain.get("cell_height",0) < 64 or terrain.get("tile_index",-1) < 0:
        fail("Invalid preview terrain geometry")
        return
    var tile_index: int = terrain.tile_index
    if (tile_index%int(terrain.columns)+1)*terrain.cell_width > terrain_image.get_width() or (tile_index/int(terrain.columns)+1)*terrain.cell_height > terrain_image.get_height():
        fail("Terrain tile exceeds texture bounds")
        return
    sheet = ImageTexture.create_from_image(actor_image)
    atlas = ImageTexture.create_from_image(terrain_image)
    clips["walk"] = {"texture": sheet, "metadata": actor}
    for state in actor.get("clips", {}):
        var info: Dictionary = actor.clips[state]
        var image := Image.load_from_file(info.get("sheet", ""))
        if image == null or image.is_empty() or info.get("frames_per_direction", []).size() != 8 or info.get("frame_width", 0) <= 0 or info.get("frame_height", 0) <= 0 or info.get("preview_frame_seconds", 0) <= 0:
            fail("Invalid additional animation clip")
            return
        for count in info.frames_per_direction:
            if count <= 0 or count * info.frame_width > image.get_width() or info.frame_height * 8 > image.get_height():
                fail("Additional clip exceeds texture bounds")
                return
        clips[state] = {"texture": ImageTexture.create_from_image(image), "metadata": info}

func _process(delta: float) -> void:
    elapsed += delta
    ticks += 1
    var direction := Vector2.ZERO
    direction.x = float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
    direction.y = float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
    if smoke: direction=Vector2(1,0)
    if direction != Vector2.ZERO:
        facing = (int(round((direction.angle()-PI/2)/ (PI/4)))+8)%8
        player += direction.normalized()*150*delta
        player = player.clamp(Vector2(200,230),Vector2(1080,580))
    var desired := "walk" if direction != Vector2.ZERO else "idle"
    if Input.is_physical_key_pressed(KEY_3): desired = "attack"
    if Input.is_physical_key_pressed(KEY_4): desired = "hit"
    if Input.is_physical_key_pressed(KEY_5): desired = "death"
    if not clips.has(desired): desired = "walk"
    if desired != playing:
        playing = desired
        animation_time = 0.0
    else:
        animation_time += delta
    if Input.is_physical_key_pressed(KEY_ESCAPE): get_tree().quit()
    queue_redraw()
    if smoke and ticks == 30:
        if player.x <= 640:
            fail("Imported actor movement failed")
        else:
            print("GAMESHIFT_IMPORT_PREVIEW_OK: external PNGs, frame bounds, eight directions, terrain bounds")
            get_tree().quit(0)

func _draw() -> void:
    if atlas == null or sheet == null: return
    var tile_index: int = terrain.tile_index
    var source := Rect2(tile_index%int(terrain.columns)*terrain.cell_width,tile_index/int(terrain.columns)*terrain.cell_height+terrain.cell_height-64,128,64)
    for y in range(6):
        for x in range(6):
            var position := Vector2(640+(x-y)*64,205+(x+y)*32)
            draw_texture_rect_region(atlas,Rect2(position-Vector2(64,32),Vector2(128,64)),source)
    var clip: Dictionary = clips.get(playing, {"texture": sheet, "metadata": actor})
    var info: Dictionary = clip.metadata
    var frame: int = int(animation_time/info.preview_frame_seconds)%int(info.frames_per_direction[facing])
    var rectangle := Rect2(frame*info.frame_width,facing*info.frame_height,info.frame_width,info.frame_height)
    draw_texture_rect_region(clip.texture,Rect2(player-Vector2(info.frame_width/2,info.frame_height),Vector2(info.frame_width,info.frame_height)),rectangle)
    draw_string(ThemeDB.fallback_font,Vector2(48,52),"IMPORTED ASSET DEMO / " + playing.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("72ddb9"))
    draw_string(ThemeDB.fallback_font,Vector2(48,690),"WASD move / Hold 3 attack, 4 hit, 5 death / ESC exit / No combat yet",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b2c3cc"))
