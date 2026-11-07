extends Area2D
## An ink well holding a limited store of ink. Stand in it to draw ink until
## you are full or the well runs dry.

const FILL_TIME := 0.18   # seconds per unit of ink

const MAX_STORED := 25
const REFILL_TIME := 10.0   # an empty well refills itself after this long

var stored := MAX_STORED
var cell := Vector2i.ZERO
var t := 0.0
var fill_t := 0.0
var active := false
var splash := 0.0
var refill_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	t = randf() * TAU
	if stored <= 0:
		refill_t = REFILL_TIME
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(44, 40)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)


func _process(delta: float) -> void:
	t += delta
	splash = max(splash - delta, 0.0)
	if stored <= 0:
		refill_t -= delta
		if refill_t <= 0.0:
			stored = MAX_STORED
			refill_t = 0.0
			splash = 0.4
			get_tree().current_scene.well_ink[cell] = stored
			get_tree().current_scene.burst(global_position + Vector2(0, -26), Color(0.3, 0.4, 1.0), 10, 120)
	active = false
	for body in get_overlapping_bodies():
		if stored > 0 and body.has_method("add_ink") and body.alive and body.ink < body.max_ink:
			active = true
			fill_t += delta
			if fill_t >= FILL_TIME:
				fill_t = 0.0
				body.add_ink(1)
				stored -= 1
				if stored <= 0:
					refill_t = REFILL_TIME
				get_tree().current_scene.well_ink[cell] = stored
				splash = 0.2
				get_tree().current_scene.burst(global_position + Vector2(0, -26), Color(0.3, 0.4, 1.0), 4, 90)
	if not active:
		fill_t = 0.0
	queue_redraw()


func _draw() -> void:
	var blue := Color(0.22, 0.3, 0.9)
	if active:
		draw_circle(Vector2(0, -18), 30.0, Color(0.4, 0.5, 1.0, 0.18 + 0.08 * sin(t * 12.0)))
	# stone base
	draw_rect(Rect2(-18, -10, 36, 10), Color(0.4, 0.38, 0.45))
	draw_rect(Rect2(-18, -10, 36, 3), Color(0.55, 0.52, 0.6))
	# well body
	draw_rect(Rect2(-15, -28, 30, 18), Color(0.33, 0.3, 0.38))
	draw_rect(Rect2(-15, -28, 4, 18), Color(0.25, 0.22, 0.3))
	# rim with ink inside
	draw_rect(Rect2(-17, -31, 34, 5), Color(0.5, 0.47, 0.56))
	# ink level sinks as the well is drained
	var level := float(stored) / MAX_STORED
	var surf := -29.0 + (1.0 - level) * 6.0 - splash * 8.0
	if stored > 0:
		draw_rect(Rect2(-13, surf, 26, -22.0 - surf), blue)
		draw_rect(Rect2(-13, surf, 26, 1.5), Color(0.6, 0.7, 1.0))
	else:
		draw_rect(Rect2(-13, -23, 26, 3), Color(0.12, 0.1, 0.16))
	_draw_label()
	if stored <= 0:
		var ry := -42.0
		draw_circle(Vector2(0, ry), 7.0, Color(0, 0, 0, 0.5))
		draw_arc(Vector2(0, ry), 6.0, -PI / 2, -PI / 2 + TAU * (1.0 - refill_t / REFILL_TIME), 24, Color(0.5, 0.6, 1.0), 2.5)
		return
	# bobbing droplet above the well so it reads as a pickup spot
	var by := -42.0 + sin(t * 3.0) * 2.5
	draw_circle(Vector2(0, by + 4), 4.5, blue)
	draw_colored_polygon(PackedVector2Array([Vector2(-3.5, by + 2), Vector2(3.5, by + 2), Vector2(0, by - 7)]), blue)


func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	var text := "EMPTY  %ds" % ceili(refill_t) if stored <= 0 else "%d / %d" % [stored, MAX_STORED]
	var col := Color(0.55, 0.55, 0.6) if stored <= 0 else Color(0.8, 0.88, 1.0)
	var pos := Vector2(-40, -58)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, 5, Color(0, 0, 0))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, col)
