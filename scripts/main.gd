extends Node2D
## Builds the level from LevelData.MAP, spawns everything, and runs the game flow.

const TILE := 32
const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const WormScript := preload("res://scripts/bookworm.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const InklingScript := preload("res://scripts/inkling.gd")
const InkwellScript := preload("res://scripts/inkwell.gd")
const BossScript := preload("res://scripts/boss.gd")
const SpikesScript := preload("res://scripts/spikes.gd")
const CheckpointScript := preload("res://scripts/checkpoint.gd")
const LevelArtScript := preload("res://scripts/level_art.gd")
const HudScript := preload("res://scripts/hud.gd")
const D := preload("res://scripts/difficulty.gd")

# Survive scene reloads so "retry" resumes from the last checkpoint.
static var resume_checkpoint = null
static var resume_collected := {}
static var resume_wells := {}

var grid: Array = []
var cols := 0
var rows := 0
var world: Node2D
var level_art
var player
var boss
var hud
var gate_shape: CollisionShape2D
var gate_x := 0
var arena_trigger_x := INF
var checkpoint_pos := Vector2.ZERO
var books_total := 0
var books_collected := 0
var collected := {}
var well_ink := {}
var state := "intro"   # intro, play, boss, won, lost


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()
	_parse_map()
	_build_world()

	hud = HudScript.new()
	add_child(hud)
	hud.set_hearts(player.hp, player.max_hp)
	hud.set_books(books_collected, books_total)
	hud.set_ink(player.ink, player.max_ink)

	world.process_mode = Node.PROCESS_MODE_DISABLED
	if resume_checkpoint != null:
		hud.show_message("TRY AGAIN!", "Back at your last checkpoint.\n\nPress Space to continue")
	else:
		_show_title()


func _show_title() -> void:
	var picks := []
	for m in D.MODES:
		picks.append(("[ %s ]" if m == D.mode else "  %s  ") % m.to_upper())
	var blurb: String = {
		"easy": "%d hearts, slower enemies, weaker bosses. Great for learning!",
		"normal": "%d hearts. A real challenge.",
		"hard": "%d hearts, fast tough enemies, huge bosses. Good luck!",
	}[D.mode] % D.PLAYER_MAX_HP
	hud.show_message("THE EVIL BOOK STEALER",
		"A hooded thief has stolen every book from the Grand Library!\n" +
		"Recover the books, then chase him down and defeat him.\n\n" +
		"Move: Arrows / WASD     Jump: Space / W / Z     Throw ink: J / X\n" +
		"Stomp enemies by jumping on them!\n\n" +
		"Difficulty  (Left / Right):   %s\n%s\n\n" % ["   ".join(picks), blurb] +
		"Press Space to begin     (or press 2 - 5 to skip to that level)")


func _process(_delta: float) -> void:
	match state:
		"intro":
			if resume_checkpoint == null:
				var step := 0
				if Input.is_action_just_pressed("move_left"):
					step = -1
				elif Input.is_action_just_pressed("move_right"):
					step = 1
				if step != 0 and D.MODES.find(D.mode) + step in range(D.MODES.size()):
					D.cycle(step)
					get_tree().reload_current_scene()   # rebuild the level with the new settings
					return
			if resume_checkpoint == null and Input.is_physical_key_pressed(KEY_2):
				get_tree().change_scene_to_file("res://chase.tscn")   # skip straight to Level 2
				return
			if resume_checkpoint == null and Input.is_physical_key_pressed(KEY_3):
				get_tree().change_scene_to_file("res://hack.tscn")    # skip straight to Level 3
				return
			if resume_checkpoint == null and Input.is_physical_key_pressed(KEY_4):
				get_tree().change_scene_to_file("res://time.tscn")    # skip straight to Level 4
				return
			if resume_checkpoint == null and Input.is_physical_key_pressed(KEY_5):
				get_tree().change_scene_to_file("res://future.tscn")  # skip straight to Level 5
				return
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
				state = "play"
				hud.hide_message()
				world.process_mode = Node.PROCESS_MODE_INHERIT
		"won", "lost":
			if hud.message_visible() and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_accept")):
				if state == "won":
					resume_checkpoint = null
					resume_collected = {}
					resume_wells = {}
					get_tree().change_scene_to_file("res://chase.tscn")   # on to Level 2!
					return
				get_tree().reload_current_scene()
		_:
			if Input.is_action_just_pressed("restart"):
				resume_checkpoint = null
				resume_collected = {}
				resume_wells = {}
				get_tree().reload_current_scene()
				return
			if state == "play" and player.global_position.x > arena_trigger_x:
				_start_boss_fight()
			if player.alive and player.global_position.y > rows * TILE + 48:
				_player_fell()


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], -1.0)
	_add_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], 1.0)
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP, KEY_Z], [JOY_BUTTON_A])
	_add_action("shoot", [KEY_J, KEY_X, KEY_K], [JOY_BUTTON_X, JOY_BUTTON_B])
	_add_action("restart", [KEY_R], [JOY_BUTTON_START])


