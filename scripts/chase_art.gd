extends Node2D
## Draws the night-time city for the skateboard chase: streets, brick walls, grind rails,
## ramps and street lamps. A separate Skyline node scrolls slowly behind everything.

var grid: Array = []
var tile := 32
var cols := 0
var rows := 0


class Skyline extends Node2D:
	## Far-away buildings, stars and the moon. Lives inside a Parallax2D.
	const W := 1920.0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var h := 544.0
		# sky bands
		for i in 32:
			var c := Color(0.07, 0.05, 0.12).lerp(Color(0.2, 0.12, 0.25), i / 31.0)
			draw_rect(Rect2(0, i * h / 32.0, W, h / 32.0 + 1), c)
		for i in 70:
			var s := rng.randf_range(0.8, 1.8)
			draw_circle(Vector2(rng.randf() * W, rng.randf() * 260.0), s, Color(1, 1, 0.9, rng.randf_range(0.3, 0.9)))
		draw_circle(Vector2(1500, 90), 34, Color(0.95, 0.93, 0.78))
		draw_circle(Vector2(1488, 82), 6, Color(0.85, 0.83, 0.7))
		draw_circle(Vector2(1512, 104), 4, Color(0.85, 0.83, 0.7))
		# two layers of buildings with lit windows
		for layer in 2:
			var x := 0.0
			var base := Color(0.12, 0.08, 0.18) if layer == 0 else Color(0.08, 0.05, 0.12)
			while x < W:
				var bw := rng.randf_range(70, 150)
				var top := rng.randf_range(150, 300) + layer * 70.0
				if x + bw > W:
					bw = W - x
				draw_rect(Rect2(x, top, bw - 4, h - top), base)
				if rng.randf() < 0.3:
					draw_rect(Rect2(x + bw * 0.4, top - 24, 6, 24), base)
				var wy := top + 14
				while wy < h - 20:
					var wx := x + 10
					while wx < x + bw - 18:
						if rng.randf() < 0.35:
							draw_rect(Rect2(wx, wy, 7, 9), Color(1.0, 0.85, 0.45, 0.55 if layer == 0 else 0.8))
						wx += 16
					wy += 22
				x += bw


func setup(g: Array, t: int) -> void:
	grid = g
	tile = t
	rows = g.size()
	cols = g[0].size() if rows > 0 else 0
	z_index = -10


func _solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return true
	return grid[y][x] == "#"


