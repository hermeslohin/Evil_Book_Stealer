extends Area2D
## A bookmark flag. Touch it to save your respawn point.

var active := false
var t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 64)
	cs.shape = r
	cs.position = Vector2(0, -32)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func activate(silent := false) -> void:
	active = true
	if not silent:
		get_tree().current_scene.set_checkpoint(global_position)


func _on_body_entered(body: Node) -> void:
	if body.has_method("respawn") and not active:
		activate()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2, -60, 4, 60), Color(0.6, 0.45, 0.3))
	draw_circle(Vector2(0, -62), 4.0, Color(1, 0.85, 0.3))
	var c := Color(0.35, 0.95, 0.5) if active else Color(0.55, 0.55, 0.6)
	var wave := sin(t * 5.0) * 3.0 if active else 0.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -58), Vector2(26, -58 + wave), Vector2(20, -48 + wave * 0.5),
		Vector2(26, -38 + wave), Vector2(2, -38)]), c)
