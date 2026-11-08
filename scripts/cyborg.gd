extends CharacterBody2D
## Level 7 boss: the Cyborg Book Stealer, who rebuilt himself out of robot parts and took over the world.
## He sweeps a laser beam along the floor (jump it!) and then OVERHEATS, fires rocket fists,
## launches homing missiles, and once he's damaged, rockets up and slams down from the sky.
## Stomp his head (2 damage) or hit him with ink (1 damage). Both count double while he's overheated.

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1500.0
const ProjectileScript := preload("res://scripts/projectile.gd")
const BEAM_WARN := 0.9
const BEAM_TIME := 0.7

var max_hp := roundi(26 * D.BOSS_HP)
var hp := max_hp
var active := false
var dead := false
var state := "idle"
var state_t := 0.0
var facing := -1
var flash := 0.0
var stomp_cd := 0.0
var t := 0.0
var shots_left := 0
var shot_t := 0.0
var last_attack := -1
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0
var death_t := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(68, 94)
	cs.shape = r
	cs.position = Vector2(0, -7)
	add_child(cs)


func _main():
	return get_tree().current_scene


func get_top_y() -> float:
	return global_position.y - 54.0


func activate(p) -> void:
	player = p
	active = true
	floor_y = global_position.y + 40.0
	_set_state("taunt", 1.6)


func _set_state(s: String, duration: float) -> void:
	state = s
	state_t = duration


func _enraged() -> bool:
	return hp <= max_hp / 2


func _face_player() -> void:
	if player:
		facing = 1 if player.global_position.x > global_position.x else -1


func _physics_process(delta: float) -> void:
	delta *= D.BOSS_TEMPO
	t += delta
	flash = max(flash - delta, 0.0)
	stomp_cd = max(stomp_cd - delta, 0.0)
	modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE

	if dead:
		death_t += delta
		position += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if fmod(death_t, 0.12) < delta:
			_main().burst(global_position + Vector2(randf_range(-30, 30), randf_range(-40, 40)),
				Color.from_hsv(randf_range(0.0, 0.12), 0.8, 1.0), 8, 220)
		modulate.a = clampf(2.0 - death_t * 0.7, 0.0, 1.0)
		queue_redraw()
		return

	if not active:
		velocity.y = min(velocity.y + GRAVITY * delta, 1000.0)
		move_and_slide()
		queue_redraw()
		return

	state_t -= delta
	var mult := 1.3 if _enraged() else 1.0
	var flying := state in ["jet_up", "jet_hover"]
	if not flying:
		velocity.y = min(velocity.y + GRAVITY * (2.5 if state == "jet_drop" else 1.0) * delta, 1400.0)

	match state:
		"taunt", "idle":
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			_face_player()
			if state_t <= 0.0:
				_choose_attack()
		"walk":
			_face_player()
			velocity.x = facing * 90.0 * mult
			if state_t <= 0.0:
				_choose_attack()
		"beam_warn":
			velocity.x = 0.0
			if state_t <= 0.0:
				_set_state("beam", BEAM_TIME)
				_main().shake(6)
		"beam":
			velocity.x = 0.0
			_beam_damage()
			if state_t <= 0.0:
				_set_state("overheat", 2.2)
				_main().hud.banner("OVERHEATED! HIT HIM NOW!", Color(1.0, 0.7, 0.3))
		"overheat":
			velocity.x = 0.0
			if randf() < 0.3:
				_main().burst(global_position + Vector2(randf_range(-20, 20), -40), Color(0.85, 0.85, 0.9, 0.7), 1, 60)
			if state_t <= 0.0:
				_set_state("idle", 0.4)
		"fists":
			velocity.x = 0.0
			_face_player()
			shot_t -= delta
			if shot_t <= 0.0:
				if shots_left > 0:
					_fire_fist()
					shots_left -= 1
					shot_t = 0.7 / mult
				else:
					_set_state("idle", 0.8 / mult)
		"missiles":
			velocity.x = 0.0
			shot_t -= delta
			if shot_t <= 0.0:
				if shots_left > 0:
					_fire_missile()
					shots_left -= 1
					shot_t = 0.35
				else:
					_set_state("idle", 1.2 / mult)
		"jet_up":
			velocity = Vector2(0, -520)
			if global_position.y < floor_y - 300.0 or state_t <= 0.0:
				_set_state("jet_hover", 1.1)
		"jet_hover":
			# chase above the player, then drop
			var tx: float = clamp(player.global_position.x, min_x, max_x)
			velocity = Vector2((tx - global_position.x) * 4.0, 0)
			if state_t <= 0.0:
				velocity = Vector2.ZERO
				_set_state("jet_drop", 3.0)
		"jet_drop":
			velocity.x = 0.0
			if is_on_floor() and state_t < 2.95:
				_main().shake(14)
				_main().burst(global_position + Vector2(0, 40), Color(0.7, 0.7, 0.8), 20, 240)
				if global_position.y + 40.0 < floor_y - 8.0:
					# landed on a floating platform: crash through it down to the floor
					collision_mask = 0
					_set_state("drop_down", 2.0)
				else:
					_shockwaves()
					_set_state("idle", 1.0)
		"drop_down":
			velocity.x = 0.0
			if global_position.y + 40.0 >= floor_y or state_t <= 0.0:
				global_position.y = floor_y - 40.0
				velocity.y = 0.0
				collision_mask = 1
				_main().shake(8)
				_shockwaves()
				_set_state("idle", 1.0)

	move_and_slide()
	queue_redraw()


