extends Node2D
## Draws the prehistoric world: grassy rock, log platforms, bubbling lava in the pits and
## the T-Rex arena gate. Backdrop is the far-off sky with a smoking volcano and ferns.

var grid: Array = []
var tile := 32
var cols := 0
var rows := 0
var gate_closed := false
var t := 0.0
var lava_cols := {}

const ROCK := Color(0.42, 0.32, 0.26)
const GRASS := Color(0.35, 0.65, 0.25)
const LAVA := Color(1.0, 0.45, 0.1)


## Sunset sky, a smoking volcano and giant fern silhouettes (scrolls with parallax).
class Backdrop extends Node2D:
	const W := 960.0
	const H := 560.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		# sky bands
		var bands := [Color(0.98, 0.62, 0.35), Color(0.95, 0.5, 0.35), Color(0.75, 0.35, 0.4), Color(0.45, 0.22, 0.35)]
		for i in bands.size():
			draw_rect(Rect2(0, i * H / 4.0, W, H / 4.0 + 1), bands[bands.size() - 1 - i])
		draw_circle(Vector2(720, 150), 46.0, Color(1.0, 0.85, 0.5, 0.9))   # big low sun
		# volcano
		var base := 470.0
		draw_colored_polygon(PackedVector2Array([Vector2(180, base), Vector2(350, 170), Vector2(410, 170), Vector2(600, base)]), Color(0.3, 0.18, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(350, 170), Vector2(410, 170), Vector2(395, 210), Vector2(370, 230), Vector2(355, 200)]), Color(1.0, 0.45, 0.15))
		for i in 5:
			var k := fmod(t * 0.12 + i * 0.2, 1.0)
			var pos := Vector2(380 + sin(k * 6.0 + i) * 25.0 + k * 60.0, 160 - k * 150.0)
			draw_circle(pos, 16.0 + k * 34.0, Color(0.35, 0.3, 0.32, 0.55 * (1.0 - k)))
		# distant hills
		var hills := PackedVector2Array([Vector2(0, H)])
		for i in 13:
			hills.append(Vector2(i * W / 12.0, 430 + sin(i * 1.7) * 25.0))
		hills.append(Vector2(W, H))
		draw_colored_polygon(hills, Color(0.25, 0.3, 0.22))
		# ferns
		for i in 6:
			var fx := 70.0 + i * 160.0
			var fy := 470.0 + (i % 2) * 20.0
			for j in 5:
				var a := -PI / 2 + (j - 2) * 0.45 + sin(t * 0.8 + i) * 0.04
				var tip := Vector2(fx, fy) + Vector2(cos(a), sin(a)) * (60.0 - absi(j - 2) * 8.0)
				draw_line(Vector2(fx, fy), tip, Color(0.15, 0.25, 0.15), 6.0)
		draw_rect(Rect2(0, 480, W, H - 480), Color(0.15, 0.22, 0.14))


func setup(g: Array, ts: int) -> void:
	grid = g
	tile = ts
	rows = g.size()
	cols = g[0].size() if rows > 0 else 0
	z_index = -10
	# a column whose ground is missing is a lava pit
	for x in cols:
		if not _solid(x, rows - 1):
			lava_cols[x] = true


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
	var view := get_viewport_rect()
	var cam_x := 0.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam_x = cam.get_screen_center_position().x
	var x0 := maxi(int((cam_x - view.size.x) / tile), 0)
	var x1 := mini(int((cam_x + view.size.x) / tile) + 1, cols)

	# volcano zone: the air glows red where meteors fall
	for x in range(x0, x1):
		if grid[0][x] == "v":
			draw_rect(Rect2(x * tile, 0, tile, h), Color(0.9, 0.25, 0.05, 0.1 + 0.03 * sin(t * 2.0 + x * 0.2)))

	# lava pits
	for x in range(x0, x1):
		if lava_cols.has(x):
			var top := (rows - 1.4) * tile + sin(t * 2.0 + x) * 3.0
			draw_rect(Rect2(x * tile, top, tile, h - top + 60), LAVA)
			draw_rect(Rect2(x * tile, top, tile, 4), Color(1.0, 0.85, 0.35))
			var b := fmod(t * 0.9 + _hash(x, 1) % 100 / 100.0, 1.0)
			draw_circle(Vector2(x * tile + 8 + _hash(x, 2) % 16, top - b * 10.0), 3.0 * (1.0 - b) + 1.0, Color(1.0, 0.7, 0.2, 1.0 - b))

	for y in rows:
		for x in range(x0, x1):
			var c: String = grid[y][x]
			var r := Rect2(x * tile, y * tile, tile, tile)
			if c == "#":
				var hsh := _hash(x, y)
				draw_rect(r, ROCK.darkened((hsh % 5) * 0.03))
				draw_circle(r.position + Vector2(6 + hsh % 20, 8 + (hsh / 20) % 18), 3.0, ROCK.darkened(0.2))
				draw_circle(r.position + Vector2(4 + (hsh / 7) % 22, 4 + (hsh / 3) % 22), 2.0, ROCK.lightened(0.12))
				if not _solid(x, y - 1):
					draw_rect(Rect2(r.position, Vector2(tile, 7)), GRASS)
					for i in 4:
						var gx := r.position.x + 3 + i * 8
						draw_colored_polygon(PackedVector2Array([Vector2(gx, r.position.y + 1), Vector2(gx + 5, r.position.y + 1), Vector2(gx + 2, r.position.y - 4 - (hsh + i) % 3)]), GRASS.lightened(0.1))
					draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(tile, 2)), GRASS.darkened(0.35))
			elif c == "=":
				var wood := Color(0.55, 0.35, 0.18)
				draw_rect(Rect2(r.position, Vector2(tile, 9)), wood)
				draw_rect(Rect2(r.position, Vector2(tile, 2)), wood.lightened(0.25))
				draw_line(r.position + Vector2(4, 5), r.position + Vector2(tile - 6, 5), wood.darkened(0.3), 1.0)
				if x == 0 or grid[y][x - 1] != "=":
					draw_circle(r.position + Vector2(2, 4.5), 4.5, wood.lightened(0.15))
					draw_arc(r.position + Vector2(2, 4.5), 2.5, 0, TAU, 10, wood.darkened(0.3), 1.0)
			elif c == "G" and gate_closed:
				for i in 3:
					var bx := r.position.x + 5 + i * 11
					draw_rect(Rect2(bx - 3, r.position.y, 7, tile), Color(0.5, 0.32, 0.16))
					draw_line(Vector2(bx - 1, r.position.y), Vector2(bx - 1, r.end.y), Color(0.65, 0.45, 0.25), 1.0)
				draw_line(r.position + Vector2(0, 10), r.position + Vector2(tile, 10), Color(0.85, 0.75, 0.5), 2.0)
