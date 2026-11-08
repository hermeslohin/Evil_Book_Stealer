extends Node2D
## Level 2: the skateboard chase. Builds the city from ChaseData.MAP and runs the chase.
## No boss fight here: the thief escapes over the wall at the end of the alley, and reaching
## the end of the alley finishes the level. You fight him in Level 3, the Hideout.

const TILE := 32
const ChaseData := preload("res://scripts/chase_data.gd")
const SkaterScript := preload("res://scripts/skater.gd")
const RunnerScript := preload("res://scripts/runner.gd")
const WormScript := preload("res://scripts/bookworm.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const SpikesScript := preload("res://scripts/spikes.gd")
const CheckpointScript := preload("res://scripts/checkpoint.gd")
const ChaseArtScript := preload("res://scripts/chase_art.gd")
const HudScript := preload("res://scripts/hud.gd")
const Progress := preload("res://scripts/progress.gd")
const MainScript := preload("res://scripts/main.gd")

# Survive scene reloads so "retry" resumes from the last checkpoint.
static var resume_checkpoint = null
static var resume_collected := {}
static var resume_bonus_books := 0
static var resume_thief_hp := -1

var grid: Array = []
var cols := 0
var rows := 0
var world: Node2D
var player
var thief
var hud
var arena_x := INF     # past this point you can ride freely (pixels)
var stand_x := INF     # where the thief stops running (pixels)
var checkpoint_pos := Vector2.ZERO
var books_total := 0
var books_collected := 0
var bonus_books := 0
var dropped_id := 0
var collected := {}
var well_ink := {}     # unused here, but shared scripts expect it
var state := "intro"   # intro, play, alley, won, lost


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
	hud.set_hearts(player.hp, player.max_hp)
	hud.set_books(books_collected, books_total)
	hud.set_ink(player.ink, player.max_ink)

	world.process_mode = Node.PROCESS_MODE_DISABLED
	if resume_checkpoint != null:
		hud.show_message("TRY AGAIN!", "Back on your board at the last checkpoint.\n\nPress Space to continue")
	else:
		hud.show_message("LEVEL 2: THE GETAWAY",
			"The Book Stealer escaped with his sack of books!\n" +
			"Grab your skateboard and chase him through the city!\n\n" +
			"You roll forward on your own.  Right: go faster     Left: slow down\n" +
			"Jump: Space / W / Z  -  hop cones and gaps, grind rails, hit the ramps!\n" +
			"Throw ink (J / X) or jump on his head to knock books out of his sack.\n" +
			"Grab as many as you can before he gets away!\n" +
			"Don't ride into walls!\n\n" +
			"Press Space to start the chase")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("to_map"):
		_clear_resume()
		Progress.go_to_map(get_tree())
		return
	match state:
		"intro":
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
				state = "play"
				hud.hide_message()
				world.process_mode = Node.PROCESS_MODE_INHERIT
				_apply_packed_items()
				thief.activate(player)
				if resume_checkpoint == null:
					hud.banner("CATCH HIM!", Color(1.0, 0.6, 0.3))
		"won", "lost":
			if hud.message_visible() and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_accept")):
				if state == "won":
					_clear_resume()
					Progress.go_to_map(get_tree())
				else:
					get_tree().reload_current_scene()
		_:
			if Input.is_action_just_pressed("restart"):
				_clear_resume()
				get_tree().reload_current_scene()
				return
			if state == "play" and player.global_position.x > arena_x:
				_enter_alley()
			if state == "alley" and player.global_position.x > stand_x - 3 * TILE:
				_finish_level()
			if player.alive and player.global_position.y > rows * TILE + 48:
				_player_fell()


func _apply_packed_items() -> void:
	if resume_checkpoint != null:
		return
	var packed := Progress.apply_run_items(player)
	if packed != "":
		get_tree().create_timer(1.6).timeout.connect(func(): hud.banner(packed + "!", Color(1.0, 0.85, 0.3)))


static func _clear_resume() -> void:
	resume_checkpoint = null
	resume_collected = {}
	resume_bonus_books = 0
	resume_thief_hp = -1


# ---------------------------------------------------------------- map helpers

func tile(x: int, y: int) -> String:
	if x < 0 or x >= cols:
		return "#"
	if y < 0 or y >= rows:
		return " "
	return grid[y][x]


func tile_at(pos: Vector2) -> String:
	return tile(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))


