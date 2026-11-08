extends CharacterBody2D
## An ink-squirting squid. Stays put, spots you from afar, winds up, and lobs
## blobs of ink at you. Stomp it or ink it back (two hits).

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1400.0
const ProjectileScript := preload("res://scripts/projectile.gd")
const INK_COLOR := Color(0.12, 0.05, 0.22)
const INK_GRAVITY := 600.0

const RANGE := 360.0          # starts attacking inside this horizontal distance
const RANGE_Y := 200.0
const WINDUP := 0.55          # telegraph time before each shot
const COOLDOWN := 1.6         # pause between volleys

var hp := 2 + D.ENEMY_HP_BONUS
var dead := false
var dir := -1
var t := 0.0
var flash := 0.0
var windup := 0.0             # >0 while charging a shot
var cooldown := 1.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	t = randf() * 10.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 25)
	cs.shape = r
	cs.position = Vector2(0, -0.5)
	add_child(cs)


func get_top_y() -> float:
	return global_position.y - 13.0


func _physics_process(delta: float) -> void:
	delta *= D.ENEMY_TEMPO
	t += delta
	flash = max(flash - delta, 0.0)
	if dead:
		scale.y = move_toward(scale.y, 0.2, 4.0 * delta)
		modulate.a = move_toward(modulate.a, 0.0, 2.0 * delta)
		if modulate.a <= 0.0:
			queue_free()
		return

	velocity.y = min(velocity.y + GRAVITY * delta, 900.0)
	velocity.x = 0.0
	move_and_slide()

	if player == null:
		player = get_tree().current_scene.player
	if player != null and player.alive:
		var d: Vector2 = player.global_position - global_position
		if abs(d.x) > 4.0:
			dir = 1 if d.x > 0.0 else -1
		var in_range: bool = abs(d.x) < RANGE and abs(d.y) < RANGE_Y
		if windup > 0.0:
			windup -= delta
			if windup <= 0.0:
				_fire()
				cooldown = COOLDOWN
		elif in_range:
			cooldown -= delta
			if cooldown <= 0.0:
				windup = WINDUP
		else:
			cooldown = max(cooldown, 0.4)
	queue_redraw()


func _fire() -> void:
	if player == null or not player.alive:
		return
	var origin := global_position + Vector2(dir * 10.0, -12.0)
	var target: Vector2 = player.global_position
	# Lob the blob on an arc that reaches the player's current position.
	var flight: float = clamp(abs(target.x - origin.x) / 320.0, 0.45, 0.9)
	var vx: float = (target.x - origin.x) / flight
	var vy: float = (target.y - origin.y) / flight - 0.5 * INK_GRAVITY * flight
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "ink"
	p.color = INK_COLOR
	p.vel = Vector2(vx, vy)
	p.grav = INK_GRAVITY
	p.life = 3.0
	p.position = origin
	get_parent().add_child(p)
	get_tree().current_scene.burst(origin, INK_COLOR, 6, 90)


func stomped(_by) -> void:
	_die()


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	windup = 0.0
	cooldown = max(cooldown, 0.5)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	position.y += 8
	get_tree().current_scene.burst(global_position, INK_COLOR.lightened(0.15), 16, 170)
	queue_redraw()


func _draw() -> void:
	var f := float(dir)
	var charge: float = 1.0 - clamp(windup / WINDUP, 0.0, 1.0) if windup > 0.0 else 0.0
	var body := Color(0.45, 0.25, 0.7) if flash <= 0.0 else Color.WHITE
	if windup > 0.0 and flash <= 0.0:
		body = body.lerp(Color(0.85, 0.3, 0.55), charge)   # blushes red before shooting
	var bob := sin(t * 3.0) * 1.5
	var puff := 1.0 + charge * 0.25                         # swells up as it charges

	# tentacles wiggling along the floor
	for i in range(4):
		var x := -10.0 + i * 6.7
		var w := sin(t * 6.0 + i * 1.3) * 2.5
		draw_line(Vector2(x, 4), Vector2(x + w, 12), body.darkened(0.2), 4.0)
	# mantle (head)
	draw_circle(Vector2(-f * 2.0, -2.0 + bob), 11.0 * puff, body)
	draw_circle(Vector2(-f * 5.0, -8.0 + bob), 6.0 * puff, body.lightened(0.1))
	# eyes
	var eye := Vector2(f * 4.0, -3.0 + bob)
	draw_circle(eye + Vector2(-5, 0), 3.6, Color.WHITE)
	draw_circle(eye + Vector2(4, 0), 3.6, Color.WHITE)
	draw_circle(eye + Vector2(-5 + f * 1.5, 0), 1.7, Color(0.1, 0.05, 0.15))
	draw_circle(eye + Vector2(4 + f * 1.5, 0), 1.7, Color(0.1, 0.05, 0.15))
	# angry brow
	draw_line(eye + Vector2(-9, -5 - f * 1.5), eye + Vector2(-1, -5 + f * 1.5), Color(0.1, 0.05, 0.15), 2.0)
	draw_line(eye + Vector2(0, -5 + f * 1.5), eye + Vector2(8, -5 - f * 1.5), Color(0.1, 0.05, 0.15), 2.0)
	# funnel/mouth that glows with ink while charging
	var mouth := Vector2(f * 11.0, 3.0 + bob)
	draw_circle(mouth, 3.5, INK_COLOR)
	if windup > 0.0:
		draw_circle(mouth + Vector2(f * 3.0, -1.0), 2.0 + charge * 5.0, INK_COLOR)
		draw_circle(mouth + Vector2(f * 3.0 - 1.0, -2.0), 1.0 + charge, Color(0.6, 0.5, 0.9))
