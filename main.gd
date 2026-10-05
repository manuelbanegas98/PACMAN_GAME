extends Node2D

const MAZE_SCRIPT = preload("res://maze.gd")
const PLAYER_SCRIPT = preload("res://player.gd")
const GHOST_SCRIPT = preload("res://ghost_ai.gd")
const HUD_SCRIPT = preload("res://game_hud.gd")
const AUDIO_SCRIPT = preload("res://audio_manager.gd")

var maze
var player
var ghost
var hud
var audio_manager
var score := 0
var lives := 3
var level := 1
var game_state := &"playing"
var death_timer := 0.0
var level_timer := 0.0
var banner_timer := 0.0
var power_timer := 0.0
var animation_clock := 0.0
var debug_visible := false
var particles: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	hud = HUD_SCRIPT.new()
	add_child(hud)
	audio_manager = AUDIO_SCRIPT.new()
	add_child(audio_manager)
	_setup_level(false)
	_update_hud()


func _process(delta: float) -> void:
	animation_clock += delta
	_update_particles(delta)
	if game_state == &"dying":
		death_timer -= delta
		if death_timer <= 0.0:
			if lives <= 0:
				game_state = &"game_over"
				hud.show_message("SIGNAL LOST\nPress SPACE to restart")
			else:
				player.reset_to(maze.player_start, maze)
				ghost.reset_ai(maze)
				game_state = &"playing"
				hud.show_message("")
		_update_hud()
		queue_redraw()
		return
	if game_state == &"level_clear":
		level_timer -= delta
		if level_timer <= 0.0:
			level += 1
			_setup_level(true)
		queue_redraw()
		return
	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - delta)
		if banner_timer == 0.0:
			hud.show_message("")
	if game_state != &"playing":
		queue_redraw()
		return

	var input_direction := _read_direction()
	if input_direction != Vector2i.ZERO:
		player.set_movement_input(input_direction)
	player.move_player(delta, maze)
	ghost.update_brain(delta, maze, player.tile, player.direction, level)
	if power_timer > 0.0:
		power_timer = maxf(0.0, power_timer - delta)
	if game_state == &"playing" and ghost.ai_state != &"RETURN" and player.position.distance_to(ghost.position) < 22.0:
		if ghost.ai_state == &"FRIGHTENED":
			ghost.catch_ghost()
			power_timer = 0.0
			score += 200
			audio_manager.play_effect(&"catch")
			_spawn_sparks(ghost.position, Color("9cf4ff"), 14)
		else:
			_lose_life()
	_update_hud()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		debug_visible = not debug_visible
		hud.set_debug_visible(debug_visible)
	elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
		if game_state == &"playing":
			game_state = &"paused"
			hud.show_message("PAUSED\nPress P or ESC to resume")
		elif game_state == &"paused":
			game_state = &"playing"
			hud.show_message("")
	elif event.keycode == KEY_SPACE:
		if game_state == &"game_over":
			score = 0
			lives = 3
			level = 1
			_setup_level(false)
		elif game_state == &"level_clear":
			level += 1
			_setup_level(true)


func _read_direction() -> Vector2i:
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		return Vector2i.UP
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		return Vector2i.RIGHT
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		return Vector2i.DOWN
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		return Vector2i.LEFT
	return Vector2i.ZERO


func _setup_level(new_level: bool) -> void:
	game_state = &"playing"
	power_timer = 0.0
	particles.clear()
	maze = MAZE_SCRIPT.new()
	maze.build(level)
	maze.collectible_collected.connect(_on_collectible_collected)
	if player == null:
		player = PLAYER_SCRIPT.new()
		add_child(player)
		player.tile_entered.connect(_on_player_tile_entered)
	player.setup(maze.player_start, maze)
	if ghost == null:
		ghost = GHOST_SCRIPT.new()
		add_child(ghost)
	ghost.setup(maze.ghost_home, maze)
	if new_level:
		hud.show_message("SECTOR %02d" % level)
		banner_timer = 1.1
	else:
		banner_timer = 0.0
		hud.show_message("")
	_update_hud()


func _on_player_tile_entered(cell: Vector2i) -> void:
	maze.collect_at(cell)


func _on_collectible_collected(kind: StringName, cell: Vector2i, duration: float) -> void:
	if kind == &"power":
		power_timer = duration
		ghost.trigger_frightened(duration)
		audio_manager.play_effect(&"power")
		_spawn_sparks(maze.cell_center(cell), Color("7ce8ff"), 20)
	else:
		score += 10
		audio_manager.play_effect(&"collect")
		_spawn_sparks(maze.cell_center(cell), Color("ffd166"), 5)
	if maze.collectibles.is_empty():
		game_state = &"level_clear"
		level_timer = 1.35
		hud.show_message("SECTOR CLEARED")
	_update_hud()


func _lose_life() -> void:
	if game_state != &"playing":
		return
	lives -= 1
	game_state = &"dying"
	death_timer = 0.82
	power_timer = 0.0
	player.direction = Vector2i.ZERO
	player.queued_direction = Vector2i.ZERO
	audio_manager.play_effect(&"hit")
	_spawn_sparks(player.position, Color("ff607d"), 18)
	hud.show_message("HULL BREACH")


func _update_hud() -> void:
	if hud == null or maze == null or ghost == null:
		return
	var target_name := "PLAYER"
	if ghost.ai_state == &"AMBUSH":
		target_name = "PREDICTED TILE"
	elif ghost.ai_state == &"SEARCH":
		target_name = "LAST SIGNAL"
	elif ghost.ai_state == &"FRIGHTENED":
		target_name = "ESCAPE ROUTE"
	elif ghost.ai_state == &"RETURN":
		target_name = "HOME BASE"
	hud.update_status(score, lives, level, maze.collectibles.size(), power_timer, ghost.ai_state, target_name, ghost.path_length(), ghost.prediction_tiles, 1.0 + float(level - 1) * 0.2)


