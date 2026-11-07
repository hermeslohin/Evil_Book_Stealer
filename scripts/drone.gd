extends CharacterBody2D
## A flying security drone. Patrols back and forth, scans for intruders, and fires
## bits of binary at you. Stomp it or ink it once.

const ProjectileScript := preload("res://scripts/projectile.gd")
const PATROL := 90.0          # half-width of the patrol path
const RANGE := 340.0
const WINDUP := 0.5
const COOLDOWN := 1.8

var hp := 1
var dead := false
var dir := -1
var t := 0.0
var flash := 0.0
var home := Vector2.ZERO
var windup := 0.0
var cooldown := 1.2
var fall_v := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	z_index = 4
	t = randf() * 10.0
	home = position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 20)
	cs.shape = r
	add_child(cs)


func get_top_y() -> float:
	return global_position.y - 10.0


func _physics_process(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	if dead:
		fall_v += 900.0 * delta
		position.y += fall_v * delta
		rotation += 6.0 * delta
		modulate.a = move_toward(modulate.a, 0.0, 1.5 * delta)
		if modulate.a <= 0.0:
			queue_free()
		queue_redraw()
		return

	if player == null:
		player = get_tree().current_scene.player
	var spotted := false
	if player != null and player.alive:
		var d: Vector2 = player.global_position - global_position
		spotted = abs(d.x) < RANGE and abs(d.y) < 260.0

	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_fire()
			cooldown = COOLDOWN
	else:
		position.x += dir * 70.0 * delta
		if position.x < home.x - PATROL:
			dir = 1
		elif position.x > home.x + PATROL:
			dir = -1
		if spotted:
			cooldown -= delta
			if cooldown <= 0.0:
				windup = WINDUP
	position.y = home.y + sin(t * 2.5) * 8.0
	queue_redraw()


func _fire() -> void:
	if player == null or not player.alive:
		return
	var origin := global_position + Vector2(0, 10)
	var aim: Vector2 = (player.global_position - origin).normalized()
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "bit"
	p.vel = aim * 240.0
	p.life = 3.0
	p.position = origin
	get_parent().add_child(p)


func stomped(_by) -> void:
	_die()


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	get_tree().current_scene.burst(global_position, Color(0.5, 0.9, 1.0), 14, 170)


func _draw() -> void:
	var body := Color(0.55, 0.6, 0.72) if flash <= 0.0 else Color.WHITE
	var charge: float = 1.0 - clamp(windup / WINDUP, 0.0, 1.0) if windup > 0.0 else 0.0
	# propellers
	var spin := absf(sin(t * 40.0)) * 9.0 + 2.0
	draw_line(Vector2(-12, -9), Vector2(-12, -5), body.darkened(0.3), 2.0)
	draw_line(Vector2(12, -9), Vector2(12, -5), body.darkened(0.3), 2.0)
	draw_line(Vector2(-12 - spin, -10), Vector2(-12 + spin, -10), Color(0.8, 0.9, 1.0, 0.8), 2.0)
	draw_line(Vector2(12 - spin, -10), Vector2(12 + spin, -10), Color(0.8, 0.9, 1.0, 0.8), 2.0)
	# hull
	draw_rect(Rect2(-15, -5, 30, 10), body)
	draw_circle(Vector2(0, 2), 9.0, body.darkened(0.15))
	# scanning eye
	var eye_col := Color(1.0, 0.25, 0.3).lerp(Color(1.0, 0.9, 0.3), charge)
	draw_circle(Vector2(0, 3), 5.5, Color(0.08, 0.05, 0.1))
	draw_circle(Vector2(sin(t * 3.0) * 2.0, 3), 3.0 + charge * 1.5, eye_col)
	# scan cone when it's watching for you
	if not dead and windup <= 0.0:
		var sx := sin(t * 1.7) * 26.0
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 8), Vector2(3, 8), Vector2(sx + 16, 70), Vector2(sx - 16, 70)]),
			Color(1.0, 0.3, 0.3, 0.08))
