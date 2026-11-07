extends Area2D
## A row of sharp quills sticking out of the floor (or, in the city, a traffic cone).

var style := "quills"   # "quills" or "cone"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	if style == "cone":
		r.size = Vector2(18, 22)
		cs.position = Vector2(0, 5)
	else:
		r.size = Vector2(28, 12)
		cs.position = Vector2(0, 9)
	cs.shape = r
	add_child(cs)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(1, global_position + Vector2(0, 40))


func _draw() -> void:
	if style == "cone":
		var orange := Color(1.0, 0.5, 0.12)
		draw_rect(Rect2(-14, 12, 28, 4), Color(0.2, 0.2, 0.22))
		draw_colored_polygon(PackedVector2Array([Vector2(-11, 13), Vector2(11, 13), Vector2(3, -9), Vector2(-3, -9)]), orange)
		draw_colored_polygon(PackedVector2Array([Vector2(-7.5, 2), Vector2(7.5, 2), Vector2(6, -3), Vector2(-6, -3)]), Color(0.95, 0.95, 0.95))
		draw_line(Vector2(-3, -9), Vector2(-9, 13), orange.lightened(0.3), 1.5)
		return
	for i in 4:
		var x := -16.0 + i * 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 16), Vector2(x + 8, 16), Vector2(x + 4, 0)]), Color(0.75, 0.78, 0.85))
		draw_line(Vector2(x + 4, 1), Vector2(x + 6, 16), Color(0.5, 0.52, 0.6), 1.0)
