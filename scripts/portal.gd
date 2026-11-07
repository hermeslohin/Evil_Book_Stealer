extends Area2D
## A swirling time portal. Step into it and you warp to its partner portal.
## The partner stays quiet until you step out of it, so you don't bounce straight back.

var partner = null
var locked := false
var t := 0.0
var pulse := 0.0
var hue := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 2
	t = randf() * TAU
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 56)
	cs.shape = r
	cs.position = Vector2(0, -30)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if locked or partner == null or not body.has_method("respawn") or not body.alive:
		return
	partner.locked = true
	partner.pulse = 1.0
	pulse = 1.0
	var main = get_tree().current_scene
	main.burst(global_position + Vector2(0, -30), Color(0.6, 0.9, 1.0), 18, 200)
	body.global_position = partner.global_position - Vector2(0, 16.0 * body.scale.y)
	body.velocity = Vector2.ZERO
	body.camera.reset_smoothing()
	main.burst(partner.global_position + Vector2(0, -30), Color(1.0, 0.85, 0.4), 18, 200)
	main.on_time_warp()


func _on_body_exited(body: Node) -> void:
	if body.has_method("respawn"):
		locked = false


func _process(delta: float) -> void:
	t += delta
	pulse = max(pulse - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0, -30)
	var glow := 0.2 + 0.08 * sin(t * 4.0) + pulse * 0.4
	# stone frame
	draw_rect(Rect2(-20, -4, 40, 4), Color(0.4, 0.35, 0.3))
	draw_rect(Rect2(-20, -62, 6, 60), Color(0.45, 0.4, 0.35))
	draw_rect(Rect2(14, -62, 6, 60), Color(0.45, 0.4, 0.35))
	draw_rect(Rect2(-22, -66, 44, 6), Color(0.5, 0.45, 0.38))
	# swirling vortex
	draw_set_transform(c, 0.0, Vector2(0.55, 1.0))
	draw_circle(Vector2.ZERO, 28.0, Color(0.45, 0.7, 1.0, glow))
	for i in 5:
		var rad := 24.0 - i * 4.5
		var a0 := t * (3.0 + i) + i * 1.3
		var col := Color.from_hsv(fmod(0.55 + i * 0.08 + t * 0.05, 1.0), 0.6, 1.0, 0.85)
		draw_arc(Vector2.ZERO, rad, a0, a0 + PI * 1.3, 18, col, 3.0)
	draw_circle(Vector2.ZERO, 4.0 + sin(t * 6.0), Color(1, 1, 1, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a little clock face on top so it reads as a TIME portal
	var ck := Vector2(0, -63)
	draw_circle(ck, 7.0, Color(1.0, 0.85, 0.4))
	draw_circle(ck, 5.5, Color(0.98, 0.95, 0.85))
	draw_line(ck, ck + Vector2(0, -4), Color(0.2, 0.15, 0.1), 1.5)
	draw_line(ck, ck + Vector2(cos(t * 2.0), sin(t * 2.0)) * 4.5, Color(0.2, 0.15, 0.1), 1.2)
