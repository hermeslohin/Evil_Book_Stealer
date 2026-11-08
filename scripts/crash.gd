extends "res://scripts/hack.gd"
## Level 5: System Crash, the second level inside the mainframe. You destroyed the core, so the
## whole supercomputer is going down, and a wall of corrupted data (the CRASH WAVE) sweeps through
## it from the left. Outrun it, past lasers, drones and bottomless gaps, to the time portal the
## Book Stealer escaped through. Touching the wave costs a heart and knocks it back a little.
## Tiles, enemies, checkpoints and pickups all work just like Level 4 (hack.gd).

const CrashData := preload("res://scripts/crash_data.gd")
const PortalScript := preload("res://scripts/portal.gd")
const D := preload("res://scripts/difficulty.gd")

const WAVE_SPEED := 105.0    # pixels per second, scaled by the difficulty's ENEMY_SPEED
const WAVE_DELAY := 1.5      # seconds before the wave starts moving
const WAVE_START_GAP := 9    # tiles behind you the wave starts (at the start or a checkpoint)
const WAVE_MAX_LAG := 640.0  # the wave never falls further behind you than this
const WAVE_PUSHBACK := 7     # tiles the wave stutters back after it hits you ("lag spike")

var wave
var wave_delay := WAVE_DELAY
var exit_pos := Vector2.INF


func _init() -> void:
	level_num = 5


func _map_data() -> Array:
	return CrashData.MAP


func _show_title() -> void:
	hud.show_message("LEVEL 5: SYSTEM CRASH",
		"The core is destroyed and the whole supercomputer is CRASHING!\n" +
		"The Book Stealer is escaping through a time portal at the far end of the system.\n\n" +
		"A wall of corrupted data is sweeping in behind you. RUN!\n" +
		"If it catches you, you lose a heart. Don't stop for long!\n" +
		"Grab the e-books on the way, and jump into the portal at the end.\n\n" +
		"Press Space to log in     (Esc: back to the map)")


func _spawn_extra(c: String, x: int, y: int) -> void:
	if c != "E":
		return
	exit_pos = Vector2((x + 0.5) * TILE, (y + 1) * TILE)
	var portal = PortalScript.new()   # no partner, so it's just for show: reaching it wins
	portal.position = exit_pos
	world.add_child(portal)


func _build_world() -> void:
	super()
	wave = CrashWave.new()
	wave.height = rows * TILE
	wave.x = checkpoint_pos.x - WAVE_START_GAP * TILE
	world.add_child(wave)


func _on_start() -> void:
	hud.banner("SYSTEM FAILURE! RUN!", Color(1.0, 0.35, 0.4))
	shake(8)


func _play_update(delta: float) -> void:
	if state != "play" or not player.alive:
		return
	var px: float = player.global_position.x
	if wave_delay > 0.0:
		wave_delay -= delta
	else:
		wave.x = maxf(wave.x + WAVE_SPEED * D.ENEMY_SPEED * delta, px - WAVE_MAX_LAG)

	if px - 10.0 < wave.x:
		player.take_damage(1, Vector2(wave.x - 100.0, player.global_position.y))
		wave.x -= WAVE_PUSHBACK * TILE
		wave.glitch = 1.0
		shake(8)
		hud.banner("LAG SPIKE!", Color(1.0, 0.45, 0.5))

	if exit_pos != Vector2.INF and px > exit_pos.x - 8.0 and absf(player.global_position.y - exit_pos.y) < 80.0:
		_escape()


func _player_fell() -> void:
	super()
	wave.x = minf(wave.x, checkpoint_pos.x - WAVE_START_GAP * TILE)
	wave_delay = WAVE_DELAY


func _escape() -> void:
	state = "won"
	var reward := Progress.complete_level(level_num, books_collected, books_total)
	wave.stopped = true
	burst(exit_pos + Vector2(0, -30), Color(0.6, 0.9, 1.0), 26, 240)
	burst(exit_pos + Vector2(0, -30), Color(1.0, 0.85, 0.4), 20, 200)
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	shake(10)
	hud.banner("INTO THE PORTAL!", Color(0.6, 0.9, 1.0))
	_clear_resume()
	await get_tree().create_timer(2.5).timeout
	hud.show_message("WORLD 2 COMPLETE!",
		"You dive into the time portal just as the supercomputer goes dark!\n" +
		"Every e-book is safe on the Grand Library's servers again.\n" +
		"But the portal is spinning you back... way, WAY back... to the age of dinosaurs!\n\n" +
		"E-books recovered: %d / %d\n\n" % [books_collected, books_total] +
		reward + "\n\nPress Enter to return to the world map")


## The crash wave: a wall of red static and broken data that sweeps to the right.
## Everything left of `x` is drawn as corrupted.
class CrashWave extends Node2D:
	var x := 0.0
	var height := 544.0
	var stopped := false
	var glitch := 0.0
	var t := 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		t += delta
		glitch = maxf(glitch - delta * 2.0, 0.0)
		if stopped:
			modulate.a = maxf(modulate.a - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var band := 18.0
		var bands := int(height / band) + 1
		var shove := glitch * 30.0
		# the solid body of the wave, with a jagged leading edge that flickers
		for i in bands:
			var y := i * band
			var edge := x + sin(t * 9.0 + i * 1.7) * 10.0 + sin(t * 23.0 + i * 4.1) * 6.0 + shove
			draw_rect(Rect2(x - 1400.0, y, edge - (x - 1400.0), band), Color(0.18, 0.02, 0.08, 0.92))
			var flick := 0.5 + 0.5 * sin(t * 30.0 + i * 2.3)
			draw_rect(Rect2(edge - 26.0, y, 26.0, band), Color(1.0, 0.15, 0.35, 0.35 + 0.35 * flick))
			draw_rect(Rect2(edge - 4.0, y, 4.0, band), Color(1.0, 0.75, 0.85, 0.9))
		# torn scanlines sticking out ahead of the wave
		for k in 10:
			var ky := fmod(k * 131.0 + t * 260.0 * (1.0 + k % 3), height)
			var kw := 30.0 + fmod(k * 53.0 + t * 90.0, 70.0)
			draw_rect(Rect2(x - 40.0, ky, kw + 40.0, 3.0), Color(1.0, 0.3, 0.5, 0.55))
		# broken bits and error glyphs tumbling inside it
		for k in 24:
			var gx := x - 30.0 - fmod(k * 97.0 + t * 40.0, 600.0)
			var gy := fmod(k * 61.0 + t * (60.0 + k * 7.0), height)
			var glyph: String = ["0", "1", "?", "!", "#", "ERR"][(k + int(t * 6.0)) % 6]
			draw_string(font, Vector2(gx, gy), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.5, 0.65, 0.7))
