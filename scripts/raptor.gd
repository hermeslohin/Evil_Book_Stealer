extends CharacterBody2D
## A little raptor. Patrols back and forth; when it spots you it crouches, then charges.
## Stomp it or ink it a few times.

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1400.0
const WALK := 70.0
const CHARGE := 260.0
const SIGHT := 280.0

var dir := -1
var hp := 2 + D.ENEMY_HP_BONUS
var dead := false
var t := 0.0
var flash := 0.0
var state := "walk"   # walk, crouch, charge, rest
var state_t := 0.0
var ray: RayCast2D
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	t = randf() * 10.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(44, 25)
	cs.shape = r
	cs.position = Vector2(0, -0.5)
	add_child(cs)
	ray = RayCast2D.new()
	ray.target_position = Vector2(0, 26)
	ray.collision_mask = 1
	add_child(ray)


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
	if player == null:
		player = get_tree().current_scene.player

	velocity.y = min(velocity.y + GRAVITY * delta, 900.0)
	state_t -= delta
	match state:
		"walk":
			velocity.x = dir * WALK * D.ENEMY_SPEED
			if player != null and player.alive:
				var d: Vector2 = player.global_position - global_position
				if abs(d.x) < SIGHT and abs(d.y) < 60.0 and sign(d.x) == dir:
					state = "crouch"
					state_t = 0.45
		"crouch":
			velocity.x = 0.0
			if state_t <= 0.0:
				state = "charge"
				state_t = 1.4
		"charge":
			velocity.x = dir * CHARGE * D.ENEMY_SPEED
			if state_t <= 0.0:
				state = "rest"
				state_t = 0.8
		"rest":
			velocity.x = 0.0
			if state_t <= 0.0:
				state = "walk"

	move_and_slide()
	if is_on_wall():
		dir = -dir
		if state == "charge":
			state = "rest"
			state_t = 0.8
	elif is_on_floor():
		ray.position = Vector2(dir * 18, 0)
		ray.force_raycast_update()
		if not ray.is_colliding():
			dir = -dir
			if state == "charge":
				state = "rest"
				state_t = 0.8
	queue_redraw()


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
	collision_mask = 0
	position.y += 6
	get_tree().current_scene.burst(global_position, Color(0.4, 0.75, 0.35), 12, 150)
	queue_redraw()


func _draw() -> void:
	var f := float(dir)
	var body := Color(0.35, 0.65, 0.3) if flash <= 0.0 else Color.WHITE
	if state == "crouch" and int(t * 16.0) % 2 == 0:
		body = Color(0.85, 0.4, 0.25)
	var low := 4.0 if state == "crouch" else 0.0
	var fast := state == "charge"
	var step := sin(t * (22.0 if fast else 12.0)) * (5.0 if fast else 3.0)
	# legs
	draw_line(Vector2(-4, 4 + low), Vector2(-4 + step, 12), body.darkened(0.25), 4.0)
	draw_line(Vector2(4, 4 + low), Vector2(4 - step, 12), body.darkened(0.25), 4.0)
	# tail
	draw_colored_polygon(PackedVector2Array([
		Vector2(-f * 6, -2 + low), Vector2(-f * 6, 6 + low), Vector2(-f * 22, -4 + low + sin(t * 8.0) * 2.0)]), body.darkened(0.1))
	# body
	draw_circle(Vector2(0, 2 + low), 9.0, body)
	# stripes
	for i in 3:
		draw_line(Vector2(-5 + i * 4, -5 + low), Vector2(-6 + i * 4, 1 + low), body.darkened(0.35), 2.0)
	# neck + head
	var head := Vector2(f * 12, -7 + low * 1.5)
	draw_line(Vector2(f * 5, 0 + low), head, body, 6.0)
	draw_circle(head, 6.0, body)
	draw_colored_polygon(PackedVector2Array([head + Vector2(0, -3), head + Vector2(f * 11, 0), head + Vector2(0, 4)]), body)
	# teeth + eye
	draw_line(head + Vector2(f * 3, 2), head + Vector2(f * 10, 1), Color(0.95, 0.95, 0.9), 1.5)
	draw_circle(head + Vector2(f * 2, -2), 2.0, Color(1.0, 0.9, 0.2))
	draw_circle(head + Vector2(f * 2.5, -2), 1.0, Color(0.1, 0.05, 0.05))
	# tiny arms
	draw_line(Vector2(f * 7, 3 + low), Vector2(f * 11, 6 + low), body.darkened(0.25), 2.0)