func _choose_attack() -> void:
	var n := 4 if _enraged() else 3
	var r := randi() % n
	if r == last_attack:
		r = (r + 1) % n
	last_attack = r
	match r:
		0:
			_face_player()
			_set_state("beam_warn", BEAM_WARN)
		1:
			shots_left = 3 if _enraged() else 2
			shot_t = 0.5
			_set_state("fists", 99.0)
		2:
			shots_left = 5 if _enraged() else 3
			shot_t = 0.4
			_set_state("missiles", 99.0)
		3:
			_set_state("jet_up", 1.2)
			_main().hud.banner("ROCKET BOOTS ENGAGED!", Color(1.0, 0.4, 0.5))


func _beam_rect() -> Rect2:
	# a beam from his eye cannon down to ankle height, sweeping the floor in front of him
	var y := floor_y - 12.0
	if facing > 0:
		return Rect2(global_position.x + 20, y - 10, max_x + 200 - global_position.x, 20)
	return Rect2(min_x - 200, y - 10, global_position.x - 20 - (min_x - 200), 20)


func _beam_damage() -> void:
	if player == null or not player.alive:
		return
	var feet: Vector2 = player.global_position + Vector2(0, 14.0 * player.scale.y)
	if _beam_rect().grow(4).has_point(feet):
		player.take_damage(1, global_position)


func _fire_fist() -> void:
	var origin := global_position + Vector2(facing * 34, -6)
	var aim: Vector2 = (player.global_position - origin).normalized()
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "fist"
	p.vel = aim * 360.0 * D.ENEMY_SHOT_SPEED
	p.life = 3.0
	p.position = origin
	get_parent().add_child(p)
	_main().burst(origin, Color(1.0, 0.6, 0.2), 8, 120)


func _fire_missile() -> void:
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "missile"
	p.vel = Vector2(randf_range(-160, 160), -300)
	p.target = player
	p.homing = 1.8
	p.life = 4.0
	p.position = global_position + Vector2(-facing * 16, -40)
	get_parent().add_child(p)


func _shockwaves() -> void:
	for d in [-1, 1]:
		var p = ProjectileScript.new()
		p.team = "enemy"
		p.kind = "bolt"
		p.vel = Vector2(d * 300.0, 0)
		p.life = 2.5
		p.position = global_position + Vector2(d * 34, 30)
		get_parent().add_child(p)


func hit(dmg: int) -> void:
	if dead or not active:
		return
	if state == "overheat":
		dmg *= 2
	hp = max(hp - dmg, 0)
	flash = 0.1
	_main().on_boss_hurt(hp, max_hp)
	if hp <= 0:
		_die()


