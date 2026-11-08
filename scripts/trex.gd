extends CharacterBody2D
## Level 6 boss: the Evil Book Stealer riding a T-Rex he tamed in the past.
## The T-Rex charges (and gets dizzy when it smacks the wall), roars to shake meteors loose,
## and stomps across the arena; the thief hurls stone tablets from the saddle.
## Stomp its head (2 damage) or hit it with ink (1 damage). Both count double while it's dizzy.

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1500.0
const ProjectileScript := preload("res://scripts/projectile.gd")

var max_hp := roundi(22 * D.BOSS_HP)
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
var rocks_left := 0
var rock_t := 0.0
var dash_dir := 1
var last_attack := -1
var min_x := 0.0
var max_x := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(100, 81)
	cs.shape = r
	cs.position = Vector2(0, -9.5)
	add_child(cs)


func _main():
	return get_tree().current_scene


func get_top_y() -> float:
	return global_position.y - 50.0


func activate(p) -> void:
	player = p
	active = true
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
		velocity.y += GRAVITY * delta
		position += velocity * delta
		rotation += 2.5 * delta
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
	var mult := 1.3 if _enraged() else 1.0

	match state:
		"taunt", "idle":
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
					_throw_tablet()
					throws_left -= 1
					throw_t = 0.42 / mult
				else:
					_set_state("idle", 0.9 / mult)
		"roar":
			velocity.x = 0.0
			_main().shake(4)
			rock_t -= delta
			if rock_t <= 0.0 and rocks_left > 0:
				rocks_left -= 1
				rock_t = 0.22 / mult
				var x := randf_range(min_x, max_x)
				if rocks_left % 3 == 0 and player:
					x = player.global_position.x   # every third one aims right at you
				_main().spawn_meteor(x)
			if state_t <= 0.0:
				_set_state("idle", 0.8 / mult)
		"hop_windup":
			velocity.x = 0.0
			_face_player()
			if state_t <= 0.0:
				var dx: float = player.global_position.x - global_position.x
				velocity.y = -680.0
				velocity.x = clamp(dx / 0.9, -480.0, 480.0)
				_set_state("hop", 3.0)
		"hop":
			if is_on_floor() and state_t < 2.9:
				velocity.x = 0.0
				_main().shake(12)
				_main().burst(global_position + Vector2(0, 30), Color(0.6, 0.5, 0.4), 18, 220)
				if _enraged():
					_shockwaves()
				_set_state("idle", 0.8 / mult)
		"charge_windup":
			velocity.x = 0.0
			if state_t <= 0.0:
				dash_dir = facing
				_set_state("charge", 2.0)
		"charge":
			velocity.x = dash_dir * 420.0 * mult
			if (is_on_wall() and state_t < 1.9) or state_t <= 0.0:
				velocity.x = 0.0
				_main().shake(12)
				_main().burst(global_position + Vector2(dash_dir * 36, -10), Color(0.6, 0.55, 0.5), 16, 200)
				_set_state("dizzy", 2.0)
		"dizzy":
			velocity.x = 0.0
			if state_t <= 0.0:
				_set_state("idle", 0.3)

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
			throws_left = 5 if _enraged() else 3
			throw_t = 0.4
			_set_state("throw", 99.0)
		1:
			_face_player()
			_set_state("charge_windup", 0.9)
		2:
			rocks_left = 9 if _enraged() else 6
			rock_t = 0.4
			_set_state("roar", 2.2)
			_main().hud.banner("ROOOAAAR!", Color(1.0, 0.55, 0.3))
		3:
			_set_state("hop_windup", 0.5)


func _throw_tablet() -> void:
	if not player:
		return
	var origin := global_position + Vector2(-facing * 4, -64)
	var target: Vector2 = player.global_position + Vector2(player.velocity.x * 0.25, 0)
	var dx := target.x - origin.x
	var flight: float = clamp(abs(dx) / 360.0, 0.5, 1.2)
	var g := 900.0
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "tablet"
	p.grav = g
	p.vel = Vector2(dx / flight * randf_range(0.85, 1.15),
		(target.y - origin.y - 0.5 * g * flight * flight) / flight)
	p.position = origin
	get_parent().add_child(p)


