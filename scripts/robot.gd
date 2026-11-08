extends CharacterBody2D
## A robot guard enforcing the Cyborg's no-reading law. Patrols, and when it spots you
## straight ahead it powers up and fires a laser bolt. Stomp it or ink it a few times.

const D := preload("res://scripts/difficulty.gd")

const GRAVITY := 1400.0
const ProjectileScript := preload("res://scripts/projectile.gd")
const SIGHT := 360.0
const CHARGE := 0.6

var dir := -1
var hp := 2 + D.ENEMY_HP_BONUS
var dead := false
var t := 0.0
var flash := 0.0
var charge := 0.0
var cooldown := 1.0
var ray: RayCast2D
var player


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 4
	t = randf() * 10.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(38, 45)
	cs.shape = r
	cs.position = Vector2(0, -4.5)
	add_child(cs)
	ray = RayCast2D.new()
	ray.target_position = Vector2(0, 30)
	ray.collision_mask = 1
	add_child(ray)


func get_top_y() -> float:
	return global_position.y - 27.0


func _physics_process(delta: float) -> void:
	delta *= D.ENEMY_TEMPO
	t += delta
	flash = max(flash - delta, 0.0)
	if dead:
		rotation = move_toward(rotation, -dir * 1.5, 4.0 * delta)
		modulate.a = move_toward(modulate.a, 0.0, 1.5 * delta)
		if modulate.a <= 0.0:
			queue_free()
		queue_redraw()
		return
	if player == null:
		player = get_tree().current_scene.player

	velocity.y = min(velocity.y + GRAVITY * delta, 900.0)
	cooldown = max(cooldown - delta, 0.0)
	if charge > 0.0:
		velocity.x = 0.0
		charge -= delta
		if charge <= 0.0:
			_fire()
			cooldown = 1.8
	else:
		velocity.x = dir * 55.0 * D.ENEMY_SPEED
		if cooldown <= 0.0 and player != null and player.alive:
			var d: Vector2 = player.global_position - global_position
			if abs(d.x) < SIGHT and abs(d.y) < 50.0 and sign(d.x) == dir:
				charge = CHARGE
	move_and_slide()
	if is_on_wall():
		dir = -dir
	elif is_on_floor() and charge <= 0.0:
		ray.position = Vector2(dir * 14, 0)
		ray.force_raycast_update()
		if not ray.is_colliding():
			dir = -dir
	queue_redraw()


func _fire() -> void:
	var p = ProjectileScript.new()
	p.team = "enemy"
	p.kind = "bolt"
	p.vel = Vector2(dir * 330.0 * D.ENEMY_SHOT_SPEED, 0)
	p.life = 2.5
	p.position = global_position + Vector2(dir * 16, -4)
	get_parent().add_child(p)


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
	collision_mask = 0
	get_tree().current_scene.burst(global_position, Color(1.0, 0.6, 0.2), 14, 170)
	queue_redraw()


func _draw() -> void:
	var f := float(dir)
	var metal := Color(0.6, 0.62, 0.7) if flash <= 0.0 else Color.WHITE
	var walking := charge <= 0.0 and not dead
	var step := sin(t * 10.0) * 3.0 if walking else 0.0
	# legs
	draw_rect(Rect2(-8 + step, 8, 6, 10), metal.darkened(0.3))
	draw_rect(Rect2(2 - step, 8, 6, 10), metal.darkened(0.3))
	# body
	draw_rect(Rect2(-11, -8, 22, 18), metal)
	draw_rect(Rect2(-7, -3, 14, 6), Color(0.2, 0.2, 0.28))
	# "NO BOOKS" badge: a book with a red cross
	draw_rect(Rect2(-4, -2, 8, 5), Color(0.9, 0.85, 0.7))
	draw_line(Vector2(-5, -3), Vector2(5, 4), Color(1, 0.2, 0.2), 1.5)
	# arm cannon
	draw_rect(Rect2(f * 8 - 3 + f * 4, -6, 10, 5), metal.darkened(0.2))
	# head with a visor
	draw_rect(Rect2(-8, -18, 16, 10), metal.lightened(0.1))
	var eye := Color(1.0, 0.2, 0.25)
	if charge > 0.0:
		eye = Color(1.0, 0.9, 0.3) if int(t * 20.0) % 2 == 0 else Color(1.0, 0.3, 0.2)
		draw_circle(Vector2(f * 18, -4), 3.0 + (CHARGE - charge) * 8.0, Color(1.0, 0.3, 0.3, 0.5))
	draw_rect(Rect2(-6, -15, 12, 4), Color(0.1, 0.05, 0.08))
	draw_rect(Rect2(f * 1 - 2 + f * 2, -15, 4, 4), eye)
	# antenna
	draw_line(Vector2(0, -18), Vector2(0, -24), metal.darkened(0.3), 1.5)
	draw_circle(Vector2(0, -25), 2.0, eye)
