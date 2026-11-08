extends "res://scripts/player.gd"
## The hero on a skateboard. Rolls forward on its own: hold Right to speed up, Left to brake.
## Jump over cones and gaps, grind rails, launch off ramps, and don't ride into walls!

const BASE_SPEED := 300.0
const FAST_SPEED := 440.0
const SLOW_SPEED := 170.0
const ROLL_ACCEL := 900.0
const RAMP_LAUNCH := -820.0

var auto := true        # false once you reach the dead-end alley: free movement
var grinding := false
var trick := 0.0        # remaining spin from a ramp flip
var crash_cd := 0.0
var ramp_cd := 0.0
var spark_t := 0.0
var wheel := 0.0
var look := 170.0       # camera looks ahead so you can see what's coming


func _physics_process(delta: float) -> void:
	anim += delta
	shake = move_toward(shake, 0.0, 40.0 * delta)
	look = move_toward(look, 170.0 if auto else 0.0, 250.0 * delta)
	camera.offset = Vector2(look + randf_range(-shake, shake), randf_range(-shake, shake) - 30.0)

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
	throw_anim = max(throw_anim - delta, 0.0)
	crash_cd = max(crash_cd - delta, 0.0)
	ramp_cd = max(ramp_cd - delta, 0.0)
	trick = move_toward(trick, 0.0, 11.0 * delta)

	var dir := Input.get_axis("move_left", "move_right")
	if auto:
		facing = 1
	elif knock_t <= 0.0 and abs(dir) > 0.2:
		facing = 1 if dir > 0 else -1

	var g := GRAVITY
	if velocity.y > 0.0:
		g *= FALL_MULT
	elif not Input.is_action_pressed("jump") and trick <= 0.0:
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
		if auto:
			var target := BASE_SPEED
			if dir > 0.2:
				target = lerpf(BASE_SPEED, FAST_SPEED, dir)
			elif dir < -0.2:
				target = lerpf(BASE_SPEED, SLOW_SPEED, -dir)
			velocity.x = move_toward(velocity.x, target, ROLL_ACCEL * delta)
		else:
			var a := ACCEL if is_on_floor() else AIR_ACCEL
			if abs(dir) < 0.2 and is_on_floor():
				a = FRICTION * 0.4   # a skateboard keeps rolling a little
			velocity.x = move_toward(velocity.x, dir * SPEED, a * delta)

	if Input.is_action_just_pressed("shoot") and shoot_cd <= 0.0:
		if ink > 0:
			_shoot()
		else:
			shoot_cd = SHOOT_COOLDOWN
			_main().burst(global_position + Vector2(facing * 14, -4), Color(0.4, 0.4, 0.5), 4, 60)
			_main().hud.flash_ink()

	var was_on_floor := is_on_floor()
	var push_x := velocity.x
	move_and_slide()
	wheel += velocity.x * delta * 0.2

	# Rolled straight into a wall? Ouch.
	if auto and is_on_wall() and push_x > 150.0 and crash_cd <= 0.0:
		_crash()

	var feet := global_position + Vector2(0, 15.0 * scale.y)
	var under: String = _main().tile_at(feet + Vector2(0, -3))
	if is_on_floor() and under == "/" and ramp_cd <= 0.0 and velocity.x > 100.0:
		_launch()

	grinding = is_on_floor() and _main().tile_at(feet + Vector2(0, 4)) == "="
	if grinding:
		spark_t -= delta
		if spark_t <= 0.0:
			spark_t = 0.06
			_spark(feet)

	if is_on_floor() and not was_on_floor:
		squash = Vector2(1.3, 0.75)
		if trick > 0.0:
			trick = 0.0   # land it clean
	squash = squash.lerp(Vector2.ONE, 12.0 * delta)

	_check_enemies()
	queue_redraw()


func _check_enemies() -> void:
	for body in hitbox.get_overlapping_bodies():
		if not body.has_method("stomped") or body.dead:
			continue
		var my_bottom := global_position.y + 15.0 * scale.y
		if velocity.y > 40.0 and my_bottom < body.get_top_y() + 16.0:
			body.stomped(self)
			velocity.y = JUMP_VELOCITY * (0.9 if Input.is_action_pressed("jump") else 0.6)
			squash = Vector2(0.8, 1.25)
			stomp_grace = 0.25
			return
		if body.has_method("is_thief"):
			continue   # riding past the thief is harmless; jump on his head!
		if stomp_grace <= 0.0:
			take_damage(1, body.global_position)


func _crash() -> void:
	crash_cd = 0.6
	_main().shake(8)
	_main().burst(global_position + Vector2(12, 8), Color(0.9, 0.8, 0.5), 10, 160)
	take_damage(1, global_position + Vector2(30, 0))
	velocity = Vector2(-260.0, -380.0)
	knock_t = 0.3


func _launch() -> void:
	ramp_cd = 0.4
	velocity.y = RAMP_LAUNCH
	velocity.x = max(velocity.x, BASE_SPEED + 30.0)
	trick = TAU
	squash = Vector2(0.75, 1.3)
	_main().burst(global_position + Vector2(-8, 14), Color(1.0, 0.85, 0.4), 10, 140)