func stomped(_by) -> void:
	if stomp_cd > 0.0 or not active:
		return
	stomp_cd = 0.4
	hp = max(hp - (4 if state == "overheat" else 2), 0)
	flash = 0.15
	_main().on_boss_hurt(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	z_index = 40
	_main().on_boss_defeated(global_position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := float(facing)
	var metal := Color(0.55, 0.57, 0.66)
	var dark := Color(0.25, 0.26, 0.33)
	var hot := state == "overheat"
	if hot:
		metal = metal.lerp(Color(1.0, 0.45, 0.25), 0.4 + 0.2 * sin(t * 12.0))
	if state == "beam_warn" and int(t * 16.0) % 2 == 0:
		metal = Color(0.9, 0.35, 0.4)
	if _enraged() and active and not dead:
		draw_circle(Vector2(0, -6), 56.0 + sin(t * 8.0) * 3.0, Color(1.0, 0.2, 0.3, 0.12))

	# the floor beam (drawn first so it sits behind him)
	if state == "beam_warn" or state == "beam":
		var br := _beam_rect()
		br.position -= global_position
		if state == "beam_warn":
			if int(t * 14.0) % 2 == 0:
				draw_line(Vector2(br.position.x, br.get_center().y), Vector2(br.end.x, br.get_center().y), Color(1.0, 0.3, 0.3, 0.5), 1.5)
		else:
			var wob := sin(t * 60.0) * 2.0
			draw_rect(br.grow(4 + wob), Color(1.0, 0.1, 0.2, 0.3))
			draw_rect(br, Color(1.0, 0.25, 0.35, 0.9))
			draw_rect(Rect2(br.position.x, br.get_center().y - 2, br.size.x, 4), Color(1, 0.9, 0.9))
		var eye_cannon := Vector2(f * 12, -28)
		var beam_y := br.get_center().y
		draw_line(eye_cannon, Vector2(f * 30, beam_y), Color(1.0, 0.3, 0.35, 0.8 if state == "beam" else 0.3), 3.0)

	var flying := state in ["jet_up", "jet_hover", "jet_drop"]
	# rocket boots
	if flying:
		for x in [-12, 12]:
			var fl := 18.0 + randf() * 10.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 40), Vector2(x + 7, 40), Vector2(x, 40 + fl)]), Color(1.0, 0.6, 0.2, 0.85))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 40), Vector2(x + 3, 40), Vector2(x, 40 + fl * 0.6)]), Color(1.0, 0.95, 0.6))
	# legs (robot)
	var step := sin(t * 10.0) * 4.0 if state == "walk" else 0.0
	draw_rect(Rect2(-18 + step, 14, 13, 22), dark)
	draw_rect(Rect2(5 - step, 14, 13, 22), dark)
	draw_rect(Rect2(-21 + step, 33, 18, 7), metal)
	draw_rect(Rect2(3 - step, 33, 18, 7), metal)
	# torn purple cloak hanging behind
	draw_colored_polygon(PackedVector2Array([Vector2(-f * 4, -30), Vector2(-f * 26, 26), Vector2(-f * 14, 20), Vector2(-f * 8, 30), Vector2(f * 2, 0)]), Color(0.38, 0.16, 0.5))
	# armoured torso
	draw_rect(Rect2(-24, -22, 48, 38), metal)
	draw_rect(Rect2(-24, -22, 48, 5), metal.lightened(0.2))
	# glowing power core (shows the stolen-book symbol)
	var core_col := Color(1.0, 0.3, 0.4) if not hot else Color(1.0, 0.8, 0.3)
	draw_circle(Vector2(0, -2), 10.0, dark)
	draw_circle(Vector2(0, -2), 7.0 + sin(t * 6.0), core_col)
	draw_rect(Rect2(-3, -5, 6, 6), Color(1, 1, 1, 0.8))
	# belt with gold buckle, like his old outfit
	draw_rect(Rect2(-24, 10, 48, 5), Color(0.2, 0.12, 0.08))
	draw_rect(Rect2(-4, 9, 8, 7), Color(0.9, 0.75, 0.2))
	# arms: back arm and a big cannon arm in front
	draw_rect(Rect2(-f * 28 - 6, -18, 12, 26), dark)
	var fist_gone := state == "fists" and shot_t > 0.35
	draw_rect(Rect2(f * 24 - 7, -18, 14, 22), dark)
	if not fist_gone:
		draw_rect(Rect2(f * 24 - 9, 2, 18, 14), metal)
	# missile pods on the shoulders
	for i in 2:
		draw_rect(Rect2(-22 + i * 30, -32, 14, 10), dark)
		draw_circle(Vector2(-15 + i * 30, -27), 3.0, Color(1.0, 0.3, 0.35) if state == "missiles" else Color(0.4, 0.15, 0.2))
	# hooded head: half face, half robot
	var head := Vector2(f * 4, -38)
	draw_circle(head, 15.0, Color(0.38, 0.16, 0.5))         # hood
	draw_circle(head + Vector2(f * 2, 2), 11.0, Color(0.06, 0.03, 0.08))
	draw_circle(head + Vector2(-f * 3, 1), 2.6, Color(1.0, 0.9, 0.2))   # his old glowing eye
	var eye_col := Color(1.0, 0.15, 0.2)
	if state == "beam_warn":
		eye_col = Color(1.0, 0.9, 0.3) if int(t * 20.0) % 2 == 0 else Color(1.0, 0.3, 0.2)
	draw_rect(Rect2(head.x + f * 2 - 4, head.y - 3, 9, 7), dark)            # cyber eyepiece
	draw_circle(head + Vector2(f * 6, 1), 3.0 + (2.0 if state == "beam" else 0.0), eye_col)
	draw_line(head + Vector2(f * 4, 4), head + Vector2(f * 9, 10), dark, 2.0)  # wires
	# crown: he rules the world now
	var crown := head + Vector2(0, -15)
	draw_colored_polygon(PackedVector2Array([crown + Vector2(-10, 4), crown + Vector2(10, 4), crown + Vector2(10, -4),
		crown + Vector2(5, 0), crown + Vector2(0, -6), crown + Vector2(-5, 0), crown + Vector2(-10, -4)]), Color(0.95, 0.8, 0.25))
	draw_circle(crown + Vector2(0, 1), 1.8, Color(1.0, 0.3, 0.4))
	if hot:
		for i in 3:
			var k := fmod(t * 1.5 + i * 0.33, 1.0)
			draw_circle(Vector2(-14 + i * 14, -50 - k * 30.0), 4.0 + k * 6.0, Color(0.85, 0.85, 0.9, 0.5 * (1.0 - k)))
