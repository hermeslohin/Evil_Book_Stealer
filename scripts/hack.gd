extends Node2D
## Level 3: hack into the Evil Book Stealer's supercomputer and recover the stolen e-books.
## Builds the cyberspace level from HackData.MAP and runs the game flow.

const TILE := 32
const HackData := preload("res://scripts/hack_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const WormScript := preload("res://scripts/bookworm.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const InkwellScript := preload("res://scripts/inkwell.gd")
const CheckpointScript := preload("res://scripts/checkpoint.gd")
const TerminalScript := preload("res://scripts/terminal.gd")
const FirewallScript := preload("res://scripts/firewall.gd")
const LaserScript := preload("res://scripts/laser.gd")
const DroneScript := preload("res://scripts/drone.gd")
const CoreScript := preload("res://scripts/core.gd")
const HackArtScript := preload("res://scripts/hack_art.gd")
const HudScript := preload("res://scripts/hud.gd")
const MainScript := preload("res://scripts/main.gd")

# Survive scene reloads so "retry" resumes from the last checkpoint.
static var resume_checkpoint = null
static var resume_collected := {}
static var resume_wells := {}
static var resume_opened := {}

var grid: Array = []
var cols := 0
var rows := 0
var world: Node2D
var art
var player
var core
var hud
var gate_shape: CollisionShape2D
var gate_x := 0
var arena_trigger_x := INF
var checkpoint_pos := Vector2.ZERO
var books_total := 0
var books_collected := 0
var dropped_id := 0
var collected := {}
var well_ink := {}
var opened := {}          # firewall groups that have been hacked open ("a", "b")
var firewalls := {}       # group -> Array of firewall nodes
var terminals := {}       # group -> terminal node
var core_terminals := []
var state := "intro"      # intro, play, boss, won, lost


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	var level1 = MainScript.new()   # borrow its control setup in case this scene is run directly
	level1._setup_input()
	level1.free()
	_parse_map()
	_build_world()

	hud = HudScript.new()
	add_child(hud)
	hud.boss_name = "THE SUPERCOMPUTER CORE"
	hud.set_hearts(player.hp, player.max_hp)
	hud.set_books(books_collected, books_total)
	hud.set_ink(player.ink, player.max_ink)

	world.process_mode = Node.PROCESS_MODE_DISABLED
	if resume_checkpoint != null:
		hud.show_message("REBOOTING...", "Back at your last checkpoint.\n\nPress Space to continue")
	else:
		hud.show_message("LEVEL 3: THE MAINFRAME",
			"The Book Stealer's sack was empty... because he uploaded the rest as E-BOOKS!\n" +
			"Jack into his evil supercomputer and download every e-book back to the library.\n\n" +
			"Stand at a TERMINAL to hack it and shut down the red FIREWALL that matches.\n" +
			"Dodge the security lasers when they flash, and stomp or ink the drones.\n" +
			"At the core: hack a terminal to drop its shield, then ink it fast!\n\n" +
			"Press Space to log in")


func _process(_delta: float) -> void:
	match state:
		"intro":
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
				state = "play"
				hud.hide_message()
				world.process_mode = Node.PROCESS_MODE_INHERIT
				if resume_checkpoint == null:
					hud.banner("ACCESS... GRANTED?", Color(0.4, 1.0, 0.7))
		"won", "lost":
			if hud.message_visible() and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_accept")):
				if state == "won":
					_clear_resume()
					get_tree().change_scene_to_file("res://time.tscn")   # on to Level 4!
				else:
					get_tree().reload_current_scene()
		_:
			if Input.is_action_just_pressed("restart"):
				_clear_resume()
				get_tree().reload_current_scene()
				return
			if state == "play" and player.global_position.x > arena_trigger_x:
				_start_core_fight()
			if player.alive and player.global_position.y > rows * TILE + 48:
				_player_fell()


static func _clear_resume() -> void:
	resume_checkpoint = null
	resume_collected = {}
	resume_wells = {}
	resume_opened = {}


# ---------------------------------------------------------------- map helpers

func tile(x: int, y: int) -> String:
	if x < 0 or x >= cols:
		return "#"
	if y < 0 or y >= rows:
		return " "
	return grid[y][x]


# ---------------------------------------------------------------- level building

func _parse_map() -> void:
	var data: Array = HackData.MAP
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

	var rain := Parallax2D.new()
	rain.scroll_scale = Vector2(0.3, 0.1)
	rain.repeat_size = Vector2(HackArtScript.DataRain.W, 0)
	rain.repeat_times = 3
	rain.z_index = -20
	rain.add_child(HackArtScript.DataRain.new())
	world.add_child(rain)

	art = HackArtScript.new()
	art.setup(grid, TILE)
	world.add_child(art)

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

	# Firewalls: one barrier per vertical run of the same letter.
	for x in cols:
		var y := 0
		while y < rows:
			var c: String = grid[y][x]
			if c == "a" or c == "b":
				var start := y
				while y < rows and grid[y][x] == c:
					y += 1
				var fw = FirewallScript.new()
				fw.height = y - start
				fw.position = Vector2((x + 0.5) * TILE, start * TILE)
				fw.group = c
				world.add_child(fw)
				if not firewalls.has(c):
					firewalls[c] = []
				firewalls[c].append(fw)
				if resume_opened.has(c):
					fw.open(true)
			else:
				y += 1
	opened = resume_opened.duplicate()

	var player_start := Vector2.ZERO
	var core_start := Vector2.ZERO
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
					p.kind = {"B": "ebook", "H": "heart", "N": "ink", "M": "big", "X": "star"}[c]
					p.cell = cell
					p.position = center
					world.add_child(p)
				"W":
					var wm = WormScript.new()
					wm.position = bottom - Vector2(0, 10)
					world.add_child(wm)
				"D":
					var dr = DroneScript.new()
					dr.position = center
					world.add_child(dr)
				"K":
					var iw = InkwellScript.new()
					iw.position = bottom
					iw.cell = Vector2i(x, y)
					iw.stored = resume_wells.get(iw.cell, InkwellScript.MAX_STORED)
					well_ink[iw.cell] = iw.stored
					world.add_child(iw)
				"L":
					var lz = LaserScript.new()
					lz.position = Vector2((x + 0.5) * TILE, y * TILE)
					var ly := y
					while ly < rows and tile(x, ly) != "#":
						ly += 1
					lz.length = (ly - y) * TILE
					lz.phase = fmod(x * 0.37, 1.0)
					world.add_child(lz)
				"1", "2", "T":
					var tm = TerminalScript.new()
					tm.position = bottom
					if c == "T":
						tm.group = "core"
						core_terminals.append(tm)
					else:
						tm.group = "a" if c == "1" else "b"
						terminals[tm.group] = tm
						if resume_opened.has(tm.group):
							tm.hacked = true
					world.add_child(tm)
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
					core_start = center

	# Core-chamber gate: open until the fight starts.
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

	core = CoreScript.new()
	core.position = core_start
	core.min_x = (gate_x + 4) * TILE
	core.max_x = (cols - 4) * TILE
	books_total += core.max_hp * CoreScript.BOOKS_PER_HIT   # every hit spills e-books
	world.add_child(core)


# ---------------------------------------------------------------- game events

func on_terminal_hacked(term) -> void:
	if term.group == "core":
		if state == "boss" and core.drop_shield():
			hud.banner("SHIELD DOWN! INK THE CORE!", Color(0.4, 1.0, 0.7))
			shake(5)
		return
	var g: String = term.group
	if opened.has(g):
		return
	opened[g] = true
	for fw in firewalls.get(g, []):
		fw.open()
	shake(6)
	hud.banner("FIREWALL DISABLED!", Color(0.4, 1.0, 0.7))


func on_core_shield_up() -> void:
	for tm in core_terminals:
		tm.rearm(2.5)
	if state == "boss":
		hud.banner("SHIELD REBOOTED - hack another terminal!", Color(1.0, 0.45, 0.45))


func _start_core_fight() -> void:
	state = "boss"
	gate_shape.set_deferred("disabled", false)
	art.gate_closed = true
	art.queue_redraw()
	player.camera.limit_left = gate_x * TILE
	shake(8)
	hud.banner("THE SUPERCOMPUTER CORE!", Color(1.0, 0.4, 0.45))
	hud.show_boss_bar(core.hp, core.max_hp)
	core.activate(player)


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
	resume_opened = opened.duplicate()
	await get_tree().create_timer(1.6).timeout
	hud.show_message("CONNECTION LOST!", "The supercomputer kicked you out of the system...\n\nPress R or Enter to retry from your last checkpoint")


func drop_book(pos: Vector2) -> void:
	dropped_id += 1
	var p = PickupScript.new()
	p.kind = "ebook"
	p.cell = Vector2i(-1, -dropped_id)
	p.magnet = true
	p.position = pos
	world.add_child.call_deferred(p)


func collect_pickup(pickup) -> void:
	if pickup.kind != "big" and not pickup.magnet:
		collected[pickup.cell] = true
	if pickup.kind == "ebook" or pickup.kind == "book":
		books_collected += 1
		hud.set_books(books_collected, books_total)
		burst(pickup.global_position, Color(0.4, 1.0, 0.9), 14, 160)
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
	hud.banner("Checkpoint saved!", Color(0.5, 1.0, 0.6))
	burst(pos - Vector2(0, 40), Color(0.5, 1.0, 0.6), 16, 140)


func on_boss_hurt(hp: int, max_hp: int) -> void:
	hud.set_boss_hp(hp, max_hp)
	shake(3)


func on_boss_defeated(pos: Vector2) -> void:
	state = "won"
	player.invuln = 999.0
	hud.hide_boss_bar()
	shake(18)
	for i in 8:
		burst(pos + Vector2(randf_range(-40, 40), randf_range(-40, 40)),
			Color.from_hsv(randf_range(0.35, 0.55), 0.7, 1.0), 16, 260)
	for i in 6:
		drop_book(pos + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
	books_total += 6
	hud.set_books(books_collected, books_total)
	hud.banner("SYSTEM CRASH!", Color(0.4, 1.0, 0.7))
	gate_shape.set_deferred("disabled", true)
	art.gate_closed = false
	art.queue_redraw()
	_clear_resume()
	await get_tree().create_timer(3.5).timeout
	hud.show_message("YOU HACKED THE MAINFRAME!",
		"The Evil Book Stealer's supercomputer crashes in a shower of sparks!\n" +
		"Every e-book downloads safely back to the Grand Library's servers.\n" +
		"But the crash rips open a swirling TIME PORTAL... and the Book Stealer dives in!\n\n" +
		"E-books recovered: %d / %d\n\n" % [books_collected, books_total] +
		"Press Enter to jump into the portal after him!")


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
