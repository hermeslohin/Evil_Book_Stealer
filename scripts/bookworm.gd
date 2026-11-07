extends CharacterBody2D
## A bookworm henchman that patrols back and forth. Stomp it or ink it twice.

const GRAVITY := 1400.0

var dir := -1
var speed := 60.0
var hp := 2
var dead := false
var t := 0.0
var flash := 0.0
var ray: RayCast2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	t = randf() * 10.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 18)
	cs.shape = r
	add_child(cs)
	ray = RayCast2D.new()
	ray.target_position = Vector2(0, 22)
	ray.collision_mask = 1
	add_child(ray)


func get_top_y() -> float:
	return global_position.y - 9.0


func _physics_process(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	if dead:
		scale.y = move_toward(scale.y, 0.2, 4.0 * delta)
		modulate.a = move_toward(modulate.a, 0.0, 2.0 * delta)
		if modulate.a <= 0.0:
			queue_free()
		return
	velocity.y = min(velocity.y + GRAVITY * delta, 900.0)
	velocity.x = dir * speed
	move_and_slide()
	if is_on_wall():
		dir = -dir
	elif is_on_floor():
		ray.position = Vector2(dir * 16, 0)
		ray.force_raycast_update()
		if not ray.is_colliding():
			dir = -dir
	queue_redraw()


func stomped(_by) -> void:
	_die()


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	dir = -dir
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	position.y += 6
	get_tree().current_scene.burst(global_position, Color(0.5, 0.85, 0.3), 12, 150)
	queue_redraw()


func _draw() -> void:
	var body := Color(0.45, 0.8, 0.3) if flash <= 0.0 else Color.WHITE
	var f := float(dir)
	# segments wiggle along the body
	for i in range(4):
		var x := -f * (i * 7.0 - 4.0)
		var y := 3.0 + sin(t * 10.0 + i) * 2.0
		draw_circle(Vector2(x, y), 6.5 - i * 0.6, body.darkened(i * 0.08))
	# head
	var head := Vector2(f * 9.0, -1.0)
	draw_circle(head, 8.0, body)
	# villain mask
	draw_rect(Rect2(head.x - 7, head.y - 4, 14, 5), Color(0.1, 0.1, 0.15))
	draw_circle(head + Vector2(f * 3.0, -1.5), 1.8, Color.WHITE)
	draw_circle(head + Vector2(-f * 2.0, -1.5), 1.8, Color.WHITE)
	# tiny stolen page in mouth
	draw_rect(Rect2(head.x + f * 5.0 - 3, head.y + 3, 6, 5), Color(0.95, 0.93, 0.85))
