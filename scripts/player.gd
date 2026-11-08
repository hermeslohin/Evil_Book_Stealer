extends CharacterBody2D
## The hero: a young librarian who throws blobs of ink and stomps on thieves.

const D := preload("res://scripts/difficulty.gd")

const SPEED := 270.0
const ACCEL := 2000.0
const AIR_ACCEL := 1400.0
const FRICTION := 2400.0
const JUMP_VELOCITY := -660.0
const GRAVITY := 1600.0
const FALL_MULT := 1.35
const SHORT_HOP_MULT := 2.2
const MAX_FALL := 950.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const SHOOT_COOLDOWN := 0.28
const BIG_SCALE := 1.5
const INVINCIBLE_TIME := 8.0
const ProjectileScript := preload("res://scripts/projectile.gd")
const Progress := preload("res://scripts/progress.gd")

var big := false
var max_ink := D.MAX_INK + Progress.bonus_ink()
var ink := max_ink
var max_hp := D.PLAYER_MAX_HP + Progress.bonus_hp()
var hp := max_hp
var alive := true
var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var shoot_cd := 0.0
var invuln := 0.0
var invincible_t := 0.0
var sparkle_t := 0.0
var knock_t := 0.0
var stomp_grace := 0.0
var spring_t := 0.0   # launched by a jump pad: full height even without holding jump
var throw_anim := 0.0
var anim := 0.0
var squash := Vector2.ONE
var shake := 0.0
var hitbox: Area2D
var camera: Camera2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	z_index = 5
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 30)
	cs.shape = r
	add_child(cs)

	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(22, 32)
	hcs.shape = hr
	hitbox.add_child(hcs)
	add_child(hitbox)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_smoothed = true
	add_child(camera)


func _main():
	return get_tree().current_scene


func _physics_process(delta: float) -> void:
	anim += delta
	shake = move_toward(shake, 0.0, 40.0 * delta)
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake) - 30.0)

	if not alive:
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
		position += velocity * delta
		rotation += 5.0 * delta
		queue_redraw()
		return

	invuln = max(invuln - delta, 0.0)
	shoot_cd = max(shoot_cd - delta, 0.0)
	knock_t = max(knock_t - delta, 0.0)
	stomp_grace = max(stomp_grace - delta, 0.0)
	spring_t = max(spring_t - delta, 0.0)
	throw_anim = max(throw_anim - delta, 0.0)

	if invincible_t > 0.0:
		invincible_t = max(invincible_t - delta, 0.0)
		sparkle_t -= delta
		if sparkle_t <= 0.0:
			sparkle_t = 0.06
			_main().burst(global_position + Vector2(randf_range(-10, 10), randf_range(-14, 14)), Color.from_hsv(fmod(anim * 1.3, 1.0), 0.7, 1.0), 2, 60)
		_main().hud.set_invincible(invincible_t, INVINCIBLE_TIME)

	var dir := Input.get_axis("move_left", "move_right")
	if knock_t <= 0.0 and abs(dir) > 0.2:
		facing = 1 if dir > 0 else -1

	# Gravity, heavier when falling or when jump is released early.
	var g := GRAVITY
	if velocity.y > 0.0:
		g *= FALL_MULT
	elif not Input.is_action_pressed("jump") and spring_t <= 0.0:
		g *= SHORT_HOP_MULT
	velocity.y = min(velocity.y + g * delta, MAX_FALL)

	if is_on_floor():
		coyote = COYOTE_TIME
	else:
		coyote -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer -= delta

	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
		squash = Vector2(0.75, 1.3)

	if knock_t <= 0.0:
		var a := ACCEL if is_on_floor() else AIR_ACCEL
		if abs(dir) < 0.2 and is_on_floor():
			a = FRICTION
		velocity.x = move_toward(velocity.x, dir * SPEED, a * delta)

	if Input.is_action_just_pressed("shoot") and shoot_cd <= 0.0:
		if ink > 0:
			_shoot()
		else:
			shoot_cd = SHOOT_COOLDOWN
			_main().burst(global_position + Vector2(facing * 14, -4), Color(0.4, 0.4, 0.5), 4, 60)
			_main().hud.flash_ink()

	var was_on_floor := is_on_floor()
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		squash = Vector2(1.3, 0.75)
	squash = squash.lerp(Vector2.ONE, 12.0 * delta)

	_check_enemies()
	queue_redraw()


func _check_enemies() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body.has_method("stomped") or body.dead:
			continue
		if invincible_t > 0.0:
			body.stomped(self)
			continue
		var my_bottom := global_position.y + 15.0 * scale.y
		if velocity.y > 40.0 and my_bottom < body.get_top_y() + 16.0:
			body.stomped(self)
			velocity.y = JUMP_VELOCITY * (0.9 if Input.is_action_pressed("jump") else 0.6)
			squash = Vector2(0.8, 1.25)
			stomp_grace = 0.25
			return
		if stomp_grace <= 0.0:
			take_damage(1, body.global_position)


func add_ink(amount: int) -> void:
	ink = clampi(ink + amount, 0, max_ink)
	_main().hud.set_ink(ink, max_ink)


