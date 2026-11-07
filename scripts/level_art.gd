extends Node2D
## Draws the library: background shelves, bookshelf blocks, wooden planks and the boss gate.

var grid: Array = []
var tile := 32
var cols := 0
var rows := 0
var gate_closed := false


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


func _hash(x: int, y: int) -> int:
	return abs((x * 73856093) ^ (y * 19349663))


func _draw() -> void:
	var w := cols * tile
	var h := rows * tile
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	# back wall
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.07, 0.1))
	var gate_px := 0
	for y in rows:
		for x in cols:
			if grid[y][x] == "G":
				gate_px = x * tile
	if gate_px > 0:
		draw_rect(Rect2(gate_px, 0, w - gate_px, h), Color(0.1, 0.05, 0.15))

	# distant bookcases
	var x := 0.0
	while x < w:
		var cw := rng.randf_range(120, 220)
		var top := rng.randf_range(40, 140)
		var case_col := Color(0.15, 0.1, 0.1)
		draw_rect(Rect2(x + 6, top, cw - 12, h - top), case_col)
		var shelf_y := top + 10
		while shelf_y < h - 40:
			var bx := x + 14
			while bx < x + cw - 20:
				var bw := rng.randf_range(5, 10)
				var bh := rng.randf_range(22, 34)
				var hue := rng.randf()
				# empty gaps where books were stolen
				if rng.randf() > 0.35:
					draw_rect(Rect2(bx, shelf_y + 38 - bh, bw, bh), Color.from_hsv(hue, 0.3, 0.22))
				bx += bw + 1
			draw_rect(Rect2(x + 8, shelf_y + 38, cw - 16, 5), Color(0.2, 0.13, 0.1))
			shelf_y += 48
		x += cw
	# moonlit windows
	for i in range(int(w / 700.0)):
		var wx := 300.0 + i * 700.0
		draw_rect(Rect2(wx, 40, 70, 110), Color(0.12, 0.1, 0.18))
		draw_rect(Rect2(wx + 6, 46, 58, 98), Color(0.3, 0.35, 0.55))
		draw_line(Vector2(wx + 35, 46), Vector2(wx + 35, 144), Color(0.12, 0.1, 0.18), 4)
		draw_line(Vector2(wx + 6, 95), Vector2(wx + 64, 95), Color(0.12, 0.1, 0.18), 4)
		draw_circle(Vector2(wx + 50, 65), 8, Color(0.9, 0.9, 0.75))

	# tiles
	for ty in rows:
		for tx in cols:
			var c: String = grid[ty][tx]
			var p := Vector2(tx * tile, ty * tile)
			match c:
				"#":
					_draw_block(tx, ty, p)
				"=":
					draw_rect(Rect2(p.x, p.y, tile, 8), Color(0.62, 0.42, 0.24))
					draw_rect(Rect2(p.x, p.y, tile, 2), Color(0.78, 0.58, 0.35))
					draw_line(Vector2(p.x + tile, p.y), Vector2(p.x + tile, p.y + 8), Color(0.4, 0.26, 0.15), 1)
					if tx % 3 == 0:
						draw_colored_polygon(PackedVector2Array([p + Vector2(10, 8), p + Vector2(22, 8), p + Vector2(16, 18)]), Color(0.4, 0.26, 0.15))
				"G":
					if gate_closed:
						draw_rect(Rect2(p.x + 2, p.y, tile - 4, tile), Color(0.1, 0.08, 0.12))
						for i in 4:
							draw_rect(Rect2(p.x + 4 + i * 7, p.y, 3, tile), Color(0.55, 0.55, 0.62))
						draw_rect(Rect2(p.x, p.y + 12, tile, 4), Color(0.45, 0.45, 0.52))


func _draw_block(tx: int, ty: int, p: Vector2) -> void:
	var wood := Color(0.42, 0.27, 0.16)
	draw_rect(Rect2(p, Vector2(tile, tile)), wood)
	if not _solid(tx, ty - 1):
		# polished top
		draw_rect(Rect2(p.x, p.y, tile, 6), Color(0.66, 0.45, 0.26))
		draw_rect(Rect2(p.x, p.y, tile, 2), Color(0.82, 0.62, 0.38))
	else:
		# shelf with books
		draw_rect(Rect2(p.x + 2, p.y + 2, tile - 4, tile - 6), Color(0.2, 0.12, 0.08))
		var hsh := _hash(tx, ty)
		var bx := p.x + 3
		var i := 0
		while bx < p.x + tile - 6:
			var bw := 4 + (hsh >> (i * 3)) % 4
			var bh := 16 + (hsh >> (i * 2 + 1)) % 9
			var hue := float((hsh >> i) % 100) / 100.0
			draw_rect(Rect2(bx, p.y + tile - 4 - bh, bw, bh), Color.from_hsv(hue, 0.55, 0.6))
			bx += bw + 1
			i += 1
	draw_rect(Rect2(p.x, p.y + tile - 4, tile, 4), Color(0.32, 0.2, 0.12))
	if not _solid(tx - 1, ty):
		draw_rect(Rect2(p.x, p.y, 2, tile), Color(0.3, 0.19, 0.11))
	if not _solid(tx + 1, ty):
		draw_rect(Rect2(p.x + tile - 2, p.y, 2, tile), Color(0.3, 0.19, 0.11))
