extends Area2D
## Ink blobs thrown by the player, or books hurled by the Book Stealer.

var team := "player"   # "player" hurts enemies, "enemy" hurts the player
var kind := "ink"      # "ink", "book" or "bit" (binary fired by the supercomputer)
var vel := Vector2.ZERO
var grav := 0.0
var life := 2.5
var spin := 0.0
var color := Color(0.15, 0.2, 0.75)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if team == "player" else 2)
	z_index = 8
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0 if kind == "book" else 7.0
	cs.shape = c
	add_child(cs)
	if kind == "book":
		color = Color.from_hsv(randf(), 0.65, 0.85)
	elif kind == "bit":
		color = Color(0.4, 1.0, 0.55)
		spin = float(randi() % 2)   # which digit to show
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	vel.y += grav * delta
	position += vel * delta
	if kind == "book":
		spin += delta * 12.0
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
