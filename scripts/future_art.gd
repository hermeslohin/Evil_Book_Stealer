extends Node2D
## Draws the year-3000 city: steel blocks with neon trim, glowing grates, the Cyborg's
## propaganda holograms and the arena force-field gate. Backdrop is the megacity skyline.

var grid: Array = []
var tile := 32
var cols := 0
var rows := 0
var gate_closed := false
var t := 0.0

const STEEL := Color(0.16, 0.16, 0.22)
const NEON := Color(0.95, 0.35, 0.85)
const SIGNS := ["READING IS BANNED", "OBEY THE CYBORG", "BOOKS = BAD", "ALL HAIL KING STEALER"]


## Megacity skyline under a red sky, with flying cars and searchlights (scrolls with parallax).
class Backdrop extends Node2D:
	const W := 960.0
	const H := 560.0
	var t := 0.0
	var towers := []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3000
		var x := 0.0
		while x < W:
			var w := rng.randf_range(40, 90)
			towers.append({"x": x, "w": w, "h": rng.randf_range(160, 380), "seed": rng.randi()})
			x += w + rng.randf_range(4, 18)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var bands := [Color(0.1, 0.03, 0.12), Color(0.25, 0.05, 0.15), Color(0.45, 0.08, 0.15), Color(0.6, 0.15, 0.12)]
		for i in bands.size():
			draw_rect(Rect2(0, i * H / 4.0, W, H / 4.0 + 1), bands[i])
		draw_circle(Vector2(200, 110), 40.0, Color(1.0, 0.35, 0.3, 0.8))   # red moon
		# searchlights sweeping the sky
		for i in 2:
			var bx := 300.0 + i * 380.0
			var a := -PI / 2 + sin(t * 0.6 + i * 2.0) * 0.5
			var d := Vector2(cos(a), sin(a))
			draw_colored_polygon(PackedVector2Array([Vector2(bx, 470), Vector2(bx, 470) + d.rotated(-0.06) * 520.0, Vector2(bx, 470) + d.rotated(0.06) * 520.0]), Color(1.0, 0.9, 0.7, 0.08))
		for tw in towers:
			var r := Rect2(tw.x, 500 - tw.h, tw.w, tw.h + 60)
			draw_rect(r, Color(0.07, 0.05, 0.1))
			var rng := RandomNumberGenerator.new()
			rng.seed = tw.seed
			var y := r.position.y + 10
			while y < 500:
				var wx := r.position.x + 6
				while wx < r.end.x - 8:
					if rng.randf() < 0.35:
						draw_rect(Rect2(wx, y, 5, 4), Color(1.0, 0.4, 0.7, 0.5) if rng.randf() < 0.5 else Color(0.4, 0.9, 1.0, 0.45))
					wx += 10
				y += 12
			draw_line(r.position + Vector2(tw.w / 2, 0), r.position + Vector2(tw.w / 2, -18), Color(0.3, 0.3, 0.35), 2.0)
			if int(t * 2.0 + tw.seed % 7) % 2 == 0:
				draw_circle(r.position + Vector2(tw.w / 2, -18), 2.5, Color(1.0, 0.2, 0.2))
		# flying cars zipping across
		for i in 6:
			var lane := 150.0 + i * 45.0
			var sp := 80.0 + i * 25.0
			var cx := fmod(t * sp * (1 if i % 2 == 0 else -1) + i * 300.0, W + 60.0)
			if cx < 0:
				cx += W + 60.0
			draw_rect(Rect2(cx - 30, lane, 14, 4), Color(0.6, 0.6, 0.7))
			draw_circle(Vector2(cx - 30 + (14 if i % 2 == 0 else 0), lane + 2), 2.0, Color(1.0, 1.0, 0.7))


func setup(g: Array, ts: int) -> void:
	grid = g
	tile = ts
	rows = g.size()
	cols = g[0].size() if rows > 0 else 0
	z_index = -10


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return true
	return grid[y][x] == "#"


func _hash(x: int, y: int) -> int:
	return abs((x * 73856093) ^ (y * 19349663))


