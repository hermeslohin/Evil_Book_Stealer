extends CharacterBody2D
## The Evil Book Stealer. Hurls stolen books, leaps at you, and charges across the arena.
## Stomp his head (2 damage) or hit him with ink (1 damage, 2 while he's dizzy).

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1500.0
const ProjectileScript := preload("res://scripts/projectile.gd")

var max_hp := roundi(18 * D.BOSS_HP)
var hp := max_hp
var active := false
var dead := false
var state := "idle"
var state_t := 0.0
var facing := -1
var flash := 0.0
var stomp_cd := 0.0
var t := 0.0
var throws_left := 0
var throw_t := 0.0
var dash_dir := 1
var last_attack := -1
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(70, 62)
	cs.shape = r
	cs.position = Vector2(0, -1)
	add_child(cs)


func _main():
	return get_tree().current_scene


func get_top_y() -> float:
	return global_position.y - 32.0


func activate(p) -> void:
	player = p
	active = true
	_set_state("taunt", 1.4)


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
		velocity.y += GRAVITY * delta
		position += velocity * delta
		rotation += 4.0 * delta
		if position.y > 2000:
			queue_free()
		queue_redraw()
		return

	velocity.y = min(velocity.y + GRAVITY * delta, 1000.0)
	if not active:
		move_and_slide()
		queue_redraw()
		return

	state_t -= delta
	var mult := 1.35 if _enraged() else 1.0

	match state:
		"taunt":
			velocity.x = 0.0
			_face_player()
			if state_t <= 0.0:
				_choose_attack()
		"idle":
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			_face_player()
			if state_t <= 0.0:
				_choose_attack()
		"throw":
			velocity.x = 0.0
			_face_player()
			throw_t -= delta
			if throw_t <= 0.0:
				if throws_left > 0:
					_throw_book()
					throws_left -= 1
					throw_t = 0.38 / mult
				else:
					_set_state("idle", 0.9 / mult)
		"leap_windup":
			velocity.x = 0.0
			_face_player()
			if state_t <= 0.0:
				var dx: float = player.global_position.x - global_position.x
				velocity.y = -720.0
				velocity.x = clamp(dx / 0.96, -520.0, 520.0)
				_set_state("leap", 3.0)
		"leap":
			if is_on_floor() and state_t < 2.9:
				velocity.x = 0.0
				_main().shake(10)
				_main().burst(global_position + Vector2(0, 30), Color(0.6, 0.5, 0.45), 16, 200)
				if _enraged():
					_shockwaves()
				_set_state("idle", 0.8 / mult)
		"dash_windup":
			velocity.x = 0.0
			if state_t <= 0.0:
				dash_dir = facing
				_set_state("dash", 1.6)
		"dash":
			velocity.x = dash_dir * 500.0 * mult
			if (is_on_wall() and state_t < 1.5) or state_t <= 0.0:
				velocity.x = 0.0
				_main().shake(9)
				_set_state("dizzy", 1.5)
		"dizzy":
			velocity.x = 0.0
			if state_t <= 0.0:
				_set_state("idle", 0.3)

	move_and_slide()
	queue_redraw()


func _choose_attack() -> void:
	var r := randi() % 3
	if r == last_attack:
		r = (r + 1) % 3
	last_attack = r
	match r:
		0:
			throws_left = 5 if _enraged() else 3
			throw_t = 0.35
			_set_state("throw", 99.0)
		1:
			_set_state("leap_windup", 0.5)
		2:
			_face_player()
			_set_state("dash_windup", 0.8)


func _throw_book() -> void:
	if not player:
		return
	var origin := global_position + Vector2(facing * 20, -34)
	var target: Vector2 = player.global_position + Vector2(player.velocity.x * 0.25, 0)
	var dx := target.x - origin.x
	var flight: float = clamp(abs(dx) / 380.0, 0.45, 1.2)
	var g := 900.0
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "book"
	p.grav = g
	p.vel = Vector2(dx / flight * randf_range(0.85, 1.15),
		(target.y - origin.y - 0.5 * g * flight * flight) / flight)
	p.position = origin
	get_parent().add_child(p)


