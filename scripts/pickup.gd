extends Area2D
## Collectible: a stolen book (or e-book), a heart that restores health, an ink bottle, or a growth mushroom.

var kind := "book"
var cell := Vector2i.ZERO
var t := 0.0
var color := Color.WHITE
var magnet := false   # books knocked loose from the thief fly to the player
var magnet_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	t = randf() * TAU
	color = Color.from_hsv(randf(), 0.6, 0.9)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("heal") and body.alive:
		if kind == "heart" and body.hp >= body.max_hp:
			return
		if kind == "ink" and body.ink >= body.max_ink:
			return
		if kind == "big" and body.big:
			return
		get_tree().current_scene.collect_pickup(self)
		queue_free()


func _draw_star(bob: Vector2) -> void:
	var gold := Color(1.0, 0.85, 0.2)
	draw_circle(bob, 18.0, Color(1.0, 0.95, 0.5, 0.18 + 0.1 * sin(t * 6.0)))
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var rad := 11.0 if i % 2 == 0 else 4.5
		pts.append(bob + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.from_hsv(fmod(t * 0.4, 1.0), 0.6, 1.0), 2.0)
	draw_circle(bob + Vector2(-2.5, -2.0), 1.6, Color(1, 1, 0.85))


func _process(delta: float) -> void:
	t += delta
	if magnet:
		magnet_t += delta
		var pl = get_tree().current_scene.player
		if magnet_t > 0.35 and pl and pl.alive:
			global_position = global_position.move_toward(pl.global_position, (250.0 + magnet_t * 700.0) * delta)
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, sin(t * 3.0) * 3.0)
	if kind == "book":
		draw_circle(bob, 14.0, Color(1, 0.9, 0.4, 0.15 + 0.08 * sin(t * 5.0)))
		draw_rect(Rect2(bob + Vector2(-8, -10), Vector2(16, 20)), color)
		draw_rect(Rect2(bob + Vector2(-8, -10), Vector2(4, 20)), color.darkened(0.35))
		draw_rect(Rect2(bob + Vector2(-1, -5), Vector2(7, 3)), Color(1, 0.9, 0.5))
		draw_rect(Rect2(bob + Vector2(7, -9), Vector2(2, 18)), Color(0.95, 0.92, 0.8))
	elif kind == "ebook":
		var glow := Color(0.3, 1.0, 0.85)
		draw_circle(bob, 15.0, Color(glow, 0.15 + 0.08 * sin(t * 5.0)))
		draw_rect(Rect2(bob + Vector2(-9, -12), Vector2(18, 24)), Color(0.12, 0.13, 0.2))   # tablet
		draw_rect(Rect2(bob + Vector2(-7, -10), Vector2(14, 18)), color.lightened(0.5))      # screen
		for i in 4:
			draw_rect(Rect2(bob + Vector2(-5, -7 + i * 4), Vector2(10 - (i % 2) * 3, 1.5)), Color(0.15, 0.15, 0.25))
		draw_circle(bob + Vector2(0, 10), 1.2, glow)
		draw_rect(Rect2(bob + Vector2(-9, -12), Vector2(18, 24)), glow, false, 1.0)
	elif kind == "big":
		var cap := Color(0.65, 0.3, 0.95)
		draw_circle(bob, 17.0, Color(0.8, 0.5, 1.0, 0.15 + 0.08 * sin(t * 5.0)))
		draw_rect(Rect2(bob + Vector2(-5, -1), Vector2(10, 12)), Color(0.95, 0.9, 0.75))   # stem
		draw_circle(bob + Vector2(0, -2), 11.0, cap)                                        # cap
		draw_rect(Rect2(bob + Vector2(-12, -2), Vector2(24, 4)), cap.darkened(0.2))
		draw_circle(bob + Vector2(-4, -6), 2.5, Color(1.0, 0.95, 0.5))
		draw_circle(bob + Vector2(4, -4), 2.0, Color(1.0, 0.95, 0.5))
		draw_circle(bob + Vector2(0, -9), 1.8, Color(1.0, 0.95, 0.5))
	elif kind == "star":
		_draw_star(bob)
	elif kind == "ink":
		var blue := Color(0.25, 0.35, 0.95)
		draw_circle(bob, 15.0, Color(0.4, 0.5, 1.0, 0.15 + 0.08 * sin(t * 5.0)))
		draw_rect(Rect2(bob + Vector2(-3, -12), Vector2(6, 5)), Color(0.55, 0.35, 0.2))   # cork
		draw_rect(Rect2(bob + Vector2(-4, -8), Vector2(8, 4)), Color(0.75, 0.85, 0.95))   # neck
		draw_circle(bob + Vector2(0, 2), 9.0, Color(0.75, 0.85, 0.95, 0.9))               # glass
		draw_circle(bob + Vector2(0, 3), 7.0, blue)                                        # ink
		draw_circle(bob + Vector2(-3, 0), 2.0, Color(0.8, 0.88, 1.0))
	else:
		var s := 1.0 + 0.1 * sin(t * 6.0)
		draw_set_transform(bob, 0.0, Vector2(s, s))
		var red := Color(1.0, 0.3, 0.4)
		draw_circle(Vector2(-5, -3), 6.0, red)
		draw_circle(Vector2(5, -3), 6.0, red)
		draw_colored_polygon(PackedVector2Array([Vector2(-10.5, -1), Vector2(10.5, -1), Vector2(0, 11)]), red)
		draw_circle(Vector2(-6, -5), 2.0, Color(1, 0.8, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