func _draw() -> void:
	var h := rows * tile
	var w := cols * tile
	var view := get_viewport_rect()
	var cam_x := 0.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam_x = cam.get_screen_center_position().x
	var x0 := maxi(int((cam_x - view.size.x) / tile), 0)
	var x1 := mini(int((cam_x + view.size.x) / tile) + 1, cols)
	var font := ThemeDB.fallback_font

	# the throne room behind the gate glows red
	var gate_px := -1
	for y in rows:
		for gx in cols:
			if grid[y][gx] == "G":
				gate_px = gx * tile
	if gate_px >= 0 and x1 * tile > gate_px:
		draw_rect(Rect2(gate_px, 0, w - gate_px, h), Color(0.4, 0.02, 0.08, 0.3 + 0.06 * sin(t * 2.0)))
		var banner_x := gate_px + 13 * tile
		draw_rect(Rect2(banner_x, 40, 6 * tile, 70), Color(0.38, 0.16, 0.5, 0.85))
		draw_string(font, Vector2(banner_x, 85), "KING STEALER", HORIZONTAL_ALIGNMENT_CENTER, 6 * tile, 26, Color(0.95, 0.8, 0.25))

	for y in rows:
		for x in range(x0, x1):
			var c: String = grid[y][x]
			var r := Rect2(x * tile, y * tile, tile, tile)
			if c == "#":
				draw_rect(r, STEEL)
				draw_rect(r.grow(-2), STEEL.lightened(0.05), false, 1.0)
				var hsh := _hash(x, y)
				if hsh % 5 == 0:
					draw_circle(r.position + Vector2(6, 6), 1.5, Color(0.4, 0.42, 0.5))
					draw_circle(r.position + Vector2(26, 26), 1.5, Color(0.4, 0.42, 0.5))
				if hsh % 9 == 0 and _solid(x, y - 1):
					var on := sin(t * 3.0 + x) > 0.0
					draw_rect(Rect2(r.position + Vector2(10, 12), Vector2(12, 4)), Color(1.0, 0.3, 0.6, 0.8) if on else Color(0.3, 0.1, 0.2))
				if not _solid(x, y - 1):
					draw_rect(Rect2(r.position, Vector2(tile, 3)), NEON)
					draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(tile, 3)), Color(NEON, 0.25))
				if not _solid(x, y + 1):
					draw_rect(Rect2(r.position + Vector2(0, tile - 2), Vector2(tile, 2)), Color(0.3, 0.9, 1.0, 0.6))
			elif c == "=":
				draw_rect(Rect2(r.position, Vector2(tile, 6)), Color(0.2, 0.22, 0.3))
				for i in 4:
					draw_line(r.position + Vector2(4 + i * 8, 1), r.position + Vector2(4 + i * 8, 5), Color(0.1, 0.1, 0.14), 2.0)
				draw_line(r.position, r.position + Vector2(tile, 0), Color(0.3, 0.9, 1.0), 2.0)
			elif c == "Y":
				# propaganda hologram: the Cyborg's face and a slogan
				var sr := Rect2(r.position.x - tile, r.position.y, tile * 4, tile * 2)
				var flick := 0.55 + 0.1 * sin(t * 9.0 + x) + (0.25 if int(t * 7.0 + x) % 23 == 0 else 0.0)
				draw_rect(sr, Color(0.3, 0.9, 1.0, 0.12 * flick))
				draw_rect(sr, Color(0.3, 0.9, 1.0, 0.5 * flick), false, 1.5)
				var face := sr.position + Vector2(18, 30)
				draw_circle(face, 13.0, Color(0.6, 0.3, 0.8, 0.6 * flick))
				draw_circle(face + Vector2(-4, 0), 2.5, Color(1.0, 0.9, 0.3, flick))
				draw_circle(face + Vector2(4, 0), 2.5, Color(1.0, 0.2, 0.2, flick))
				var text: String = SIGNS[_hash(x, y) % SIGNS.size()]
				draw_string(font, sr.position + Vector2(36, 28), text, HORIZONTAL_ALIGNMENT_LEFT, tile * 4 - 40, 12, Color(0.6, 1.0, 1.0, flick))
				for i in 4:
					var sy := sr.position.y + fmod(t * 30.0 + i * 16.0, sr.size.y)
					draw_line(Vector2(sr.position.x, sy), Vector2(sr.end.x, sy), Color(0.6, 1.0, 1.0, 0.08), 1.0)
			elif c == "G" and gate_closed:
				draw_rect(r, Color(1.0, 0.15, 0.3, 0.25 + 0.1 * sin(t * 10.0)))
				for i in 4:
					var yy := r.position.y + fmod(t * 50.0 + i * 8.0, float(tile))
					draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(1.0, 0.5, 0.6, 0.7), 1.5)
