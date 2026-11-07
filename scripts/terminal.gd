extends Area2D
## A computer terminal. Stand at it to hack it. When the progress bar fills it tells the
## level, which opens the matching firewall (or drops the core's shield).

const HACK_TIME := 1.4

var group := "a"       # "a"/"b" opens that firewall, "core" drops the core's shield
var hacked := false
var progress := 0.0
var rearm_t := 0.0
var t := 0.0
var flash := 0.0
var touching := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 2
	t = randf() * TAU
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 48)
	cs.shape = r
	cs.position = Vector2(0, -24)
	add_child(cs)


func rearm(delay: float) -> void:
	rearm_t = delay


func _process(delta: float) -> void:
	t += delta
	flash = max(flash - delta, 0.0)
	if rearm_t > 0.0:
		rearm_t -= delta
		if rearm_t <= 0.0:
			hacked = false
			progress = 0.0
	touching = false
	if not hacked:
		for body in get_overlapping_bodies():
			if body.has_method("respawn") and body.alive:
				touching = true
		if touching:
			progress += delta / HACK_TIME
			if progress >= 1.0:
				progress = 1.0
				hacked = true
				flash = 0.4
				get_tree().current_scene.burst(global_position + Vector2(0, -40), Color(0.4, 1.0, 0.7), 16, 160)
				get_tree().current_scene.on_terminal_hacked(self)
		else:
			progress = max(progress - delta * 0.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var green := Color(0.35, 1.0, 0.6)
	var red := Color(1.0, 0.35, 0.4)
	var accent: Color = green if hacked else (Color(1.0, 0.85, 0.3) if touching else red)
	if group == "core" and not hacked:
		accent = Color(0.5, 0.75, 1.0) if not touching else Color(1.0, 0.85, 0.3)

	# stand + keyboard
	draw_rect(Rect2(-4, -16, 8, 16), Color(0.2, 0.22, 0.3))
	draw_rect(Rect2(-14, -2, 28, 2), Color(0.3, 0.32, 0.42))
	# monitor
	var mon := Rect2(-18, -46, 36, 30)
	draw_rect(mon.grow(2), Color(0.12, 0.13, 0.2))
	draw_rect(mon, Color(0.02, 0.06, 0.06))
	if flash > 0.0:
		draw_rect(mon, Color(0.6, 1.0, 0.8, flash))
	# scrolling code lines on screen
	for i in 4:
		var w := 8.0 + fmod(t * 23.0 + i * 13.0, 22.0)
		draw_rect(Rect2(mon.position + Vector2(3, 4 + i * 6), Vector2(w, 2)), accent.darkened(0.3))
	draw_rect(mon.grow(4), Color(accent.r, accent.g, accent.b, 0.12 + 0.08 * sin(t * 4.0)), false, 2.0)

	# floating label / progress bar
	var label := ""
	if hacked:
		label = "ACCESS GRANTED" if group != "core" else ("REBOOTING..." if rearm_t > 0.0 else "SHIELD OFF")
	elif progress > 0.0:
		label = "HACKING..."
	else:
		label = "HACK ME" if group == "core" else "TERMINAL " + ("1" if group == "a" else "2")
	draw_string_outline(font, Vector2(-60, -60), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 4, Color(0, 0, 0))
	draw_string(font, Vector2(-60, -60), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, accent)
	if not hacked and progress > 0.0:
		var bar := Rect2(-20, -56, 40, 5)
		draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color(1.0, 0.85, 0.3))
