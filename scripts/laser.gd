extends Area2D
## A security laser hanging from the ceiling. It flickers as a warning, then fires a
## beam straight down for a moment. Time your run through the gaps.

const CYCLE := 2.6
const WARN := 0.6      # flickering, harmless
const FIRE := 1.0      # deadly beam

var length := 160.0
var phase := 0.0       # 0..1 offset so neighbouring lasers fire out of step
var t := 0.0
var shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 6
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, length - 10)
	shape.shape = r
	shape.position = Vector2(0, length / 2.0 + 5)
	add_child(shape)


func _cycle_pos() -> float:
	return fmod(t + phase * CYCLE, CYCLE)


func firing() -> bool:
	var c := _cycle_pos()
	return c >= WARN and c < WARN + FIRE


func warning() -> bool:
	return _cycle_pos() < WARN


func _physics_process(delta: float) -> void:
	t += delta
	if firing():
		for body in get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(1, global_position + Vector2(0, length * 0.5))
	queue_redraw()


func _draw() -> void:
	# emitter housing
	draw_rect(Rect2(-10, 0, 20, 10), Color(0.25, 0.27, 0.36))
	draw_rect(Rect2(-6, 8, 12, 5), Color(0.15, 0.15, 0.2))
	var lamp := Color(0.35, 0.1, 0.12)
	if warning():
		var blink := int(_cycle_pos() * 14.0) % 2 == 0
		lamp = Color(1.0, 0.8, 0.2) if blink else Color(0.5, 0.35, 0.1)
		# thin aiming line
		if blink:
			draw_line(Vector2(0, 13), Vector2(0, length), Color(1.0, 0.4, 0.4, 0.35), 1.0)
	elif firing():
		lamp = Color(1.0, 0.3, 0.3)
		var wob := sin(t * 60.0) * 1.5
		draw_rect(Rect2(-9 - wob, 13, 18 + wob * 2, length - 13), Color(1.0, 0.1, 0.15, 0.25))
		draw_rect(Rect2(-4, 13, 8, length - 13), Color(1.0, 0.25, 0.3, 0.85))
		draw_rect(Rect2(-1.5, 13, 3, length - 13), Color(1.0, 0.9, 0.9))
		draw_circle(Vector2(0, length - 2), 7.0 + wob, Color(1.0, 0.5, 0.4, 0.6))
	draw_circle(Vector2(0, 10), 3.0, lamp)