func _draw() -> void:
	var w := cols * tile
	var arena_px := 0
	for x in cols:
		for y in rows:
			if grid[y][x] == "A":
				arena_px = x * tile

	# street lamps along the ground
	var x := 6
	while x < cols - 2:
		var gy := -1
		for y in rows:
			if grid[y][x] == "#":
				gy = y
				break
		if gy > 2 and not _solid(x, gy - 1):
			var base := Vector2((x + 0.5) * tile, gy * tile)
			draw_rect(Rect2(base.x - 2, base.y - 120, 4, 120), Color(0.18, 0.18, 0.22))
			draw_rect(Rect2(base.x - 2, base.y - 120, 18, 4), Color(0.18, 0.18, 0.22))
			draw_circle(base + Vector2(16, -112), 26, Color(1.0, 0.85, 0.45, 0.08))
			draw_circle(base + Vector2(16, -114), 5, Color(1.0, 0.9, 0.55))
		x += 14

	# the dead-end alley: tall brick walls closing in
	if arena_px > 0:
		draw_rect(Rect2(arena_px, 0, w - arena_px, rows * tile), Color(0.16, 0.08, 0.09, 0.85))
		var by := 0
		while by < rows * tile:
			var off := 0 if (by / 16) % 2 == 0 else 16
			var bx := arena_px - off
			while bx < w:
				draw_rect(Rect2(bx + 1, by + 1, 30, 14), Color(0.24, 0.11, 0.11, 0.6))
				bx += 32
			by += 16
		var sign_pos := Vector2(arena_px + 120, 120)
		draw_rect(Rect2(sign_pos, Vector2(200, 44)), Color(0.12, 0.1, 0.14))
		draw_rect(Rect2(sign_pos + Vector2(3, 3), Vector2(194, 38)), Color(0.9, 0.3, 0.45, 0.25))
		draw_string(ThemeDB.fallback_font, sign_pos + Vector2(0, 30), "DEAD END", HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(1.0, 0.45, 0.6))

	for ty in rows:
		for tx in cols:
			var c: String = grid[ty][tx]
			var p := Vector2(tx * tile, ty * tile)
			match c:
				"#":
					_draw_block(tx, ty, p)
				"=":
					# metal grind rail on posts
					draw_rect(Rect2(p.x, p.y, tile, 6), Color(0.72, 0.75, 0.82))
					draw_rect(Rect2(p.x, p.y, tile, 2), Color(0.95, 0.97, 1.0))
					draw_rect(Rect2(p.x, p.y + 5, tile, 1), Color(0.35, 0.37, 0.45))
					if tx % 3 == 0:
						draw_rect(Rect2(p.x + 13, p.y + 6, 5, 30), Color(0.3, 0.32, 0.38))
				"/":
					var ramp := PackedVector2Array([p + Vector2(0, tile), p + Vector2(tile, tile), p + Vector2(tile, 12)])
					draw_colored_polygon(ramp, Color(0.72, 0.5, 0.28))
					draw_line(p + Vector2(0, tile), p + Vector2(tile, 12), Color(0.9, 0.7, 0.4), 3.0)
					draw_line(p + Vector2(tile - 1, 12), p + Vector2(tile - 1, tile), Color(0.45, 0.3, 0.16), 2.0)
					draw_line(p + Vector2(10, tile - 2), p + Vector2(tile - 2, 18), Color(1.0, 0.85, 0.3, 0.7), 2.0)


func _draw_block(tx: int, ty: int, p: Vector2) -> void:
	var top_open := not _solid(tx, ty - 1)
	var ground := ty >= rows - 2
	if ground:
		# street: dark asphalt with a sidewalk curb on top
		draw_rect(Rect2(p, Vector2(tile, tile)), Color(0.17, 0.16, 0.2))
		if top_open:
			draw_rect(Rect2(p.x, p.y, tile, 8), Color(0.55, 0.55, 0.6))
			draw_rect(Rect2(p.x, p.y, tile, 2), Color(0.75, 0.75, 0.8))
			draw_line(Vector2(p.x + tile, p.y), Vector2(p.x + tile, p.y + 8), Color(0.35, 0.35, 0.4), 1.0)
		elif ty == rows - 1 and tx % 4 == 0:
			draw_rect(Rect2(p.x + 4, p.y + 12, 18, 3), Color(0.85, 0.75, 0.3, 0.6))
	else:
		# brick walls and stacked crates
		draw_rect(Rect2(p, Vector2(tile, tile)), Color(0.5, 0.22, 0.18))
		for row in 2:
			var off := 0.0 if (row + ty) % 2 == 0 else 8.0
			var by := p.y + row * 16
			draw_line(Vector2(p.x, by + 15), Vector2(p.x + tile, by + 15), Color(0.3, 0.13, 0.11), 2.0)
			var bx := p.x + off
			while bx < p.x + tile:
				draw_line(Vector2(bx, by), Vector2(bx, by + 15), Color(0.3, 0.13, 0.11), 2.0)
				bx += 16
		if top_open:
			draw_rect(Rect2(p.x - 1, p.y, tile + 2, 6), Color(0.6, 0.6, 0.64))
			draw_rect(Rect2(p.x - 1, p.y, tile + 2, 2), Color(0.8, 0.8, 0.85))
	if not _solid(tx - 1, ty):
		draw_rect(Rect2(p.x, p.y, 2, tile), Color(0.1, 0.08, 0.1))
	if not _solid(tx + 1, ty):
		draw_rect(Rect2(p.x + tile - 2, p.y, 2, tile), Color(0.1, 0.08, 0.1))