func _shockwaves() -> void:
	for d in [-1, 1]:
		var p = ProjectileScript.new()
		p.team = "enemy"
		p.kind = "rock"
		p.grav = 0.0
		p.vel = Vector2(d * 300.0, 0)
		p.position = global_position + Vector2(d * 40, 20)
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
	hp = max(hp - (4 if state == "dizzy" else 2), 0)
	flash = 0.15
	_main().on_boss_hurt(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(-facing * 140.0, -520.0)
	z_index = 40
	_main().on_boss_defeated(global_position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := float(facing)
	var skin := Color(0.4, 0.55, 0.3)
	var telegraph := state in ["hop_windup", "charge_windup"]
	if telegraph and int(t * 16.0) % 2 == 0:
		skin = Color(0.8, 0.3, 0.25)
	if _enraged() and active:
		draw_circle(Vector2(0, -10), 56.0 + sin(t * 8.0) * 3.0, Color(1.0, 0.35, 0.2, 0.13))
	var running := state == "charge"
	var step := sin(t * (18.0 if running else 4.0)) * (6.0 if running else 1.0)
	var dizzy := state == "dizzy"
	var roaring := state == "roar" or state == "charge_windup"
	var head_drop := 14.0 if dizzy else 0.0

	# tail
	draw_colored_polygon(PackedVector2Array([
		Vector2(-f * 20, -12), Vector2(-f * 20, 10), Vector2(-f * 62, -6 + sin(t * 3.0) * 4.0)]), skin.darkened(0.1))
	# back leg + front leg
	draw_rect(Rect2(-14 - 6 + step, 10, 14, 20), skin.darkened(0.25))
	draw_rect(Rect2(6 - step, 10, 14, 20), skin.darkened(0.15))
	draw_rect(Rect2(-14 - 8 + step, 26, 18, 5), skin.darkened(0.4))
	draw_rect(Rect2(4 - step, 26, 18, 5), skin.darkened(0.35))
	# body
	draw_circle(Vector2(0, -2), 26.0, skin)
	draw_circle(Vector2(f * 6, 6), 18.0, Color(0.75, 0.75, 0.5))   # belly
	# back spikes
	for i in 4:
		var sx := -f * (i * 9.0 - 6.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, -24 + i * 2), Vector2(sx + 4, -24 + i * 2), Vector2(sx, -33 + i * 2)]), skin.darkened(0.35))
	# tiny arms (very important)
	draw_line(Vector2(f * 20, 0), Vector2(f * 28, 8), skin.darkened(0.2), 4.0)
	# neck + big head
	var head := Vector2(f * 34, -24 + head_drop)
	draw_line(Vector2(f * 16, -12), head, skin, 16.0)
	draw_rect(Rect2(head.x - 14 + f * 4, head.y - 12, 28, 18), skin)
	var jaw_open := 10.0 if roaring else (4.0 if state == "throw" else 2.0)
	draw_rect(Rect2(head.x - 12 + f * 6, head.y + 6, 26, 6 + jaw_open * 0.3), skin.darkened(0.1))
	if roaring:
		draw_rect(Rect2(head.x - 10 + f * 8, head.y + 4, 22, jaw_open), Color(0.55, 0.12, 0.15))
	# teeth
	for i in 5:
		var tx := head.x - 8 + f * 6 + i * 4.5
		draw_colored_polygon(PackedVector2Array([Vector2(tx, head.y + 5), Vector2(tx + 3, head.y + 5), Vector2(tx + 1.5, head.y + 9)]), Color(0.97, 0.95, 0.88))
	# eye
	var eye := Vector2(head.x + f * 2, head.y - 5)
	if dizzy:
		draw_line(eye + Vector2(-3, -3), eye + Vector2(3, 3), Color(0.1, 0.05, 0.05), 2.0)
		draw_line(eye + Vector2(-3, 3), eye + Vector2(3, -3), Color(0.1, 0.05, 0.05), 2.0)
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			draw_circle(head + Vector2(cos(a) * 18.0, -24 + sin(a) * 5.0), 3.0, Color(1, 1, 0.5))
	else:
		draw_circle(eye, 4.0, Color(1.0, 0.85, 0.2) if not _enraged() else Color(1.0, 0.3, 0.2))
		draw_circle(eye + Vector2(f, 0), 2.0, Color(0.1, 0.05, 0.05))
	draw_line(eye + Vector2(-f * 5, -6), eye + Vector2(f * 5, -4), skin.darkened(0.4), 3.0)   # angry brow

	# the Book Stealer in the saddle, wearing a caveman pelt over his cloak
	var rider := Vector2(-f * 4, -38 + sin(t * 4.0) * 1.5)
	draw_rect(Rect2(rider.x - 14, rider.y + 8, 28, 6), Color(0.5, 0.3, 0.15))   # saddle
	draw_colored_polygon(PackedVector2Array([
		rider + Vector2(-12, 12), rider + Vector2(12, 12), rider + Vector2(9, -10),
		rider + Vector2(f * 4, -22), rider + Vector2(-9, -10)]), Color(0.38, 0.16, 0.5))
	# leopard-spot pelt across the chest
	draw_colored_polygon(PackedVector2Array([rider + Vector2(-11, 0), rider + Vector2(11, -6), rider + Vector2(11, 2), rider + Vector2(-11, 8)]), Color(0.85, 0.6, 0.25))
	draw_circle(rider + Vector2(-5, 2), 1.5, Color(0.35, 0.2, 0.1))
	draw_circle(rider + Vector2(4, -1), 1.5, Color(0.35, 0.2, 0.1))
	var face := rider + Vector2(f * 3, -11)
	draw_circle(face, 7.0, Color(0.06, 0.03, 0.08))
	draw_circle(face + Vector2(-2.5, -1), 1.8, Color(1.0, 0.9, 0.2))
	draw_circle(face + Vector2(3, -1), 1.8, Color(1.0, 0.9, 0.2))
	# bone in his hood
	draw_line(face + Vector2(-6, -9), face + Vector2(6, -11), Color(0.95, 0.92, 0.85), 2.5)
	draw_circle(face + Vector2(-6, -9), 2.0, Color(0.95, 0.92, 0.85))
	draw_circle(face + Vector2(6, -11), 2.0, Color(0.95, 0.92, 0.85))
	if state == "throw":
		var hand := rider + Vector2(f * 16, -18)
		draw_line(rider + Vector2(f * 6, -4), hand, Color(0.38, 0.16, 0.5), 5.0)
		draw_rect(Rect2(hand.x - 6, hand.y - 12, 12, 14), Color(0.6, 0.58, 0.55))
