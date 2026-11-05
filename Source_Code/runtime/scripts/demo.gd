extends Node2D

const HERO = preload("res://resources/hero.svg")
var player := Vector2(640, 390)
var arena := Rect2(72, 140, 1136, 508)
var elapsed := 0.0
var smoke := false
var ticks := 0
var speed := 240.0
var initial_position := Vector2.ZERO

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	smoke = args.has("--smoke-test")
	var manifest_path := "res://resources/demo_manifest.json"
	var manifest_index := args.find("--manifest")
	if manifest_index >= 0:
		if manifest_index + 1 >= args.size():
			fail("Missing manifest argument")
			return
		manifest_path = args[manifest_index + 1]
	var stream := FileAccess.open(manifest_path, FileAccess.READ)
	if stream == null:
		fail("Manifest could not be opened")
		return
	var document = JSON.parse_string(stream.get_as_text())
	if not document is Dictionary or document.get("schema_version") != 1 or document.get("game_id") != "original_demo":
		fail("Unsupported demo manifest")
		return
	var actors = document.get("actors", [])
	if not actors is Array or actors.is_empty() or not actors[0] is Dictionary:
		fail("Demo manifest has no actors")
		return
	speed = float(actors[0].get("speed", 240))
	if speed <= 0.0 or speed > 1000.0:
		fail("Invalid movement speed")
		return
	if smoke:
		player = arena.position + Vector2(24, 24)
	initial_position = player

func fail(message: String) -> void:
	set_process(false)
	push_error(message)
	get_tree().quit(1)

func _process(delta: float) -> void:
	elapsed += delta
	ticks += 1
	var direction := Vector2.ZERO
	if smoke:
		direction = Vector2(1, 1).normalized()
	else:
		direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		direction = direction.normalized()
		if Input.is_physical_key_pressed(KEY_ESCAPE):
			get_tree().quit()
	player += direction * speed * delta
	player.x = clampf(player.x, arena.position.x + 18, arena.end.x - 18)
	player.y = clampf(player.y, arena.position.y + 18, arena.end.y - 18)
	queue_redraw()
	if smoke and ticks >= 30:
		if not arena.has_point(player) or player.distance_to(initial_position) <= 0.0:
			fail("Movement smoke failed")
		else:
			print("GAMESHIFT_SMOKE_OK: manifest, movement, bounds, scene lifecycle")
			get_tree().quit(0)

func _draw() -> void:
	draw_rect(arena, Color("101e28"))
	for x in range(72, 1209, 40):
		draw_line(Vector2(x, 140), Vector2(x, 648), Color("1a2e3b"), 1)
	for y in range(140, 649, 40):
		draw_line(Vector2(72, y), Vector2(1208, y), Color("1a2e3b"), 1)
	draw_rect(arena, Color("335665"), false, 2)
	for prop in [Vector2(220, 260), Vector2(1020, 300), Vector2(380, 560), Vector2(920, 530)]:
		draw_circle(prop, 22, Color("203c48"))
		draw_arc(prop, 30, 0, TAU, 24, Color("315b67"), 2)
	draw_circle(player + Vector2(0, 18), 18, Color(0, 0, 0, 0.4))
	draw_texture_rect(HERO, Rect2(player - Vector2(24, 32), Vector2(48, 64)), false)
	for i in range(3):
		var orb := player + Vector2.from_angle(elapsed * 1.6 + i * TAU / 3.0) * 64
		draw_circle(orb, 10, Color(0.35, 0.85, 0.69, 0.12))
		draw_circle(orb, 4, Color("79ecc6"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(72, 58), "GAMESHIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("6edcbd"))
	draw_string(font, Vector2(72, 104), "The proving grounds", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("edf7fa"))
	draw_string(font, Vector2(72, 692), "WASD / arrows to move     •     ESC to exit     •     Original assets / M0 demo", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("94abb8"))