func _shockwaves() -> void:
	for d in [-1, 1]:
		var p = ProjectileScript.new()
		p.team = "enemy"
		p.kind = "book"
		p.grav = 0.0
		p.vel = Vector2(d * 320.0, 0)
		p.position = global_position + Vector2(d * 30, 18)
		get_parent().add_child(p)


func hit(dmg: int) -> void:
	if dead or not active:
		return
	if state == "dizzy":
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
	hp = max(hp - 2, 0)
	flash = 0.15
	_main().on_boss_hurt(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(-facing * 160.0, -560.0)
	z_index = 40
	_main().on_boss_defeated(global_position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := float(facing)
	var bob := sin(t * 4.0) * 1.5
	var cloak := Color(0.38, 0.16, 0.5)
	var telegraph := state in ["leap_windup", "dash_windup"]
	if telegraph and int(t * 16.0) % 2 == 0:
		cloak = Color(0.85, 0.2, 0.3)
	if _enraged() and active:
		draw_circle(Vector2(0, 0), 38.0 + sin(t * 8.0) * 3.0, Color(0.9, 0.2, 0.4, 0.15))

	# sack of stolen books on his back
	var sack := Vector2(-f * 20.0, -6 + bob)
	for i in 4:
		var bx := sack.x - 12 + i * 6
		draw_rect(Rect2(bx, sack.y - 24 + (i % 2) * 4, 6, 16), Color.from_hsv(i * 0.23, 0.7, 0.8))
	draw_circle(sack, 16.0, Color(0.55, 0.42, 0.25))
	draw_circle(sack + Vector2(0, -10), 9.0, Color(0.55, 0.42, 0.25))
	draw_line(sack + Vector2(-6, -12), sack + Vector2(6, -12), Color(0.35, 0.25, 0.12), 3.0)

	# feet
	var step := sin(t * 16.0) * 4.0 if state == "dash" else 0.0
	draw_rect(Rect2(-14 + step, 24, 12, 6), Color(0.15, 0.1, 0.12))
	draw_rect(Rect2(2 - step, 24, 12, 6), Color(0.15, 0.1, 0.12))

	# cloak body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, 26), Vector2(24, 26), Vector2(18, -16 + bob),
		Vector2(f * 8, -36 + bob), Vector2(-18, -16 + bob)]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 26), Vector2(6, 26), Vector2(3, 0 + bob), Vector2(-3, 0 + bob)]), cloak.darkened(0.3))
	# belt
	draw_rect(Rect2(-21, 6 + bob, 42, 5), Color(0.2, 0.12, 0.08))
	draw_rect(Rect2(-4, 5 + bob, 8, 7), Color(0.9, 0.75, 0.2))

	# hood opening and glowing eyes
	var face := Vector2(f * 5.0, -16 + bob)
	draw_circle(face, 12.0, Color(0.06, 0.03, 0.08))
	var eye := Color(1.0, 0.9, 0.2) if not _enraged() else Color(1.0, 0.25, 0.2)
	if state == "dizzy":
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 18.0, -44 + sin(a) * 5.0), 3.0, Color(1, 1, 0.5))
		draw_line(face + Vector2(-7, -4), face + Vector2(-2, 1), eye, 2.0)
		draw_line(face + Vector2(-7, 1), face + Vector2(-2, -4), eye, 2.0)
		draw_line(face + Vector2(2, -4), face + Vector2(7, 1), eye, 2.0)
		draw_line(face + Vector2(2, 1), face + Vector2(7, -4), eye, 2.0)
	else:
		draw_circle(face + Vector2(-4, -1), 2.6, eye)
		draw_circle(face + Vector2(5, -1), 2.6, eye)
		# sinister grin
		draw_arc(face + Vector2(1, 3), 5.0, 0.2, PI - 0.2, 8, eye.darkened(0.2), 1.5)

	# arm holding a book while throwing
	if state == "throw":
		var hand := Vector2(f * 24.0, -24 + bob)
		draw_line(Vector2(f * 12, -6 + bob), hand, cloak, 7.0)
		draw_rect(Rect2(hand.x - 7, hand.y - 12, 14, 12), Color(0.8, 0.25, 0.25))