## Pixel y of the first surface you could stand on in this column.
func ground_top(col: int) -> float:
	for y in rows:
		var c := tile(col, y)
		if c == "#" or c == "=":
			return y * TILE
	return (rows - 2) * TILE


# ---------------------------------------------------------------- level building

func _parse_map() -> void:
	var data: Array = ChaseData.MAP
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
	sky.scroll_scale = Vector2(0.25, 0.1)
	sky.repeat_size = Vector2(ChaseArtScript.Skyline.W, 0)
	sky.repeat_times = 3
	sky.z_index = -20
	sky.add_child(ChaseArtScript.Skyline.new())
	world.add_child(sky)

	var art = ChaseArtScript.new()
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
			elif c == "/":
				var cp := CollisionPolygon2D.new()
				cp.polygon = PackedVector2Array([Vector2(0, TILE), Vector2(TILE, TILE), Vector2(TILE, 12)])
				cp.position = Vector2(x * TILE, y * TILE)
				solids.add_child(cp)
				x += 1
			else:
				x += 1

	var player_start := Vector2.ZERO
	var thief_start := Vector2.ZERO
	for y in rows:
		for x in cols:
			var c: String = grid[y][x]
			var center := Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			var bottom := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match c:
				"P":
					player_start = bottom
				"S":
					thief_start = bottom
				"A":
					arena_x = x * TILE
				"E":
					stand_x = x * TILE
				"B", "H", "N", "M":
					var cell := Vector2i(x, y)
					if c == "B":
						books_total += 1
					if resume_collected.has(cell):
						collected[cell] = true
						if c == "B":
							books_collected += 1
						continue
					var p = PickupScript.new()
					p.kind = "book" if c == "B" else ("heart" if c == "H" else ("ink" if c == "N" else "big"))
					p.cell = cell
					p.position = center
					world.add_child(p)
				"W":
					var wm = WormScript.new()
					wm.position = bottom - Vector2(0, 10)
					world.add_child(wm)
				"^":
					var s = SpikesScript.new()
					s.style = "cone"
					s.position = center
					world.add_child(s)
				"C":
					var cp = CheckpointScript.new()
					cp.position = bottom
					world.add_child(cp)
					if resume_checkpoint != null and resume_checkpoint.is_equal_approx(bottom):
						cp.activate(true)

	checkpoint_pos = player_start
	if resume_checkpoint != null:
		checkpoint_pos = resume_checkpoint

	player = SkaterScript.new()
	player.position = checkpoint_pos - Vector2(0, 16)
	world.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = cols * TILE
	player.camera.limit_bottom = rows * TILE
	player.camera.reset_smoothing()

	thief = RunnerScript.new()
	books_total += thief.max_hp - RunnerScript.RUN_MIN_HP   # each hit knocks a book out of his sack
	bonus_books = resume_bonus_books
	books_collected += bonus_books
	if resume_thief_hp > 0:
		thief.hp = resume_thief_hp
	if resume_checkpoint != null:
		var col := int(checkpoint_pos.x / TILE) + 11
		thief_start = Vector2((col + 0.5) * TILE, ground_top(col))
	thief.position = thief_start - Vector2(0, 28)
	world.add_child(thief)

	if checkpoint_pos.x > arena_x:
		_enter_alley(true)


# ---------------------------------------------------------------- game events

func _enter_alley(silent := false) -> void:
	state = "alley"
	player.auto = false
	player.camera.limit_left = int(arena_x) - 4 * TILE
	if not silent:
		hud.banner("DEAD END! Don't let him get away!", Color(1.0, 0.5, 0.6))


