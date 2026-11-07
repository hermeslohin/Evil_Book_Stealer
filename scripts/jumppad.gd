extends Area2D
## A glowing jump pad. Land on it and it launches you sky-high.

const LAUNCH := -1000.0

var t := 0.0
var pop := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 10)
	cs.shape = r
	cs.position = Vector2(0, -5)
	add_child(cs)


func _physics_process(delta: float) -> void:
	t += delta
	pop = max(pop - delta * 3.0, 0.0)
	for body in get_overlapping_bodies():
		if body.has_method("spring") and body.alive and body.velocity.y >= 0.0:
			body.spring(LAUNCH)
			pop = 1.0
			get_tree().current_scene.burst(global_position + Vector2(0, -8), Color(0.3, 1.0, 0.9), 12, 180)
	queue_redraw()


func _draw() -> void:
	var glow := Color(0.3, 1.0, 0.9)
	var h := 6.0 + pop * 6.0
	draw_rect(Rect2(-15, -4, 30, 4), Color(0.2, 0.22, 0.3))
	draw_rect(Rect2(-12, -4 - h, 24, 3), glow)
	draw_line(Vector2(-8, -4), Vector2(-8, -4 - h), Color(0.6, 0.65, 0.75), 2.0)
	draw_line(Vector2(8, -4), Vector2(8, -4 - h), Color(0.6, 0.65, 0.75), 2.0)
	# chevrons pointing up
	for i in 3:
		var y := -18.0 - i * 9.0 - fmod(t * 20.0, 9.0)
		var a := 0.6 * (1.0 - i / 3.0)
		draw_polyline(PackedVector2Array([Vector2(-6, y + 4), Vector2(0, y), Vector2(6, y + 4)]), Color(glow, a), 2.0)
