extends CharacterBody2D
## The Evil Book Stealer on the run. He sprints ahead of you through the city, leaping over
## everything and tossing books back at you. Ink him (1 damage) or jump on his head (2 damage)
## to knock books out of his sack. At the dead-end alley he turns and makes a last stand.

const GRAVITY := 1500.0
const RUN_MIN_HP := 5   # can't be knocked below this until he's cornered
const TILE := 32
const ProjectileScript := preload("res://scripts/projectile.gd")

var max_hp := 14
var hp := 14
var active := false
var dead := false
var cornered := false
var state := "run"     # run, windup, throw, (cornered:) idle, hop
var state_t := 0.0
var facing := 1
var t := 0.0
var flash := 0.0
var stomp_cd := 0.0
var stumble := 0.0
var throw_t := 2.5
var throws_left := 0
var target_x := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(34, 56)
	cs.shape = r
	add_child(cs)


func _main():
	return get_tree().current_scene


func is_thief() -> bool:
	return true


func get_top_y() -> float:
	return global_position.y - 28.0


func activate(p) -> void:
	player = p
	active = true


func corner() -> void:
	if cornered:
		return
	cornered = true
	state = "idle"
	state_t = 1.0


func _physics_process(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	stomp_cd = max(stomp_cd - delta, 0.0)
	stumble = max(stumble - delta, 0.0)
	modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE

	if dead:
		velocity.y += GRAVITY * delta
		position += velocity * delta
		rotation += 4.0 * delta
		if position.y > 3000:
			queue_free()
		queue_redraw()
		return

	velocity.y = min(velocity.y + GRAVITY * delta, 1000.0)
	if not active:
		velocity.x = 0.0
		move_and_slide()
		queue_redraw()
		return

	if cornered:
		_last_stand(delta)
	else:
		_flee(delta)

	move_and_slide()

	# Fell down a hole? He scrambles back out further ahead.
	if global_position.y > _main().rows * TILE + 80:
		var col := int(player.global_position.x / TILE) + 12
		global_position = Vector2((col + 0.5) * TILE, _main().ground_top(col) - 28.0)
		velocity = Vector2.ZERO
	queue_redraw()


func _flee(delta: float) -> void:
	var m = _main()
	if global_position.x >= m.stand_x:
		corner()
		return
	facing = 1
	# He jogs at a steady pace. Hold Right to catch up! Get too close and he sprints;
	# fall too far behind and he slows down to taunt you.
	var gap: float = global_position.x - player.global_position.x
	var spd := 320.0
	if gap > 850.0:
		spd = 0.0
	elif gap > 560.0:
		spd = 160.0
	elif gap < 150.0:
		spd = 470.0
	if stumble > 0.0:
		spd = 80.0
	if state == "windup":
		spd = min(spd, 220.0)
	if not is_on_floor():
		spd = max(spd, 300.0)   # never stall in mid-air over a gap
	velocity.x = move_toward(velocity.x, spd, 1600.0 * delta)
	if is_on_floor() and stumble <= 0.0 and _obstacle_ahead():
		velocity.y = -640.0

	# Toss books back over his shoulder.
	throw_t -= delta
	if state == "run" and throw_t <= 0.0 and player.alive:
		var dist: float = global_position.x - player.global_position.x
		if dist > 120.0 and dist < 750.0:
			state = "windup"
			state_t = 0.4
		else:
			throw_t = 0.5
	if state == "windup":
		state_t -= delta
		if state_t <= 0.0:
			_throw_book()
			state = "run"
			throw_t = randf_range(1.8, 3.0) * (0.75 if hp <= max_hp / 2 else 1.0)


func _last_stand(delta: float) -> void:
	var m = _main()
	state_t -= delta
	if player:
		facing = 1 if player.global_position.x > global_position.x else -1
	match state:
		"idle":
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if state_t <= 0.0 and is_on_floor():
				if randf() < 0.55:
					state = "windup"
					state_t = 0.45
					throws_left = 3 if hp <= max_hp / 2 else 2
				else:
					state = "hop"
					target_x = randf_range(m.arena_x + 4.0 * TILE, m.stand_x + TILE)
					velocity.y = -680.0
					state_t = 2.0
		"windup":
			velocity.x = 0.0
			if state_t <= 0.0:
				_throw_book()
				throws_left -= 1
				if throws_left > 0:
					state_t = 0.35
				else:
					state = "idle"
					state_t = randf_range(0.8, 1.4)
		"hop":
			velocity.x = clampf((target_x - global_position.x) * 3.0, -300.0, 300.0)
			if (is_on_floor() and state_t < 1.9) or state_t <= 0.0:
				velocity.x = 0.0
				m.shake(4)
				state = "idle"
				state_t = randf_range(0.5, 1.0)
	if stumble > 0.0:
		velocity.x = 0.0


func _obstacle_ahead() -> bool:
	var m = _main()
	var feet := global_position.y + 28.0
	var row := int(floor((feet - 4.0) / TILE))
	for dx in [20.0, 44.0, 68.0]:
		var col := int((global_position.x + dx + velocity.x * 0.05) / TILE)
		var here: String = m.tile(col, row)
		if here == "#" or here == "^" or m.tile(col, row - 1) == "#":
			return true
		var below: String = m.tile(col, row + 1)
		if here != "/" and not below in ["#", "=", "/"]:
			return true
	return false


func _throw_book() -> void:
	if not player or not player.alive:
		return
	var origin := global_position + Vector2(facing * -6.0, -34)
	var lead_t := 0.8
	var target: Vector2 = player.global_position + Vector2(player.velocity.x * lead_t * 0.85, 0)
	var g := 900.0
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "book"
	p.grav = g
	p.vel = Vector2((target.x - origin.x) / lead_t, (target.y - origin.y - 0.5 * g * lead_t * lead_t) / lead_t)
	p.position = origin
	get_parent().add_child(p)


func hit(dmg: int) -> void:
	if dead or not active:
		return
	_hurt(dmg, 0.45)


func stomped(_by) -> void:
	if stomp_cd > 0.0 or not active or dead:
		return
	stomp_cd = 0.4
	_hurt(2, 0.9)


func _hurt(dmg: int, stun: float) -> void:
	# While still on the run he's too slippery to finish off: you have to corner him first.
	var floor_hp := 0 if cornered else RUN_MIN_HP
	dmg = clampi(dmg, 0, max(hp - floor_hp, 0))
	flash = 0.12
	stumble = stun
	if dmg == 0:
		_main().on_thief_too_fast()
		return
	hp -= dmg
	if state == "windup":
		state = "run" if not cornered else "idle"
		state_t = 0.6
		throw_t = 1.2
	for i in dmg:
		_main().drop_book(global_position + Vector2(randf_range(-10, 10), -40))
	_main().on_thief_hurt(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(-facing * 160.0, -560.0)
	z_index = 40
	_main().on_thief_defeated(global_position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := float(facing)
	var running: bool = active and not dead and abs(velocity.x) > 40.0 and is_on_floor()
	var bob := sin(t * 18.0) * 2.0 if running else sin(t * 4.0) * 1.0
	var cloak := Color(0.38, 0.16, 0.5)
	if state == "windup" and int(t * 16.0) % 2 == 0:
		cloak = Color(0.85, 0.2, 0.3)
	var lean := 0.18 * f if running else 0.0
	if stumble > 0.0:
		lean = -0.35 * f
	draw_set_transform(Vector2(0, 28), lean, Vector2.ONE)

	# legs (running cycle)
	var s := sin(t * 18.0) * 9.0 if running else 0.0
	var dark := Color(0.15, 0.1, 0.12)
	draw_line(Vector2(-4, -12), Vector2(-4 + s, -1), dark, 6.0)
	draw_line(Vector2(4, -12), Vector2(4 - s, -1), dark, 6.0)
	draw_rect(Rect2(-8 + s, -4, 11, 5), dark)
	draw_rect(Rect2(-3 - s, -4, 11, 5), dark)

	# sack of stolen books, shrinking as books get knocked out
	var full := 0.55 + 0.45 * float(hp) / float(max_hp)
	var sack := Vector2(-f * 18.0, -36 + bob)
	for i in 4:
		if float(i) < full * 4.0:
			draw_rect(Rect2(sack.x - 12 + i * 6, sack.y - 22 * full + (i % 2) * 4, 6, 16), Color.from_hsv(i * 0.23, 0.7, 0.8))
	draw_circle(sack, 15.0 * full, Color(0.55, 0.42, 0.25))
	draw_circle(sack + Vector2(0, -9 * full), 8.0 * full, Color(0.55, 0.42, 0.25))

	# cloak, flapping behind him
	var flap := sin(t * 12.0) * 4.0
	var cloak_pts := PackedVector2Array()
	for v in [Vector2(-18, -10), Vector2(16, -10), Vector2(14, -44 + bob),
			Vector2(6, -62 + bob), Vector2(-14, -44 + bob), Vector2(-26 - flap, -16)]:
		cloak_pts.append(Vector2(v.x * f, v.y))
	draw_colored_polygon(cloak_pts, cloak)
	draw_rect(Rect2(-15, -24 + bob, 30, 4), Color(0.2, 0.12, 0.08))
	draw_rect(Rect2(-3, -25 + bob, 6, 6), Color(0.9, 0.75, 0.2))

	# hood and glowing eyes
	var face := Vector2(f * 5.0, -44 + bob)
	draw_circle(face, 10.0, Color(0.06, 0.03, 0.08))
	var eye := Color(1.0, 0.9, 0.2) if hp > max_hp / 2 else Color(1.0, 0.25, 0.2)
	if stumble > 0.0:
		draw_line(face + Vector2(-6, -3), face + Vector2(-2, 1), eye, 2.0)
		draw_line(face + Vector2(-6, 1), face + Vector2(-2, -3), eye, 2.0)
		draw_line(face + Vector2(2, -3), face + Vector2(6, 1), eye, 2.0)
		draw_line(face + Vector2(2, 1), face + Vector2(6, -3), eye, 2.0)
	else:
		draw_circle(face + Vector2(-3, -1), 2.3, eye)
		draw_circle(face + Vector2(4, -1), 2.3, eye)
		draw_arc(face + Vector2(1, 3), 4.0, 0.2, PI - 0.2, 8, eye.darkened(0.2), 1.5)

	# arm raised with a book while winding up a throw
	if state == "windup":
		var hand := Vector2(-f * 6.0, -66 + bob)
		draw_line(Vector2(0, -36 + bob), hand, cloak, 6.0)
		draw_rect(Rect2(hand.x - 7, hand.y - 12, 14, 12), Color(0.8, 0.25, 0.25))
	# taunting wave when he's way ahead and waiting for you
	elif active and not cornered and abs(velocity.x) < 30.0 and is_on_floor():
		var wave := sin(t * 10.0) * 6.0
		draw_line(Vector2(f * 8, -36 + bob), Vector2(f * 18 + wave, -58), cloak, 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