func _shoot() -> void:
	ink -= 1
	_main().hud.set_ink(ink, max_ink)
	shoot_cd = SHOOT_COOLDOWN
	throw_anim = 0.15
	var p = ProjectileScript.new()
	p.team = "player"
	p.kind = "ink"
	p.vel = Vector2(facing * 600.0, -60.0)
	p.grav = 300.0
	p.position = global_position + Vector2(facing * 14, -4) * scale.y
	get_parent().add_child(p)


## Launched upward by a jump pad.
func spring(launch_velocity: float) -> void:
	velocity.y = launch_velocity
	spring_t = 0.6
	coyote = 0.0
	squash = Vector2(0.7, 1.35)


func grow() -> void:
	if big:
		return
	big = true
	scale = Vector2.ONE * BIG_SCALE
	position.y -= 15.0 * (BIG_SCALE - 1.0)   # keep feet on the ground
	squash = Vector2(0.7, 1.3)
	invuln = max(invuln, 0.3)


func start_invincible() -> void:
	invincible_t = INVINCIBLE_TIME
	sparkle_t = 0.0


func shrink() -> void:
	if not big:
		return
	big = false
	scale = Vector2.ONE
	position.y += 15.0 * (BIG_SCALE - 1.0)
	squash = Vector2(1.3, 0.7)


func take_damage(amount: int, from_pos = null, force := false) -> void:
	if not alive or (invuln > 0.0 and not force):
		return
	if invincible_t > 0.0 and not force:
		return
	if big and not force:
		# the power-up absorbs the hit instead of a heart
		shrink()
		invuln = D.INVULN_TIME
		if from_pos != null:
			var sd: float = sign(global_position.x - from_pos.x)
			if sd == 0.0:
				sd = -facing
			velocity = Vector2(sd * 300.0, -330.0)
			knock_t = 0.25
		_main().shake(6)
		_main().burst(global_position, Color(0.8, 0.5, 1.0), 14, 160)
		return
	hp -= amount
	invuln = D.INVULN_TIME
	if from_pos != null:
		var d: float = sign(global_position.x - from_pos.x)
		if d == 0.0:
			d = -facing
		velocity = Vector2(d * 300.0, -330.0)
		knock_t = 0.25
	_main().on_player_hurt(hp)
	_main().burst(global_position, Color(1, 0.3, 0.3), 10, 140)
	if hp <= 0:
		_die()


func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)
	_main().on_player_healed(hp)


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	invuln = 1.0
	camera.reset_smoothing()


func _die() -> void:
	alive = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(-facing * 120.0, -520.0)
	z_index = 50
	_main().on_player_died()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if alive and invuln > 0.0 and int(invuln * 14.0) % 2 == 0:
		return
	modulate = Color.from_hsv(fmod(anim * 2.2, 1.0), 0.75, 1.0) if invincible_t > 0.0 else Color.WHITE
	var sx := squash.x * facing
	draw_set_transform(Vector2(0, 15.0 * (1.0 - squash.y)), 0.0, Vector2(sx, squash.y))

	var running: bool = alive and is_on_floor() and abs(velocity.x) > 30.0
	var step := sin(anim * 18.0) * 3.0 if running else 0.0
	var skin := Color(1.0, 0.82, 0.66)
	var shoe := Color(0.25, 0.15, 0.1)
	var pants := Color(0.2, 0.22, 0.35)

	# legs
	draw_rect(Rect2(-7 + step, 8, 5, 5), pants)
	draw_rect(Rect2(2 - step, 8, 5, 5), pants)
	draw_rect(Rect2(-8 + step, 12, 7, 3), shoe)
	draw_rect(Rect2(1 - step, 12, 7, 3), shoe)
	# body (green sweater) + satchel strap
	draw_rect(Rect2(-8, -3, 16, 12), Color(0.2, 0.62, 0.42))
	draw_line(Vector2(-7, -3), Vector2(6, 8), Color(0.55, 0.35, 0.2), 2.0)
	# arm (throwing pose when shooting)
	if throw_anim > 0.0:
		draw_rect(Rect2(6, -3, 9, 4), Color(0.2, 0.62, 0.42))
		draw_circle(Vector2(16, -1), 2.5, skin)
	else:
		draw_rect(Rect2(3, -2, 4, 9), Color(0.16, 0.52, 0.35))
	# head
	draw_circle(Vector2(0, -10), 8.0, skin)
	# hair
	draw_circle(Vector2(-2, -15), 6.5, Color(0.45, 0.25, 0.12))
	draw_rect(Rect2(-8, -17, 14, 4), Color(0.45, 0.25, 0.12))
	# glasses
	draw_arc(Vector2(3, -10), 3.0, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.2)
	draw_arc(Vector2(-3, -10), 3.0, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.2)
	draw_circle(Vector2(3.5, -10), 1.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(-2.5, -10), 1.0, Color(0.1, 0.1, 0.1))
	# scarf
	var scarf := Progress.scarf_color(anim)
	draw_rect(Rect2(-8, -4, 16, 3), scarf)
	var flap := sin(anim * 10.0) * 2.0
	draw_rect(Rect2(-12, -3 + flap * 0.3, 5, 3), scarf)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
