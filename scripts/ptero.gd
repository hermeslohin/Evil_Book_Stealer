extends CharacterBody2D
## A pterodactyl. Glides back and forth high up, then swoops down at you when you pass below.
## Stomp it or ink it twice.

const D := preload("res://scripts/difficulty.gd")

const PATROL := 110.0
const SIGHT := 220.0

var hp := 1 + D.ENEMY_HP_BONUS
var dead := false
var dir := -1
var t := 0.0
var flash := 0.0
var home := Vector2.ZERO
var state := "glide"   # glide, warn, swoop, climb
var state_t := 0.0
var swoop_from := Vector2.ZERO
var swoop_to := Vector2.ZERO
var cooldown := 1.0
var fall_v := 0.0
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	z_index = 4
	t = randf() * 10.0
	home = position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(34, 18)
	cs.shape = r
	add_child(cs)


func get_top_y() -> float:
	return global_position.y - 9.0


func _physics_process(delta: float) -> void:
	delta *= D.ENEMY_TEMPO
	t += delta
	flash = max(flash - delta, 0.0)
	if dead:
		fall_v += 900.0 * delta
		position.y += fall_v * delta
		rotation += 5.0 * delta
		modulate.a = move_toward(modulate.a, 0.0, 1.5 * delta)
		if modulate.a <= 0.0:
			queue_free()
		queue_redraw()
		return
	if player == null:
		player = get_tree().current_scene.player

	cooldown = max(cooldown - delta, 0.0)
	state_t -= delta
	match state:
		"glide":
			position.x += dir * 80.0 * delta
			if position.x < home.x - PATROL:
				dir = 1
			elif position.x > home.x + PATROL:
				dir = -1
			position.y = home.y + sin(t * 2.0) * 6.0
			if cooldown <= 0.0 and player != null and player.alive:
				var d: Vector2 = player.global_position - global_position
				if abs(d.x) < SIGHT and d.y > 40.0 and d.y < 420.0:
					state = "warn"
					state_t = 0.45
					dir = 1 if d.x > 0 else -1
		"warn":
			position.y = home.y - 10.0 * (1.0 - state_t / 0.45)
			if state_t <= 0.0:
				state = "swoop"
				state_t = 1.1
				swoop_from = position
				swoop_to = player.global_position + Vector2(dir * 60.0, 0)
		"swoop":
			# a dip down through your position and back up the other side
			var k: float = 1.0 - state_t / 1.1
			var end := Vector2(swoop_to.x + (swoop_to.x - swoop_from.x), home.y)
			var ctrl := swoop_to * 2.0 - (swoop_from + end) * 0.5   # curve passes through swoop_to
			position = swoop_from.lerp(ctrl, k).lerp(ctrl.lerp(end, k), k)
			if state_t <= 0.0:
				state = "climb"
		"climb":
			position = position.move_toward(Vector2(position.x, home.y), 160.0 * delta)
			if abs(position.y - home.y) < 2.0:
				home.x = position.x
				state = "glide"
				cooldown = 1.6
	queue_redraw()


func stomped(_by) -> void:
	_die()


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	collision_layer = 0
	get_tree().current_scene.burst(global_position, Color(0.8, 0.5, 0.35), 14, 170)


func _draw() -> void:
	var f := float(dir)
	var body := Color(0.65, 0.4, 0.3) if flash <= 0.0 else Color.WHITE
	if state == "warn" and int(t * 16.0) % 2 == 0:
		body = Color(0.95, 0.35, 0.3)
	var flap := sin(t * (14.0 if state == "swoop" else 7.0)) * 9.0
	if state == "swoop":
		flap = -6.0   # wings tucked back for the dive
	# wings
	var wing := body.darkened(0.15)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(-f * 26, -4 - flap), Vector2(-f * 16, 4)]), wing)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(f * 22, -4 - flap), Vector2(f * 12, 4)]), wing.lightened(0.1))
	# body
	draw_circle(Vector2.ZERO, 6.5, body)
	# head with crest and long beak
	var head := Vector2(f * 9, -4)
	draw_circle(head, 5.0, body)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-f * 2, -3), head + Vector2(-f * 12, -8), head + Vector2(-f * 3, 1)]), body.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([head + Vector2(f * 3, -2), head + Vector2(f * 16, 1), head + Vector2(f * 3, 2)]), Color(0.95, 0.8, 0.4))
	draw_circle(head + Vector2(f * 1.5, -1.5), 1.5, Color(0.1, 0.05, 0.05))
	# feet
	draw_line(Vector2(-2, 5), Vector2(-3, 10), Color(0.9, 0.75, 0.35), 1.5)
	draw_line(Vector2(2, 5), Vector2(1, 10), Color(0.9, 0.75, 0.35), 1.5)
