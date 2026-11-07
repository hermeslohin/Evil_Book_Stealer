extends StaticBody2D
## A crackling red firewall blocking the way. Hack the matching terminal to shut it down.

const TILE := 32

var height := 1        # in tiles; the node sits at the top-center of the barrier
var group := "a"
var is_open := false
var fade := 1.0
var t := 0.0
var shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 2
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, height * TILE)
	shape.shape = r
	shape.position = Vector2(0, height * TILE / 2.0)
	shape.disabled = is_open
	add_child(shape)


func open(instant := false) -> void:
	is_open = true
	if instant:
		fade = 0.0
	if shape:
		shape.set_deferred("disabled", true)
	if not instant and is_inside_tree():
		for i in height:
			get_tree().current_scene.burst(global_position + Vector2(0, (i + 0.5) * TILE), Color(1.0, 0.35, 0.35), 6, 140)


func _process(delta: float) -> void:
	t += delta
	if is_open:
		fade = move_toward(fade, 0.0, 2.5 * delta)
	queue_redraw()


func _draw() -> void:
	var h := height * TILE
	# emitter caps stay behind even once it's down
	var cap := Color(0.25, 0.1, 0.12) if is_open else Color(0.45, 0.12, 0.15)
	draw_rect(Rect2(-14, -2, 28, 6), cap)
	draw_rect(Rect2(-14, h - 4, 28, 6), cap)
	if fade <= 0.0:
		return
	var a := fade
	draw_rect(Rect2(-12, 0, 24, h), Color(1.0, 0.15, 0.2, 0.18 * a))
	# vertical beams that jitter
	for i in 4:
		var x := -9.0 + i * 6.0 + sin(t * 17.0 + i * 2.1) * 1.2
		draw_line(Vector2(x, 0), Vector2(x, h), Color(1.0, 0.3 + 0.1 * i, 0.3, 0.75 * a), 2.0)
	# horizontal scan lines sliding down
	for i in height * 2:
		var y := fmod(t * 50.0 + i * 16.0, float(h))
		draw_line(Vector2(-12, y), Vector2(12, y), Color(1.0, 0.6, 0.6, 0.45 * a), 1.0)
	# lock icon in the middle
	var mid := Vector2(0, h / 2.0)
	draw_arc(mid + Vector2(0, -6), 5.0, PI, TAU, 10, Color(1, 0.85, 0.85, a), 2.0)
	draw_rect(Rect2(mid + Vector2(-7, -6), Vector2(14, 11)), Color(1.0, 0.3, 0.35, a))
	draw_circle(mid + Vector2(0, -1), 1.8, Color(0.2, 0.0, 0.05, a))