func _spawn_sparks(at: Vector2, color: Color, count: int) -> void:
	for _index in range(count):
		var angle := randf() * TAU
		var speed := randf_range(24.0, 95.0)
		particles.append({"position": at, "velocity": Vector2(cos(angle), sin(angle)) * speed, "life": randf_range(0.22, 0.55), "color": color})


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle["position"] += particle["velocity"] * delta
		particle["life"] -= delta
		if particle["life"] <= 0.0:
			particles.remove_at(index)
		else:
			particles[index] = particle


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 600)), Color("07111d"))
	draw_rect(Rect2(Vector2(0, 0), Vector2(960, 82)), Color("0b1c2a"))
	draw_line(Vector2(24, 81), Vector2(936, 81), Color("1a596b"), 1.0)
	if maze != null:
		_draw_maze()
		_draw_collectibles()
		_draw_base()
		if player != null:
			_draw_player()
		if ghost != null:
			_draw_ghost()
	_draw_particles()


func _draw_maze() -> void:
	var board := Rect2(maze.origin, Vector2(maze.width, maze.height) * maze.tile_size)
	draw_rect(board.grow(5.0), Color("112c3c"))
	draw_rect(board, Color("091a28"))
	for y in range(maze.height):
		for x in range(maze.width):
			var cell := Vector2i(x, y)
			var rect := Rect2(maze.origin + Vector2(x, y) * maze.tile_size, Vector2.ONE * maze.tile_size)
			if not maze.is_open(cell):
				draw_rect(rect.grow(-1.0), Color("102c46"))
				draw_rect(rect.grow(-3.0), Color("0b2137"), false, 1.2, true)
			else:
				draw_rect(rect, Color(0.15, 0.42, 0.52, 0.08), false, 1.0)


func _draw_collectibles() -> void:
	for cell in maze.collectibles:
		var item = maze.collectibles[cell]
		var center: Vector2 = maze.cell_center(cell)
		if item.kind == &"power":
			var pulse := 1.0 + 0.14 * sin(animation_clock * 5.0)
			draw_circle(center, 9.0 * pulse, Color(0.26, 0.89, 1.0, 0.16))
			draw_circle(center, 5.0 * pulse, Color("a5f3ff"))
			draw_circle(center, 2.0, Color("ffffff"))
		else:
			draw_circle(center, 2.6, Color("ffd166"))
			draw_circle(center, 1.2, Color("fff1bd"))


func _draw_base() -> void:
	var center: Vector2 = maze.cell_center(maze.ghost_home)
	draw_circle(center, 48.0, Color(0.12, 0.57, 0.75, 0.08))
	draw_arc(center, 42.0, 0.0, TAU, 48, Color(0.22, 0.68, 0.84, 0.34), 1.2, true)


func _draw_player() -> void:
	var center: Vector2 = player.position
	if player.direction != Vector2i.ZERO:
		center.y -= absf(sin(animation_clock * 13.0)) * 1.4
	var radius := 12.5
	if game_state == &"dying":
		radius *= clampf(death_timer / 0.82, 0.0, 1.0)
	draw_circle(center + Vector2(0, 3), radius + 2.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center, radius, Color("43d9cf"))
	draw_arc(center, radius - 0.5, 0.0, TAU, 32, Color("b8fff4"), 1.5, true)
	var eye_offset := Vector2(3.4, -3.5)
	draw_circle(center + eye_offset, 2.2, Color("09212e"))
	if radius > 7.0:
		draw_circle(center + eye_offset + Vector2(0.7, -0.5), 0.7, Color("ffffff"))


func _draw_ghost() -> void:
	var center: Vector2 = ghost.position
	if ghost.ai_state == &"RETURN":
		draw_circle(center + Vector2(-4, -2), 4.2, Color("f5fbff"))
		draw_circle(center + Vector2(4, -2), 4.2, Color("f5fbff"))
		draw_circle(center + Vector2(-3, -1), 1.8, Color("3454a0"))
		draw_circle(center + Vector2(5, -1), 1.8, Color("3454a0"))
		return
	var frightened: bool = ghost.ai_state == &"FRIGHTENED"
	var body_color := Color("ff557d") if not frightened else Color("527ce8")
	if frightened and power_timer < 1.8 and int(animation_clock * 9.0) % 2 == 0:
		body_color = Color("f2f7ff")
	var body := PackedVector2Array([
		center + Vector2(-13, 10), center + Vector2(-13, -1), center + Vector2(-11, -9),
		center + Vector2(-5, -13), center + Vector2(5, -13), center + Vector2(11, -8),
		center + Vector2(13, 1), center + Vector2(13, 10), center + Vector2(7, 6),
		center + Vector2(1, 10), center + Vector2(-5, 6)
	])
	draw_colored_polygon(body, body_color)
	draw_circle(center + Vector2(-5, -2), 4.0, Color("f8fbff"))
	draw_circle(center + Vector2(5, -2), 4.0, Color("f8fbff"))
	var look := Vector2(1.0, 0.0) if not frightened else Vector2.ZERO
	draw_circle(center + Vector2(-5, -2) + look, 1.8, Color("172342"))
	draw_circle(center + Vector2(5, -2) + look, 1.8, Color("172342"))


func _draw_particles() -> void:
	for particle in particles:
		var color: Color = particle["color"]
		color.a = clampf(float(particle["life"]) * 2.2, 0.0, 1.0)
		draw_circle(particle["position"], 2.0, color)