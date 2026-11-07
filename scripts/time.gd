extends Node2D
## Level 4: lost in time. The supercomputer's crash flung you back to the age of dinosaurs,
## where the Book Stealer is trying to steal the very first stories ever carved in stone.
## Builds the prehistoric world from TimeData.MAP and runs the game flow.

const TILE := 32
const TimeData := preload("res://scripts/time_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RaptorScript := preload("res://scripts/raptor.gd")
const PteroScript := preload("res://scripts/ptero.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const InkwellScript := preload("res://scripts/inkwell.gd")
const SpikesScript := preload("res://scripts/spikes.gd")
const CheckpointScript := preload("res://scripts/checkpoint.gd")
const PortalScript := preload("res://scripts/portal.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const TrexScript := preload("res://scripts/trex.gd")
const TimeArtScript := preload("res://scripts/time_art.gd")
const HudScript := preload("res://scripts/hud.gd")
const MainScript := preload("res://scripts/main.gd")

const METEOR_EVERY := 1.1

# Survive scene reloads so "retry" resumes from the last checkpoint.
static var resume_checkpoint = null
static var resume_collected := {}
static var resume_wells := {}

var grid: Array = []
var cols := 0
var rows := 0
var world: Node2D
var art
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
var meteor_cols := {}
var meteor_t := 2.0
var warped_once := false
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
	hud.boss_name = "THE BOOK STEALER & HIS T-REX"
	hud.set_hearts(player.hp, player.max_hp)
	hud.set_books(books_collected, books_total)
	hud.set_ink(player.ink, player.max_ink)

	world.process_mode = Node.PROCESS_MODE_DISABLED
	if resume_checkpoint != null:
		hud.show_message("TRY AGAIN!", "Back at your last checkpoint.\n\nPress Space to continue")
	else:
		hud.show_message("LEVEL 4: LOST IN TIME",
			"WHOOSH! The time portal flung you way, WAY back... to the age of dinosaurs!\n" +
			"The Book Stealer came too. He's stealing the very first stories ever carved in stone,\n" +
			"so that nobody in the future will ever write a book!\n\n" +
			"Collect the STONE TABLETS. Watch out for charging raptors and swooping pterodactyls.\n" +
			"Step into a glowing TIME PORTAL to warp somewhere else. Beware of the volcano!\n\n" +
			"Press Space to start exploring")


func _process(delta: float) -> void:
	match state:
		"intro":
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
				state = "play"
				hud.hide_message()
				world.process_mode = Node.PROCESS_MODE_INHERIT
				if resume_checkpoint == null:
					hud.banner("WHERE... WHEN AM I?", Color(1.0, 0.75, 0.4))
		"won", "lost":
			if hud.message_visible() and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_accept")):
				if state == "won":
					_clear_resume()
					get_tree().change_scene_to_file("res://future.tscn")   # on to Level 5!
				else:
					get_tree().reload_current_scene()
		_:
			if Input.is_action_just_pressed("restart"):
				_clear_resume()
				get_tree().reload_current_scene()
				return
			if state == "play" and player.global_position.x > arena_trigger_x:
				_start_boss_fight()
			if player.alive and _in_lava(player.global_position):
				burst(player.global_position, Color(1.0, 0.5, 0.1), 20, 240)
				_player_fell()
			elif player.alive and player.global_position.y > rows * TILE + 48:
				_player_fell()
			if state == "play" and player.alive:
				_update_meteors(delta)


static func _clear_resume() -> void:
	resume_checkpoint = null
	resume_collected = {}
	resume_wells = {}


func _in_lava(pos: Vector2) -> bool:
	var col := int(pos.x / TILE)
	return art.lava_cols.has(col) and pos.y > (rows - 1.2) * TILE


# ---------------------------------------------------------------- level building

func _parse_map() -> void:
	var data: Array = TimeData.MAP
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

	var sky := Parallax2D.new()
	sky.scroll_scale = Vector2(0.2, 0.1)
	sky.repeat_size = Vector2(TimeArtScript.Backdrop.W, 0)
	sky.repeat_times = 3
	sky.z_index = -20
	sky.add_child(TimeArtScript.Backdrop.new())
	world.add_child(sky)

	art = TimeArtScript.new()
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

	var player_start := Vector2.ZERO
	var boss_start := Vector2.ZERO
	var gate_rows := []
	var portals := []
	for y in rows:
		for x in cols:
			var c: String = grid[y][x]
			var center := Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			var bottom := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match c:
				"P":
					player_start = bottom
				"v":
					meteor_cols[x] = true
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
					p.kind = {"B": "tablet", "H": "heart", "N": "ink", "M": "big", "X": "star"}[c]
					p.cell = cell
					p.position = center
					world.add_child(p)
				"R":
					var rp = RaptorScript.new()
					rp.position = bottom - Vector2(0, 12)
					world.add_child(rp)
				"F":
					var pt = PteroScript.new()
					pt.position = center
					world.add_child(pt)
				"K":
					var iw = InkwellScript.new()
					iw.position = bottom
					iw.cell = Vector2i(x, y)
					iw.stored = resume_wells.get(iw.cell, InkwellScript.MAX_STORED)
					well_ink[iw.cell] = iw.stored
					world.add_child(iw)
				"^":
					var s = SpikesScript.new()
					s.style = "stone"
					s.position = center
					world.add_child(s)
				"O":
					var po = PortalScript.new()
					po.position = bottom
					world.add_child(po)
					portals.append(po)
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

	# Link the time portals in pairs, left to right.
	portals.sort_custom(func(a, b): return a.position.x < b.position.x)
	for i in range(0, portals.size() - 1, 2):
		portals[i].partner = portals[i + 1]
		portals[i + 1].partner = portals[i]

	# Arena gate: open until the fight starts.
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

	boss = TrexScript.new()
	boss.position = boss_start - Vector2(0, 30)
	boss.min_x = (gate_x + 2) * TILE
	boss.max_x = (cols - 2) * TILE
	world.add_child(boss)


# ---------------------------------------------------------------- meteors

func _update_meteors(delta: float) -> void:
	var col := int(player.global_position.x / TILE)
	if not meteor_cols.has(col):
		return
	meteor_t -= delta
	if meteor_t > 0.0:
		return
	meteor_t = METEOR_EVERY * randf_range(0.7, 1.3)
	# land them around (and a little ahead of) where you're heading
	spawn_meteor(player.global_position.x + player.velocity.x * 0.7 + randf_range(-180, 260))


## Drop a flaming rock from the top of the screen at this x.
func spawn_meteor(x: float) -> void:
	var top: float = player.camera.get_screen_center_position().y - get_viewport_rect().size.y / 2.0 - 30.0
	var m = ProjectileScript.new()
	m.team = "enemy"
	m.kind = "rock"
	m.vel = Vector2(randf_range(-50, 50), 140.0)
	m.grav = 600.0
	m.life = 4.0
	m.position = Vector2(x, top)
	world.add_child(m)


# ---------------------------------------------------------------- game events

func on_time_warp() -> void:
	shake(5)
	if not warped_once:
		warped_once = true
		hud.banner("TIME WARP!", Color(0.6, 0.9, 1.0))


func _start_boss_fight() -> void:
	state = "boss"
	gate_shape.set_deferred("disabled", false)
	art.gate_closed = true
	art.queue_redraw()
	player.camera.limit_left = gate_x * TILE
	shake(10)
	hud.banner("HE TAMED A T-REX?!", Color(1.0, 0.55, 0.3))
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
	hud.show_message("EXTINCT!", "Looks like you went the way of the dinosaurs...\n\nPress R or Enter to retry from your last checkpoint")


func collect_pickup(pickup) -> void:
	if pickup.kind != "big":
		collected[pickup.cell] = true
	if pickup.kind == "tablet":
		books_collected += 1
		hud.set_books(books_collected, books_total)
		burst(pickup.global_position, Color(1.0, 0.85, 0.5), 14, 160)
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
	shake(18)
	for i in 8:
		burst(pos + Vector2(randf_range(-40, 40), randf_range(-40, 20)),
			Color.from_hsv(randf_range(0.0, 0.15), 0.8, 1.0), 16, 260)
	hud.banner("THE STORIES ARE SAFE!", Color(1.0, 0.85, 0.4))
	gate_shape.set_deferred("disabled", true)
	art.gate_closed = false
	art.queue_redraw()
	_clear_resume()
	await get_tree().create_timer(3.0).timeout
	hud.show_message("YOU SAVED HISTORY!",
		"The T-Rex bucks the Book Stealer right out of the saddle and stomps off into the jungle!\n" +
		"The first stories ever told are safe... but the thief scrambles into the time portal,\n" +
		"cranks the dial all the way FORWARD and vanishes into the future!\n\n" +
		"Stone tablets recovered: %d / %d\n\n" % [books_collected, books_total] +
		"Press Enter to dive into the portal after him!")


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
