extends Area2D
## Ink blobs thrown by the player, or books hurled by the Book Stealer.

var team := "player"   # "player" hurts enemies, "enemy" hurts the player
var kind := "ink"      # "ink", "book", "bit" (binary fired by the supercomputer), "rock" (meteor), "tablet",
                       # "bolt" (robot laser), "fist" (rocket fist) or "missile" (homing)
var vel := Vector2.ZERO
var grav := 0.0
var life := 2.5
var spin := 0.0
var color := Color(0.15, 0.2, 0.75)
var target = null   # missiles steer toward this
var homing := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if team == "player" else 2)
	z_index = 8
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0 if kind == "fist" else (10.0 if kind in ["book", "tablet", "rock"] else 7.0)
	cs.shape = c
	add_child(cs)
	if kind == "book":
		color = Color.from_hsv(randf(), 0.65, 0.85)
	elif kind == "bit":
		color = Color(0.4, 1.0, 0.55)
		spin = float(randi() % 2)   # which digit to show
	elif kind == "rock":
		color = Color(1.0, 0.5, 0.15)
	elif kind == "tablet":
		color = Color(0.62, 0.6, 0.56)
	elif kind == "bolt" or kind == "missile":
		color = Color(1.0, 0.25, 0.35)
	elif kind == "fist":
		color = Color(0.7, 0.72, 0.8)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if kind == "missile" and target != null and is_instance_valid(target) and homing > 0.0:
		homing -= delta
		var want: Vector2 = (target.global_position - global_position).normalized() * vel.length()
		vel = vel.lerp(want, 2.2 * delta)
	vel.y += grav * delta
	position += vel * delta
	if kind == "missile" and randf() < 0.5:
		get_tree().current_scene.burst(global_position - vel.normalized() * 10.0, Color(1.0, 0.7, 0.3), 1, 30)
	if kind == "book" or kind == "tablet":
		spin += delta * 12.0
	elif kind == "rock":
		spin += delta * 4.0
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if team == "player" and body.has_method("hit"):
		if body.dead:
			return
		body.hit(1)
	elif team == "enemy" and body.has_method("take_damage"):
		body.take_damage(1, global_position)
	get_tree().current_scene.burst(global_position, color, 8, 110)
	queue_free()


func _draw() -> void:
	if kind == "bit":
		draw_circle(Vector2.ZERO, 9.0, Color(color, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(-5, 6), "1" if spin > 0.5 else "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
	elif kind == "bolt":
		var dir := vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
		draw_line(-dir * 14.0, dir * 6.0, Color(color, 0.4), 8.0)
		draw_line(-dir * 12.0, dir * 5.0, color, 4.0)
		draw_line(-dir * 10.0, dir * 4.0, Color(1, 0.9, 0.9), 1.5)
	elif kind == "fist":
		var d := 1.0 if vel.x >= 0.0 else -1.0
		draw_colored_polygon(PackedVector2Array([Vector2(-d * 10, -6), Vector2(-d * 26, 0), Vector2(-d * 10, 6)]), Color(1.0, 0.6, 0.2, 0.8))
		draw_rect(Rect2(-10, -9, 20, 18), color)
		for i in 3:
			draw_line(Vector2(d * 4, -6 + i * 5), Vector2(d * 10, -6 + i * 5), color.darkened(0.4), 1.5)
		draw_rect(Rect2(-d * 12 - 3, -6, 6, 12), Color(0.95, 0.35, 0.85))
	elif kind == "missile":
		draw_set_transform(Vector2.ZERO, vel.angle(), Vector2.ONE)
		draw_rect(Rect2(-9, -3, 16, 6), Color(0.75, 0.77, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(7, -3), Vector2(12, 0), Vector2(7, 3)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -3), Vector2(-13, -6), Vector2(-6, -3)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, 3), Vector2(-13, 6), Vector2(-6, 3)]), color)
		draw_circle(Vector2(-11, 0), 3.0 + randf() * 2.0, Color(1.0, 0.8, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif kind == "rock":
		# flaming meteor with a trail pointing back the way it came
		var back := -vel.normalized() * 22.0 if vel.length() > 1.0 else Vector2(0, -22)
		var side := back.orthogonal().normalized() * 9.0
		draw_colored_polygon(PackedVector2Array([side, back, -side]), Color(1.0, 0.6, 0.15, 0.55))
		draw_colored_polygon(PackedVector2Array([side * 0.5, back * 0.7, -side * 0.5]), Color(1.0, 0.9, 0.4, 0.7))
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.22, 0.18))
		draw_circle(Vector2(-3, -3), 3.0, Color(0.5, 0.32, 0.25))
		draw_circle(Vector2(4, 2), 2.0, Color(1.0, 0.5, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif kind == "tablet":
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_rect(Rect2(-8, -11, 16, 22), color)
		draw_rect(Rect2(-8, -11, 16, 22), color.darkened(0.35), false, 1.5)
		for i in 3:
			draw_line(Vector2(-5, -6 + i * 5), Vector2(5, -6 + i * 5), color.darkened(0.4), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif kind == "ink":
		draw_circle(Vector2.ZERO, 7.0, color)
		draw_circle(Vector2(-vel.x * 0.012, 2), 4.0, color.darkened(0.2))
		draw_circle(Vector2(2, -2), 2.0, Color(0.6, 0.7, 1.0))
	else:
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_rect(Rect2(-10, -7, 20, 14), color)
		draw_rect(Rect2(-8, -5, 17, 10), Color(0.95, 0.92, 0.8))
		draw_rect(Rect2(-10, -7, 4, 14), color.darkened(0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