func _spark(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at + Vector2(randf_range(-8, 8), 0)
	p.one_shot = true
	p.amount = 3
	p.explosiveness = 1.0
	p.lifetime = 0.25
	p.direction = Vector2(-1, -0.6)
	p.spread = 30.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 180.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Color(1.0, 0.85, 0.3)
	p.z_index = 6
	get_parent().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _shoot() -> void:
	# Ink flies flatter and carries your board's speed, so it can reach the thief.
	ink -= 1
	_main().hud.set_ink(ink, max_ink)
	shoot_cd = SHOOT_COOLDOWN
	throw_anim = 0.15
	var p = ProjectileScript.new()
	p.team = "player"
	p.kind = "ink"
	var carry: float = max(velocity.x * facing, 0.0)
	p.vel = Vector2(facing * (600.0 + carry), -120.0)
	p.grav = 300.0
	p.position = global_position + Vector2(facing * 14, -4) * scale.y
	get_parent().add_child(p)


func respawn(pos: Vector2) -> void:
	super.respawn(pos)
	trick = 0.0
	rotation = 0.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if alive and invuln > 0.0 and int(invuln * 14.0) % 2 == 0:
		return
	var sx := squash.x * facing
	draw_set_transform(Vector2(0, 15.0 * (1.0 - squash.y)), -trick * facing, Vector2(sx, squash.y))

	var skin := Color(1.0, 0.82, 0.66)
	var shoe := Color(0.25, 0.15, 0.1)
	var pants := Color(0.2, 0.22, 0.35)
	var crouch := 2.0 if grinding or trick > 0.0 else 0.0

	# skateboard: deck, kicked-up tail and nose, spinning wheels
	var deck := Color(0.85, 0.25, 0.3)
	draw_rect(Rect2(-15, 9, 30, 3), deck)
	draw_line(Vector2(-15, 10), Vector2(-19, 6), deck, 3.0)
	draw_line(Vector2(15, 10), Vector2(19, 6), deck, 3.0)
	draw_rect(Rect2(-13, 9, 26, 1), Color(1.0, 0.85, 0.3))
	for wx in [-9.0, 9.0]:
		draw_circle(Vector2(wx, 13), 2.6, Color(0.95, 0.9, 0.7))
		var a: float = wheel + wx
		draw_line(Vector2(wx, 13), Vector2(wx + cos(a) * 2.4, 13 + sin(a) * 2.4), Color(0.4, 0.35, 0.3), 1.0)

	# legs in a wide skater stance, knees bent
	draw_rect(Rect2(-9, 1 + crouch, 5, 8 - crouch), pants)
	draw_rect(Rect2(4, 1 + crouch, 5, 8 - crouch), pants)
	draw_rect(Rect2(-11, 6, 7, 3), shoe)
	draw_rect(Rect2(4, 6, 7, 3), shoe)
	# body leaning forward
	draw_set_transform(Vector2(0, 15.0 * (1.0 - squash.y) + crouch), -trick * facing + 0.12 * facing, Vector2(sx, squash.y))
	draw_rect(Rect2(-8, -9, 16, 11), Color(0.2, 0.62, 0.42))
	draw_line(Vector2(-7, -9), Vector2(6, 2), Color(0.55, 0.35, 0.2), 2.0)
	if throw_anim > 0.0:
		draw_rect(Rect2(6, -9, 9, 4), Color(0.2, 0.62, 0.42))
		draw_circle(Vector2(16, -7), 2.5, skin)
	else:
		# arms out for balance
		draw_rect(Rect2(-15, -7, 8, 3), Color(0.16, 0.52, 0.35))
		draw_rect(Rect2(7, -6, 7, 3), Color(0.16, 0.52, 0.35))
	draw_circle(Vector2(0, -16), 8.0, skin)
	draw_circle(Vector2(-2, -21), 6.5, Color(0.45, 0.25, 0.12))
	draw_rect(Rect2(-8, -23, 14, 4), Color(0.45, 0.25, 0.12))
	# helmet, because safety first
	draw_arc(Vector2(0, -18), 9.0, PI, TAU, 14, Color(0.25, 0.5, 0.95), 4.0)
	draw_arc(Vector2(3, -16), 3.0, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.2)
	draw_arc(Vector2(-3, -16), 3.0, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.2)
	draw_circle(Vector2(3.5, -16), 1.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(-2.5, -16), 1.0, Color(0.1, 0.1, 0.1))
	# scarf streaming behind in the wind
	draw_rect(Rect2(-8, -10, 16, 3), Progress.scarf_color(anim))
	var flap := sin(anim * 14.0) * 2.5
	draw_rect(Rect2(-16, -10 + flap * 0.4, 8, 3), Progress.scarf_color(anim))
	draw_rect(Rect2(-22, -9 + flap, 6, 3), Progress.scarf_color(anim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
