extends CharacterBody2D
## The Evil Book Stealer's supercomputer core: a giant glowing eye of circuitry.
## It's shielded until you hack one of the chamber's terminals. Then it's open for a
## few seconds: ink it or stomp it! Each hit spills e-books. It gets angrier as it breaks.

const ProjectileScript := preload("res://scripts/projectile.gd")
const DroneScript := preload("res://scripts/drone.gd")
const SHIELD_DOWN_TIME := 5.0
const HITS_PER_WINDOW := 2
const BOOKS_PER_HIT := 2

var max_hp := 6
var hp := 6
var active := false
var dead := false
var shielded := true
var shield_t := 0.0          # time left with the shield down
var window_hits := 0
var t := 0.0
var flash := 0.0
var fire_t := 2.0
var drone_t := 8.0
var dir := 1
var min_x := 0.0
var max_x := 0.0
var home_y := 0.0
var base_y := 0.0
var stomp_cd := 0.0
var death_t := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	z_index = 4
	home_y = position.y
	base_y = home_y
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 26.0
	cs.shape = c
	add_child(cs)


func _main():
	return get_tree().current_scene


func get_top_y() -> float:
	return global_position.y - 26.0


func activate(p) -> void:
	player = p
	active = true
	fire_t = 1.5


func _rage() -> int:
	# 0, 1, 2 as it takes damage
	return clampi((max_hp - hp) / HITS_PER_WINDOW, 0, 2)


## Called when a chamber terminal is hacked. Returns true if the shield actually dropped.
func drop_shield() -> bool:
	if dead or not shielded:
		return false
	shielded = false
	shield_t = SHIELD_DOWN_TIME
	window_hits = 0
	flash = 0.3
	return true


func _raise_shield() -> void:
	shielded = true
	shield_t = 0.0
	_main().on_core_shield_up()


func _physics_process(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	stomp_cd = max(stomp_cd - delta, 0.0)
	if dead:
		death_t += delta
		position += Vector2(randf_range(-3, 3), randf_range(-3, 3))
		if fmod(death_t, 0.15) < delta:
			_main().burst(global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
				Color.from_hsv(randf_range(0.3, 0.6), 0.6, 1.0), 6, 200)
		modulate.a = clampf(1.5 - death_t * 0.6, 0.0, 1.0)
		queue_redraw()
		return
	if not active:
		queue_redraw()
		return

	# drift side to side, faster when angry
	var speed := 50.0 + 30.0 * _rage()
	if not shielded:
		speed *= 0.4   # it's stunned while exposed
	position.x += dir * speed * delta
	if position.x < min_x:
		dir = 1
	elif position.x > max_x:
		dir = -1
	# while exposed it sinks down within reach of your ink
	base_y = move_toward(base_y, home_y + (0.0 if shielded else 140.0), 260.0 * delta)
	position.y = base_y + sin(t * 1.8) * (22.0 if shielded else 8.0)

	if not shielded:
		shield_t -= delta
		if shield_t <= 0.0:
			_raise_shield()
	else:
		fire_t -= delta
		if fire_t <= 0.0:
			_fire_spread()
			fire_t = 2.0 - 0.45 * _rage()
		if _rage() >= 1:
			drone_t -= delta
			if drone_t <= 0.0:
				drone_t = 9.0
				_spawn_drone()
	queue_redraw()


func _fire_spread() -> void:
	if player == null or not player.alive:
		return
	var origin := global_position + Vector2(0, 14)
	var aim: Vector2 = (player.global_position - origin).normalized()
	var count := 3 + _rage() * 2
	for i in count:
		var ang := (i - (count - 1) / 2.0) * 0.22
		var p = ProjectileScript.new()
		p.team = "enemy"
		p.kind = "bit"
		p.vel = aim.rotated(ang) * 230.0
		p.life = 3.5
		p.position = origin
		get_parent().add_child(p)
	_main().burst(origin, Color(0.4, 1.0, 0.6), 8, 120)


func _spawn_drone() -> void:
	var alive_drones := 0
	for n in get_parent().get_children():
		if n.get_script() == DroneScript and not n.dead:
			alive_drones += 1
	if alive_drones >= 2:
		return
	var d = DroneScript.new()
	d.position = global_position + Vector2(-dir * 60.0, 40.0)
	get_parent().add_child(d)
	_main().burst(d.position, Color(0.5, 0.9, 1.0), 10, 140)


func hit(dmg: int) -> void:
	if dead or not active:
		return
	if shielded:
		_main().burst(global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(0.5, 0.8, 1.0), 5, 120)
		return
	_hurt(dmg)


func stomped(by) -> void:
	if dead or not active or stomp_cd > 0.0:
		return
	stomp_cd = 0.4
	if shielded:
		return   # bounces you off harmlessly
	_hurt(1)


func _hurt(dmg: int) -> void:
	hp = max(hp - dmg, 0)
	flash = 0.15
	window_hits += dmg
	for i in dmg * BOOKS_PER_HIT:
		_main().drop_book(global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)))
	_main().on_boss_hurt(hp, max_hp)
	if hp <= 0:
		_die()
	elif window_hits >= HITS_PER_WINDOW:
		_raise_shield()


func _die() -> void:
	dead = true
	collision_layer = 0
	_main().on_boss_defeated(global_position)


func _draw() -> void:
	var rage := _rage()
	var base := Color(0.1, 0.12, 0.2)
	var glow: Color = [Color(0.3, 0.9, 1.0), Color(1.0, 0.75, 0.25), Color(1.0, 0.3, 0.35)][rage]
	if flash > 0.0:
		glow = Color.WHITE
	# cables trailing up to the ceiling
	for i in 3:
		var x := -16.0 + i * 16.0
		draw_line(Vector2(x, -24), Vector2(x * 1.6 + sin(t * 2.0 + i) * 6.0, -200), Color(0.15, 0.16, 0.25), 4.0)
	# outer casing
	for i in 8:
		var ang := t * 0.6 + i * TAU / 8.0
		var p := Vector2(cos(ang), sin(ang)) * 30.0
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(0.22, 0.24, 0.34))
	draw_circle(Vector2.ZERO, 26.0, base)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, glow.darkened(0.2), 2.0)
	# the eye
	var look := Vector2.ZERO
	if player:
		look = (player.global_position - global_position).normalized() * 6.0
	draw_circle(Vector2.ZERO, 17.0, Color(0.03, 0.03, 0.07))
	draw_circle(look, 9.0 + sin(t * 5.0) * 1.0, glow)
	draw_circle(look, 4.0, Color(0.03, 0.03, 0.07))
	draw_circle(look + Vector2(-3, -3), 2.0, Color(1, 1, 1, 0.8))
	# little book icon on the casing: it's full of stolen e-books!
	draw_rect(Rect2(-6, 18, 12, 6), glow.darkened(0.3))
	# shield bubble
	if shielded and not dead:
		var a := 0.25 + 0.1 * sin(t * 4.0)
		draw_circle(Vector2.ZERO, 44.0, Color(0.3, 0.6, 1.0, a * 0.4))
		draw_arc(Vector2.ZERO, 44.0, 0, TAU, 40, Color(0.5, 0.8, 1.0, a + 0.3), 2.5)
		for i in 6:
			var ang := t * 1.2 + i * TAU / 6.0
			draw_arc(Vector2.ZERO, 44.0, ang, ang + 0.4, 6, Color(0.8, 0.95, 1.0, 0.8), 3.0)
	elif not dead:
		# exposed: countdown ring
		var frac := clampf(shield_t / SHIELD_DOWN_TIME, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 40.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(0.4, 1.0, 0.6, 0.9), 3.0)
