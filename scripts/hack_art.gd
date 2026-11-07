extends Node2D
## Draws the inside of the supercomputer: glowing circuit blocks, data bridges, server racks
## in the background and the core-chamber gate. DataRain is the falling-binary backdrop.

var grid: Array = []
var tile := 32
var cols := 0
var rows := 0
var gate_closed := false
var t := 0.0

const NEON := Color(0.25, 0.95, 0.85)
const BLOCK := Color(0.07, 0.1, 0.16)


## Falling columns of 1s and 0s far in the background (scrolls with parallax).
class DataRain extends Node2D:
	const W := 960.0
	const H := 560.0
	var t := 0.0
	var columns := []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 40:
			columns.append({
				"x": i * W / 40.0 + rng.randf_range(-4, 4),
				"speed": rng.randf_range(30, 90),
				"off": rng.randf_range(0, H),
				"len": rng.randi_range(5, 12),
				"seed": rng.randi(),
			})

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.06))
		for c in columns:
			var head: float = fmod(c.off + t * c.speed, H + c.len * 16.0)
			for j in c.len:
				var y: float = head - j * 16.0
				if y < 0 or y > H:
					continue
				var a: float = 0.5 * (1.0 - float(j) / c.len)
				var bit := "1" if ((c.seed + j + int(t * 3.0)) % 3 == 0) else "0"
				var col := Color(0.6, 1.0, 0.8, a + 0.2) if j == 0 else Color(0.15, 0.7, 0.45, a * 0.6)
				draw_string(font, Vector2(c.x, y), bit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


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
	var w := cols * tile
	var h := rows * tile
	var view := get_viewport_rect()
	var cam_x := 0.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam_x = cam.get_screen_center_position().x
	var x0 := maxi(int((cam_x - view.size.x) / tile), 0)
	var x1 := mini(int((cam_x + view.size.x) / tile) + 1, cols)

	# server racks behind the play area (only around the camera)
	for rx in range(x0 - x0 % 5, x1, 5):
		var hsh := _hash(rx, 7)
		var top := 2 + hsh % 4
		var rect := Rect2(rx * tile + 8, top * tile, tile * 4 - 16, h - top * tile)
		draw_rect(rect, Color(0.05, 0.07, 0.12, 0.85))
		draw_rect(rect, Color(0.12, 0.18, 0.28, 0.6), false, 1.0)
		var ly := rect.position.y + 12
		var i := 0
		while ly < rect.end.y - 8:
			draw_rect(Rect2(rect.position.x + 6, ly, rect.size.x - 12, 3), Color(0.1, 0.13, 0.2))
			var blink := (sin(t * (1.5 + (hsh + i) % 5) + i) > 0.3)
			var lc := Color(0.3, 1.0, 0.6) if (hsh + i) % 3 != 0 else Color(1.0, 0.7, 0.2)
			if blink:
				draw_circle(Vector2(rect.position.x + 10 + (i * 7) % int(rect.size.x - 20), ly + 1.5), 1.6, lc)
			ly += 14
			i += 1

	# the core chamber glows red
	var gate_px := -1
	for y in rows:
		for gx in cols:
			if grid[y][gx] == "G":
				gate_px = gx * tile
	if gate_px >= 0:
		draw_rect(Rect2(gate_px, 0, w - gate_px, h), Color(0.3, 0.02, 0.06, 0.25 + 0.06 * sin(t * 2.0)))

	# tiles
	for y in rows:
		for x in range(x0, x1):
			var c: String = grid[y][x]
			var r := Rect2(x * tile, y * tile, tile, tile)
			if c == "#":
				draw_rect(r, BLOCK)
				var hsh := _hash(x, y)
				# circuit traces
				var tc := Color(0.12, 0.3, 0.35)
				var mid := r.position + Vector2(8 + hsh % 16, 8 + (hsh / 16) % 16)
				draw_line(mid, Vector2(r.position.x, mid.y), tc, 1.5)
				draw_line(mid, Vector2(mid.x, r.end.y), tc, 1.5)
				draw_circle(mid, 2.5, tc.lightened(0.2))
				if hsh % 7 == 0:
					var pulse := 0.5 + 0.5 * sin(t * 3.0 + x)
					draw_circle(mid, 2.0, Color(0.4, 1.0, 0.9, pulse))
				# neon edges where the block is exposed
				var edge := NEON
				edge.a = 0.75
				if not _solid(x, y - 1):
					draw_line(r.position, Vector2(r.end.x, r.position.y), edge, 2.0)
				if not _solid(x - 1, y):
					draw_line(r.position, Vector2(r.position.x, r.end.y), Color(edge, 0.35), 1.5)
				if not _solid(x + 1, y):
					draw_line(Vector2(r.end.x, r.position.y), r.end, Color(edge, 0.35), 1.5)
			elif c == "=":
				var col := Color(0.4, 0.8, 1.0)
				draw_rect(Rect2(r.position, Vector2(tile, 6)), Color(col, 0.35))
				draw_line(r.position + Vector2(0, 1), r.position + Vector2(tile, 1), col, 2.0)
				# data packets zipping along the bridge
				var px := fmod(t * 60.0 + x * 11.0, float(tile))
				draw_rect(Rect2(r.position + Vector2(px, 2), Vector2(4, 2)), Color(1, 1, 1, 0.8))
			elif c == "G" and gate_closed:
				draw_rect(r, Color(0.25, 0.05, 0.1))
				for i in 3:
					var bx := r.position.x + 6 + i * 10
					draw_line(Vector2(bx, r.position.y), Vector2(bx, r.end.y), Color(1.0, 0.3, 0.35, 0.8 + 0.2 * sin(t * 12.0 + i)), 3.0)