func _add_action(action: String, keys: Array, buttons: Array, axis_dir := 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	if axis_dir != 0.0:
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_LEFT_X
		m.axis_value = axis_dir
		InputMap.action_add_event(action, m)


# ---------------------------------------------------------------- level building

func _parse_map() -> void:
	var data: Array = LevelData.MAP
	rows = data.size()
	for line in data:
		cols = max(cols, line.length())
	for y in rows:
		var line: String = data[y]
		var row := []
		for x in cols:
			row.append(line[x] if x < line.length() else " ")
		grid.append(row)


func _build_world() -> void:
	world = Node2D.new()
	add_child(world)

	level_art = LevelArtScript.new()
	level_art.setup(grid, TILE)
	world.add_child(level_art)

	var solids := StaticBody2D.new()
	solids.collision_layer = 1
	solids.collision_mask = 0
	world.add_child(solids)

	# Merge horizontal runs of tiles into single collision rectangles.
	for y in rows:
		var x := 0
		while x < cols:
			var c: String = grid[y][x]
			if c == "#" or c == "=":
				var start := x
				while x < cols and grid[y][x] == c:
					x += 1
				var w := x - start
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				if c == "#":
					rs.size = Vector2(w * TILE, TILE)
					cs.position = Vector2((start + w / 2.0) * TILE, (y + 0.5) * TILE)
				else:
					rs.size = Vector2(w * TILE, 10)
					cs.position = Vector2((start + w / 2.0) * TILE, y * TILE + 5)
					cs.one_way_collision = true
				cs.shape = rs
				solids.add_child(cs)
			else:
				x += 1

	var player_start := Vector2.ZERO
	var boss_start := Vector2.ZERO
	var gate_rows := []
	for y in rows:
		for x in cols:
			var c: String = grid[y][x]
			var center := Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			var bottom := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match c:
				"P":
					player_start = bottom
				"B", "H", "N", "M", "X":
					var cell := Vector2i(x, y)
					if c == "B":
						books_total += 1
					if resume_collected.has(cell):
						collected[cell] = true
						if c == "B":
							books_collected += 1
						continue
					var p = PickupScript.new()
					p.kind = "book" if c == "B" else ("heart" if c == "H" else ("ink" if c == "N" else ("star" if c == "X" else "big")))
					p.cell = cell
					p.position = center
					world.add_child(p)
				"W":
					var w = WormScript.new()
					w.position = bottom - Vector2(0, 10)
					world.add_child(w)
				"K":
					var iw = InkwellScript.new()
					iw.position = bottom
					iw.cell = Vector2i(x, y)
					iw.stored = resume_wells.get(iw.cell, InkwellScript.MAX_STORED)
					well_ink[iw.cell] = iw.stored
					world.add_child(iw)
				"I":
					var ik = InklingScript.new()
					ik.position = bottom - Vector2(0, 12)
					world.add_child(ik)
				"^":
					var s = SpikesScript.new()
					s.position = center
					world.add_child(s)
				"C":
					var cp = CheckpointScript.new()
					cp.position = bottom
					world.add_child(cp)
					if resume_checkpoint != null and resume_checkpoint.is_equal_approx(bottom):
						cp.activate(true)
				"G":
					gate_x = x
					gate_rows.append(y)
				"S":
					boss_start = bottom

	# Boss gate: open until the fight starts.
	if gate_rows.size() > 0:
		var gate_body := StaticBody2D.new()
		gate_body.collision_layer = 1
		gate_shape = CollisionShape2D.new()
		var gr := RectangleShape2D.new()
		gr.size = Vector2(TILE, gate_rows.size() * TILE)
		gate_shape.shape = gr
		gate_shape.position = Vector2((gate_x + 0.5) * TILE, (gate_rows.min() + gate_rows.size() / 2.0) * TILE)
		gate_shape.disabled = true
		gate_body.add_child(gate_shape)
		world.add_child(gate_body)
		arena_trigger_x = (gate_x + 3) * TILE

	checkpoint_pos = player_start
	if resume_checkpoint != null:
		checkpoint_pos = resume_checkpoint

	player = PlayerScript.new()
	player.position = checkpoint_pos - Vector2(0, 16)
	world.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = cols * TILE
	player.camera.limit_bottom = rows * TILE
	player.camera.reset_smoothing()

	boss = BossScript.new()
	boss.position = boss_start - Vector2(0, 32)
	world.add_child(boss)


# ---------------------------------------------------------------- game events

func _start_boss_fight() -> void:
	state = "boss"
	gate_shape.set_deferred("disabled", false)
	level_art.gate_closed = true
	level_art.queue_redraw()
	player.camera.limit_left = gate_x * TILE
	shake(8)
	hud.banner("THE EVIL BOOK STEALER!", Color(0.85, 0.5, 1.0))
	hud.show_boss_bar(boss.hp, boss.max_hp)
	boss.activate(player)


func _player_fell() -> void:
	player.take_damage(1, null, true)
	if player.alive:
		player.respawn(checkpoint_pos - Vector2(0, 16))


func on_player_hurt(hp: int) -> void:
	hud.set_hearts(hp, player.max_hp)
	shake(6)


func on_player_healed(hp: int) -> void:
	hud.set_hearts(hp, player.max_hp)


func on_player_died() -> void:
	if state == "won":
		return
	state = "lost"
	resume_checkpoint = checkpoint_pos
	resume_collected = collected.duplicate()
	resume_wells = well_ink.duplicate()
	await get_tree().create_timer(1.6).timeout
	hud.show_message("OH NO!", "The Book Stealer cackles and runs off with the books...\n\nPress R or Enter to retry from your last checkpoint")


func collect_pickup(pickup) -> void:
	if pickup.kind != "big":   # the mushroom comes back after a retry, since big is lost on death
		collected[pickup.cell] = true
	if pickup.kind == "book":
		books_collected += 1
		hud.set_books(books_collected, books_total)
		burst(pickup.global_position, Color(1.0, 0.85, 0.3), 14, 160)
	elif pickup.kind == "big":
		player.grow()
		burst(pickup.global_position, Color(0.8, 0.5, 1.0), 18, 180)
		hud.banner("BIG!", Color(0.85, 0.6, 1.0))
	elif pickup.kind == "ink":
		player.add_ink(5)
		burst(pickup.global_position, Color(0.3, 0.4, 1.0), 14, 160)
		hud.banner("+5 Ink!", Color(0.55, 0.65, 1.0))
	elif pickup.kind == "star":
		player.start_invincible()
		burst(pickup.global_position, Color(1.0, 0.85, 0.2), 22, 220)
		hud.banner("INVINCIBLE!", Color(1.0, 0.85, 0.2))
	else:
		player.heal(1)
		burst(pickup.global_position, Color(1.0, 0.35, 0.45), 14, 160)


func set_checkpoint(pos: Vector2) -> void:
	if checkpoint_pos.is_equal_approx(pos):
		return
	checkpoint_pos = pos
	hud.banner("Checkpoint!", Color(0.5, 1.0, 0.6))
	burst(pos - Vector2(0, 40), Color(0.5, 1.0, 0.6), 16, 140)


func on_boss_hurt(hp: int, max_hp: int) -> void:
	hud.set_boss_hp(hp, max_hp)
	shake(3)


func on_boss_defeated(pos: Vector2) -> void:
	state = "won"
	player.invuln = 999.0
	hud.hide_boss_bar()
	shake(16)
	for i in 6:
		burst(pos + Vector2(randf_range(-30, 30), randf_range(-40, 10)),
			Color.from_hsv(randf(), 0.7, 1.0), 16, 260)
	hud.banner("The books are free!", Color(1.0, 0.85, 0.3))
	gate_shape.set_deferred("disabled", true)
	level_art.gate_closed = false
	level_art.queue_redraw()
	resume_checkpoint = null
	resume_collected = {}
	resume_wells = {}
	await get_tree().create_timer(2.5).timeout
	hud.show_message("LEVEL 1 COMPLETE!",
		"You knocked the Evil Book Stealer out the library window!\n" +
		"But he landed on his feet and ran off with one last sack of books...\n\n" +
		"Books you rescued along the way: %d / %d\n\n" % [books_collected, books_total] +
		"Press Enter to grab your skateboard and chase him!")


# ---------------------------------------------------------------- effects

func shake(amount: float) -> void:
	if player:
		player.shake = max(player.shake, amount)


func burst(pos: Vector2, color: Color, amount := 12, speed := 150.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = color
	p.z_index = 20
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