func _player_fell() -> void:
	player.take_damage(1, null, true)
	if player.alive:
		player.respawn(checkpoint_pos - Vector2(0, 16))
		# the thief waits a little way ahead so the chase can continue
		if not thief.cornered and not thief.dead and not thief.escaped:
			var col := int(checkpoint_pos.x / TILE) + 11
			thief.global_position = Vector2((col + 0.5) * TILE, ground_top(col) - 28.0)
			thief.velocity = Vector2.ZERO


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
	resume_bonus_books = bonus_books
	resume_thief_hp = thief.hp
	await get_tree().create_timer(1.6).timeout
	hud.show_message("WIPEOUT!", "The Book Stealer gets away... for now!\n\nPress R or Enter to retry from your last checkpoint\nPress Esc to go back to the world map")


func drop_book(pos: Vector2) -> void:
	dropped_id += 1
	var p = PickupScript.new()
	p.kind = "book"
	p.cell = Vector2i(-1, -dropped_id)
	p.magnet = true
	p.position = pos
	world.add_child.call_deferred(p)
	burst(pos, Color(1.0, 0.85, 0.3), 8, 140)


func collect_pickup(pickup) -> void:
	if pickup.kind == "book" and pickup.magnet:
		bonus_books += 1
	elif pickup.kind != "big":
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
	else:
		player.heal(1)
		burst(pickup.global_position, Color(1.0, 0.35, 0.45), 14, 160)


func set_checkpoint(pos: Vector2) -> void:
	if checkpoint_pos.is_equal_approx(pos):
		return
	checkpoint_pos = pos
	hud.banner("Checkpoint!", Color(0.5, 1.0, 0.6))
	burst(pos - Vector2(0, 40), Color(0.5, 1.0, 0.6), 16, 140)


func on_thief_hurt(_hp: int, _max_hp: int) -> void:
	shake(3)


var too_fast_cd := 0.0

func on_thief_too_fast() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > too_fast_cd:
		too_fast_cd = now + 4.0
		hud.banner("He's clutching the last books too tight!", Color(1.0, 0.7, 0.4))


func on_thief_escaped(pos: Vector2) -> void:
	burst(pos, Color(0.6, 0.4, 0.8), 18, 220)
	if state != "won":
		hud.banner("He leapt over the wall!", Color(0.85, 0.6, 1.0))


## Reached the end of the alley: the chase is over and the thief has fled to his hideout.
func _finish_level() -> void:
	state = "won"
	thief.escape()
	var reward := Progress.complete_level(2, books_collected, books_total)
	player.invuln = 999.0
	player.auto = false
	_clear_resume()
	await get_tree().create_timer(1.8).timeout
	hud.show_message("LEVEL 2 COMPLETE!",
		"The Evil Book Stealer leapt over the wall and got away...\n" +
		"but you spotted where he went: his secret HIDEOUT in Book Town!\n\n" +
		"Books recovered in the chase: %d / %d\n\n" % [books_collected, books_total] +
		reward + "\n\nPress Enter to return to the world map")


func on_thief_defeated(pos: Vector2) -> void:
	state = "won"
	var reward := Progress.complete_level(2, books_collected, books_total)
	player.invuln = 999.0
	hud.hide_boss_bar()
	shake(16)
	for i in 6:
		burst(pos + Vector2(randf_range(-30, 30), randf_range(-40, 10)),
			Color.from_hsv(randf(), 0.7, 1.0), 16, 260)
	hud.banner("GOTCHA!", Color(1.0, 0.85, 0.3))
	_clear_resume()
	await get_tree().create_timer(2.5).timeout
	hud.show_message("YOU CAUGHT HIM!",
		"The Evil Book Stealer is cornered and his sack is empty!\n" +
		"But wait... where are all the E-BOOKS he stole?\n" +
		"\"Ha! They're locked inside my SUPERCOMPUTER!\" he cackles.\n\n" +
		"Books recovered in the chase: %d / %d\n\n" % [books_collected, books_total] +
		reward + "\n\nPress Enter to return to the world map")


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
