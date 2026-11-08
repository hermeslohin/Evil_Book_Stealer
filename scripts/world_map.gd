extends Node2D
## The world map: walk between the seven levels and the two shops, then press Space to go in.
## Also hosts the title screen (difficulty select) and the shop menus. Everything is drawn in code.

const Progress := preload("res://scripts/progress.gd")
const D := preload("res://scripts/difficulty.gd")
const MainScript := preload("res://scripts/main.gd")

const WALK_SPEED := 2.6   # nodes per second

# The path, in order. Shops open once you've beaten the level named in "need".
const NODES := [
	{"type": "level", "level": 1, "area": "Book Town", "pos": Vector2(85, 418)},
	{"type": "shop", "shop": "quill", "need": 1, "pos": Vector2(178, 322)},
	{"type": "level", "level": 2, "area": "Book Town", "pos": Vector2(282, 418)},
	{"type": "level", "level": 3, "area": "Book Town", "boss": true, "pos": Vector2(385, 300)},
	{"type": "level", "level": 4, "area": "Cyberspace", "pos": Vector2(482, 372)},
	{"type": "level", "level": 5, "area": "Cyberspace", "pos": Vector2(588, 330)},
	{"type": "shop", "shop": "bazaar", "need": 5, "pos": Vector2(655, 196)},
	{"type": "level", "level": 6, "pos": Vector2(762, 312)},
	{"type": "level", "level": 7, "pos": Vector2(880, 175)},
]
const BENDS := [38.0, -34.0, -40.0, 30.0, -26.0, -30.0, -38.0, 34.0]   # how much each path segment curves

# Land regions: center, radius, color. Drawn as overlapping blobs to make the island.
const REGIONS := [
	[Vector2(110, 400), 150.0, Color(0.38, 0.67, 0.37)],    # Book Town (Levels 1-3): library side
	[Vector2(200, 300), 110.0, Color(0.38, 0.67, 0.37)],
	[Vector2(270, 400), 140.0, Color(0.38, 0.67, 0.37)],    # Book Town: city side
	[Vector2(370, 290), 100.0, Color(0.38, 0.67, 0.37)],    # Book Town: the hideout
	[Vector2(500, 340), 85.0, Color(0.14, 0.24, 0.3)],      # Cyberspace (Levels 4-5): the mainframe
	[Vector2(578, 320), 80.0, Color(0.14, 0.24, 0.3)],
	[Vector2(655, 195), 85.0, Color(0.62, 0.52, 0.42)],
	[Vector2(765, 310), 115.0, Color(0.74, 0.55, 0.3)],     # prehistoric lands
	[Vector2(878, 172), 120.0, Color(0.36, 0.2, 0.5)],      # the year 3000
]

static var title_done := false
static var node_index := 0
static var known_open := -1

var hero_t := 0.0          # position along the path, in nodes (2.5 = halfway from node 2 to 3)
var target := 0
var anim := 0.0
var banner_text := ""
var banner_t := 0.0
var title_sel := 0          # 0 = Continue, 1 = New Game
var confirm_new := false    # New Game pressed once on a save that has progress

var shop_id := ""
var shop_sel := 0
var shop_say := ""
var shop_say_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level1 = MainScript.new()   # borrow its control setup
	level1._setup_input()
	level1.free()
	MainScript._clear_resume()

	# Walk to whatever just opened up since the last time we were here.
	var open := _open_count()
	if Progress.current_level > 0:
		node_index = _level_node(Progress.current_level)
	node_index = clampi(node_index, 0, open - 1)
	hero_t = node_index
	target = node_index
	if known_open >= 0 and open > known_open:
		target = mini(node_index + 1, open - 1)
		_banner("NEW PLACE UNLOCKED!")
	known_open = open


func _open_count() -> int:
	var n := 0
	for i in NODES.size():
		if not _is_open(i):
			break
		n += 1
	return n


func _is_open(i: int) -> bool:
	var node: Dictionary = NODES[i]
	if node.type == "level":
		return node.level <= Progress.unlocked
	return Progress.cleared[node.need - 1]


func _level_node(level: int) -> int:
	for i in NODES.size():
		if NODES[i].type == "level" and NODES[i].level == level:
			return i
	return 0


func _banner(text: String) -> void:
	banner_text = text
	banner_t = 2.4


# ---------------------------------------------------------------- input & update

func _process(delta: float) -> void:
	anim += delta
	banner_t = max(banner_t - delta, 0.0)
	shop_say_t = max(shop_say_t - delta, 0.0)
	queue_redraw()

	if not title_done:
		_title_input()
	elif shop_id != "":
		_shop_input()
	else:
		_map_input(delta)


func _pressed(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


## Title menu choices. "Continue" only shows up when there's a save to continue.
func _title_options() -> Array:
	return ["continue", "new"] if Progress.has_progress() else ["new"]


func _title_input() -> void:
	var options := _title_options()
	title_sel = clampi(title_sel, 0, options.size() - 1)
	if _pressed(["ui_up"]):
		title_sel = (title_sel - 1 + options.size()) % options.size()
		confirm_new = false
	elif _pressed(["ui_down"]):
		title_sel = (title_sel + 1) % options.size()
		confirm_new = false
	var step := 0
	if _pressed(["move_left", "ui_left"]):
		step = -1
	elif _pressed(["move_right", "ui_right"]):
		step = 1
	if step != 0:
		D.cycle(step)
	if confirm_new and _pressed(["to_map"]):
		confirm_new = false
		return
	if not _pressed(["ui_accept"]):
		return
	if options[title_sel] == "continue":
		title_done = true
	elif Progress.has_progress() and not confirm_new:
		confirm_new = true   # ask before wiping the save
	else:
		_start_new_game()


func _start_new_game() -> void:
	Progress.reset()
	node_index = 0
	hero_t = 0
	target = 0
	known_open = _open_count()
	confirm_new = false
	title_sel = 0
	title_done = true
	_banner("A NEW ADVENTURE BEGINS!")


func _map_input(delta: float) -> void:
	if _pressed(["to_map"]):
		title_done = false
		title_sel = 0
		return
	var open := _open_count()
	if _pressed(["move_right", "ui_right"]):
		target = mini(target + 1, open - 1)
	elif _pressed(["move_left", "ui_left"]):
		target = maxi(target - 1, 0)

	hero_t = move_toward(hero_t, float(target), WALK_SPEED * delta)
	var arrived := is_equal_approx(hero_t, float(target))
	if arrived:
		node_index = target

	if arrived and _pressed(["jump", "ui_accept"]):
		var node: Dictionary = NODES[node_index]
		if node.type == "level":
			Progress.launch_level(get_tree(), node.level)
		else:
			shop_id = node.shop
			shop_sel = 0
			shop_say = Progress.SHOPS[shop_id].greeting
			shop_say_t = 999.0


func _shop_input() -> void:
	var items: Array = Progress.SHOPS[shop_id].items
	var count := items.size() + 1   # + "Leave"
	if _pressed(["ui_down", "move_right"]):
		shop_sel = (shop_sel + 1) % count
	elif _pressed(["ui_up", "move_left"]):
		shop_sel = (shop_sel - 1 + count) % count
	if _pressed(["to_map"]) or (shop_sel == items.size() and _pressed(["jump", "ui_accept"])):
		shop_id = ""
		return
	if _pressed(["jump", "ui_accept"]):
		shop_say = Progress.buy(items[shop_sel])
		shop_say_t = 999.0


# ---------------------------------------------------------------- path helpers

func _path_point(t: float) -> Vector2:
	var i := clampi(int(floor(t)), 0, NODES.size() - 2)
	var f := clampf(t - i, 0.0, 1.0)
	var a: Vector2 = NODES[i].pos
	var b: Vector2 = NODES[i + 1].pos
	var perp := (b - a).orthogonal().normalized()
	return a.lerp(b, f) + perp * sin(f * PI) * BENDS[i]


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_world()
	_draw_path()
	for i in NODES.size():
		_draw_node(i)
	_draw_hero(_path_point(hero_t) + Vector2(0, -26))
	_draw_top_bar(font)
	if not title_done:
		_draw_title(font)
	elif shop_id != "":
		_draw_shop(font)
	else:
		_draw_info(font)
	if banner_t > 0.0:
		var a := clampf(banner_t / 0.4, 0.0, 1.0)
		_text(font, Vector2(0, 120), banner_text, 34, Color(1.0, 0.85, 0.3, a), 960, HORIZONTAL_ALIGNMENT_CENTER, a)


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, width := -1, align := HORIZONTAL_ALIGNMENT_LEFT, alpha := 1.0) -> void:
	draw_string_outline(font, pos, s, align, width, size, max(4, size / 4), Color(0, 0, 0, 0.85 * alpha))
	draw_string(font, pos, s, align, width, size, col)


func _draw_world() -> void:
	# ocean with little moving waves
	draw_rect(Rect2(0, 0, 960, 540), Color(0.13, 0.33, 0.55))
	for i in 26:
		var wx := fmod(i * 157.0 + anim * 12.0, 1000.0) - 20.0
		var wy := fmod(i * 89.0, 540.0)
		draw_arc(Vector2(wx, wy), 8.0, PI * 1.15, PI * 1.85, 6, Color(0.5, 0.75, 0.95, 0.5), 2.0)
	# sandy beaches, then the land regions on top
	for r in REGIONS:
		draw_circle(r[0], r[1] + 14.0, Color(0.93, 0.84, 0.6))
	for r in REGIONS:
		draw_circle(r[0], r[1], r[2])

	_deco_town()
	_deco_library(Vector2(85, 362))
	_deco_trees()
	_deco_city(Vector2(272, 362))
	_deco_hideout(Vector2(392, 246))
	_deco_mainframe(Vector2(530, 292))
	_deco_volcano(Vector2(770, 258))
	_deco_future(Vector2(880, 116))


func _deco_trees() -> void:
	for p in [Vector2(35, 300), Vector2(45, 470), Vector2(130, 250), Vector2(250, 250), Vector2(25, 390), Vector2(380, 470)]:
		draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 8)), Color(0.4, 0.25, 0.12))
		draw_circle(p + Vector2(0, -4), 9.0, Color(0.2, 0.5, 0.25))
		draw_circle(p + Vector2(-3, -7), 4.0, Color(0.3, 0.62, 0.32))


## Book Town: the library and the city share one area, joined by a cobbled street with little
## houses along it. Levels 1 and 2 both live here.
func _deco_town() -> void:
	var road := Color(0.72, 0.68, 0.6)
	draw_rect(Rect2(207, 380, 135, 46), Color(0.55, 0.58, 0.6))   # paved city block
	draw_line(Vector2(85, 446), Vector2(282, 446), road, 12.0)    # main street, library to city
	for x in range(93, 282, 14):
		draw_line(Vector2(x, 442), Vector2(x + 6, 442), road.darkened(0.15), 1.5)
	for h in [[Vector2(140, 404), Color(0.9, 0.6, 0.45)], [Vector2(172, 414), Color(0.6, 0.75, 0.9)], [Vector2(204, 402), Color(0.95, 0.85, 0.5)]]:
		var p: Vector2 = h[0]
		draw_rect(Rect2(p + Vector2(-10, -8), Vector2(20, 16)), h[1])
		draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -8), p + Vector2(13, -8), p + Vector2(0, -20)]), Color(0.6, 0.25, 0.2))
		draw_rect(Rect2(p + Vector2(-3, 1), Vector2(6, 7)), Color(0.4, 0.25, 0.15))
	_text(ThemeDB.fallback_font, Vector2(110, 222), "BOOK TOWN", 18, Color(1.0, 0.95, 0.75), 160, HORIZONTAL_ALIGNMENT_CENTER)


## The Book Stealer's hideout: a crooked old bookshop with boarded windows (Level 3, the boss).
func _deco_hideout(c: Vector2) -> void:
	var wall := Color(0.32, 0.22, 0.3)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-30, 24), c + Vector2(30, 24), c + Vector2(28, -24), c + Vector2(-32, -20)]), wall)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-38, -20), c + Vector2(34, -26), c + Vector2(-4, -54)]), Color(0.18, 0.12, 0.18))
	draw_rect(Rect2(c + Vector2(-8, 4), Vector2(16, 20)), Color(0.12, 0.07, 0.1))   # door
	for wx in [-22.0, 12.0]:
		var win := Rect2(c + Vector2(wx, -12), Vector2(12, 11))
		var glow := 0.55 + 0.45 * absf(sin(anim * 2.0 + wx))
		draw_rect(win, Color(0.9, 0.3, 0.9, glow))   # eerie purple light
		draw_line(win.position, win.end, Color(0.45, 0.3, 0.2), 2.0)   # boards
	# a crooked sign and a little flag with the thief's mark
	draw_line(c + Vector2(30, -26), c + Vector2(30, -48), Color(0.3, 0.2, 0.15), 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(30, -48), c + Vector2(46, -43 + sin(anim * 4.0) * 2.0), c + Vector2(30, -38)]), Color(0.6, 0.15, 0.6))


func _deco_library(c: Vector2) -> void:
	var stone := Color(0.9, 0.86, 0.76)
	draw_rect(Rect2(c + Vector2(-46, -20), Vector2(92, 36)), stone)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-54, -20), c + Vector2(54, -20), c + Vector2(0, -50)]), Color(0.7, 0.3, 0.25))
	for i in 5:
		draw_rect(Rect2(c + Vector2(-40 + i * 19, -16), Vector2(6, 30)), Color(1, 0.97, 0.9))
	draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 18)), Color(0.4, 0.25, 0.15))
	draw_rect(Rect2(c + Vector2(-50, 16), Vector2(100, 5)), Color(0.75, 0.7, 0.62))


func _deco_city(c: Vector2) -> void:
	var heights := [40, 62, 34, 78, 50, 30]
	for i in heights.size():
		var h: int = heights[i]
		var r := Rect2(c + Vector2(-60 + i * 20, 20 - h), Vector2(17, h))
		draw_rect(r, Color(0.3, 0.33, 0.42).lightened(0.05 * (i % 2)))
		for wy in range(int(r.position.y) + 5, int(r.end.y) - 4, 9):
			for wx in [3, 10]:
				var lit := int(i * 7 + wy) % 3 != 0
				draw_rect(Rect2(r.position.x + wx, wy, 4, 4), Color(1.0, 0.9, 0.5) if lit else Color(0.2, 0.22, 0.3))


## Cyberspace: the Book Stealer's supercomputer. Levels 4 and 5 both happen inside it.
func _deco_mainframe(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-26, -50), Vector2(52, 72)), Color(0.08, 0.1, 0.14))
	draw_rect(Rect2(c + Vector2(-26, -50), Vector2(52, 72)), Color(0.3, 1.0, 0.6), false, 2.0)
	for i in 6:
		var blink := int(anim * 4.0 + i * 1.7) % 3 == 0
		draw_circle(c + Vector2(-16 + (i % 3) * 16, -36 + (i / 3) * 14), 3.0, Color(0.3, 1.0, 0.6) if blink else Color(0.1, 0.35, 0.2))
	for i in 4:
		var y := -6 + i * 7
		draw_line(c + Vector2(-20, y), c + Vector2(20, y), Color(0.2, 0.7, 0.45, 0.7), 1.0)
	# circuit traces running out over the ground
	for d in [Vector2(-60, 30), Vector2(60, 26), Vector2(-40, -70), Vector2(50, -60)]:
		draw_line(c + Vector2(0, 10), c + Vector2(d.x, 10), Color(0.3, 1.0, 0.6, 0.35), 2.0)
		draw_line(c + Vector2(d.x, 10), c + d, Color(0.3, 1.0, 0.6, 0.35), 2.0)
		draw_circle(c + d, 3.0, Color(0.3, 1.0, 0.6, 0.6))
	_text(ThemeDB.fallback_font, Vector2(c.x - 80, c.y - 62), "CYBERSPACE", 18, Color(0.6, 1.0, 0.8), 160, HORIZONTAL_ALIGNMENT_CENTER)


func _deco_volcano(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-60, 22), c + Vector2(60, 22), c + Vector2(14, -38), c + Vector2(-14, -38)]), Color(0.42, 0.3, 0.24))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -38), c + Vector2(14, -38), c + Vector2(8, -18), c + Vector2(0, -28), c + Vector2(-6, -12)]), Color(1.0, 0.45, 0.1))
	for i in 3:
		var t := fmod(anim * 0.5 + i / 3.0, 1.0)
		draw_circle(c + Vector2(sin(t * 5.0 + i) * 8.0, -44 - t * 50.0), 6.0 + t * 8.0, Color(0.5, 0.5, 0.5, 0.6 * (1.0 - t)))
	# a palm-ish fern and a little dino silhouette
	draw_circle(c + Vector2(-70, 50), 6.0, Color(0.25, 0.45, 0.2))
	draw_rect(Rect2(c + Vector2(62, 40), Vector2(16, 8)), Color(0.3, 0.45, 0.25))
	draw_line(c + Vector2(76, 42), c + Vector2(84, 32), Color(0.3, 0.45, 0.25), 4.0)
	draw_circle(c + Vector2(85, 31), 4.0, Color(0.3, 0.45, 0.25))


func _deco_future(c: Vector2) -> void:
	var tw := [[-44, 50], [-22, 76], [0, 60], [22, 90], [44, 54]]
	for i in tw.size():
		var x: float = tw[i][0]
		var h: float = tw[i][1]
		draw_rect(Rect2(c + Vector2(x - 7, 30 - h), Vector2(14, h)), Color(0.15, 0.08, 0.25))
		var glow := Color.from_hsv(fmod(0.8 + i * 0.07 + sin(anim + i) * 0.03, 1.0), 0.7, 1.0)
		draw_rect(Rect2(c + Vector2(x - 7, 30 - h), Vector2(14, 3)), glow)
		draw_line(c + Vector2(x, 30 - h), c + Vector2(x, 22 - h), glow, 1.5)
	# a hover car zooming around
	var car := c + Vector2(cos(anim * 1.2) * 60.0, -40 + sin(anim * 2.4) * 10.0)
	draw_rect(Rect2(car - Vector2(7, 2), Vector2(14, 5)), Color(0.95, 0.4, 0.85))


func _draw_path() -> void:
	for i in NODES.size() - 1:
		var lit := _is_open(i) and _is_open(i + 1)
		var col := Color(1.0, 0.95, 0.8, 0.95) if lit else Color(0.2, 0.15, 0.1, 0.35)
		var steps := 14
		for s in range(1, steps):
			var p := _path_point(i + float(s) / steps)
			draw_circle(p, 3.0 if lit else 2.2, col)


func _draw_node(i: int) -> void:
	var node: Dictionary = NODES[i]
	var p: Vector2 = node.pos
	var open := _is_open(i)
	var here := i == target and title_done and shop_id == ""
	if here:
		draw_circle(p, 24.0 + sin(anim * 5.0) * 2.0, Color(1, 1, 1, 0.35))
	if node.type == "level":
		var cleared: bool = Progress.cleared[node.level - 1]
		var base := Color(0.95, 0.75, 0.25) if cleared else (Color(0.85, 0.25, 0.3) if open else Color(0.35, 0.33, 0.36))
		draw_circle(p + Vector2(0, 4), 18.0, Color(0, 0, 0, 0.35))
		if node.get("boss", false):   # boss levels get a spiky purple ring
			for k in 8:
				var a := k * TAU / 8.0 + anim * 0.6
				draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a - 0.2) * 19.0, p + Vector2.from_angle(a) * 27.0, p + Vector2.from_angle(a + 0.2) * 19.0]), Color(0.75, 0.3, 0.9))
		draw_circle(p, 18.0, base.darkened(0.35))
		draw_circle(p, 15.0, base)
		if open:
			var font := ThemeDB.fallback_font
			draw_string(font, p + Vector2(-6, 7), str(node.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1) if not cleared else Color(0.4, 0.2, 0.05))
			if cleared:
				_star(p + Vector2(14, -14), 7.0, Color(1.0, 0.95, 0.4))
		else:
			_lock(p)
	else:
		_draw_shop_hut(p, open, node.shop)


func _draw_shop_hut(p: Vector2, open: bool, id: String) -> void:
	var wall := Color(0.95, 0.88, 0.7) if open else Color(0.45, 0.43, 0.45)
	var stripe := (Color(0.3, 0.5, 0.95) if id == "quill" else Color(0.85, 0.35, 0.8)) if open else Color(0.35, 0.33, 0.36)
	draw_rect(Rect2(p + Vector2(-17, -6), Vector2(34, 22)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(p + Vector2(-16, -10), Vector2(32, 24)), wall)
	for k in 4:
		draw_rect(Rect2(p + Vector2(-19 + k * 10, -18), Vector2(10, 9)), stripe if k % 2 == 0 else Color(1, 1, 1) if open else wall)
	draw_rect(Rect2(p + Vector2(-5, 0), Vector2(10, 14)), Color(0.45, 0.28, 0.15))
	if open:
		_coin(p + Vector2(0, -28), 8.0)
	else:
		_lock(p + Vector2(0, -26))


func _lock(p: Vector2) -> void:
	draw_arc(p + Vector2(0, -3), 5.0, PI, TAU, 10, Color(0.85, 0.85, 0.9), 2.5)
	draw_rect(Rect2(p + Vector2(-7, -3), Vector2(14, 10)), Color(0.85, 0.85, 0.9))
	draw_circle(p + Vector2(0, 2), 2.0, Color(0.2, 0.2, 0.25))


func _coin(p: Vector2, r: float) -> void:
	draw_circle(p, r + 1.5, Color(0.55, 0.35, 0.05))
	draw_circle(p, r, Color(1.0, 0.8, 0.2))
	draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1.0, 0.95, 0.6))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


func _heart(p: Vector2, s: float, col: Color) -> void:
	draw_circle(p + Vector2(-5, -3) * s, 6.0 * s, col)
	draw_circle(p + Vector2(5, -3) * s, 6.0 * s, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10.5, -1) * s, p + Vector2(10.5, -1) * s, p + Vector2(0, 11) * s]), col)


func _draw_hero(p: Vector2) -> void:
	var walking := not is_equal_approx(hero_t, float(target))
	var bob := absf(sin(anim * 12.0)) * -3.0 if walking else sin(anim * 3.0) * 1.0
	var face := 1.0 if target >= hero_t else -1.0
	p.y += bob
	draw_set_transform(p, 0.0, Vector2(face, 1))
	var skin := Color(1.0, 0.82, 0.66)
	draw_circle(Vector2(0, 17), 9.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-6, 6, 4, 8), Color(0.2, 0.22, 0.35))
	draw_rect(Rect2(2, 6, 4, 8), Color(0.2, 0.22, 0.35))
	draw_rect(Rect2(-7, -4, 14, 11), Color(0.2, 0.62, 0.42))
	draw_circle(Vector2(0, -10), 7.0, skin)
	draw_circle(Vector2(-2, -14), 5.5, Color(0.45, 0.25, 0.12))
	draw_rect(Rect2(-7, -16, 12, 3), Color(0.45, 0.25, 0.12))
	draw_arc(Vector2(3, -10), 2.5, 0, TAU, 10, Color(0.1, 0.1, 0.1), 1.0)
	var scarf := Progress.scarf_color(anim)
	draw_rect(Rect2(-7, -5, 14, 3), scarf)
	draw_rect(Rect2(-12, -4 + sin(anim * 10.0), 5, 3), scarf)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_top_bar(font: Font) -> void:
	draw_rect(Rect2(0, 0, 960, 44), Color(0.05, 0.03, 0.08, 0.6))
	_text(font, Vector2(16, 30), "WORLD MAP", 24, Color(1.0, 0.85, 0.35))
	_text(font, Vector2(180, 29), D.label(), 16, D.color())
	# hearts & ink upgrades, packed items, coins
	var x := 560.0
	_heart(Vector2(x, 22), 0.8, Color(1.0, 0.3, 0.4))
	_text(font, Vector2(x + 14, 29), "+%d" % Progress.upgrades.heart, 16, Color.WHITE)
	x += 56
	draw_circle(Vector2(x, 25), 6.0, Color(0.3, 0.4, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 5.5, 23), Vector2(x + 5.5, 23), Vector2(x, 13)]), Color(0.3, 0.4, 1.0))
	_text(font, Vector2(x + 12, 29), "+%d" % Progress.bonus_ink(), 16, Color.WHITE)
	x += 56
	_mushroom(Vector2(x, 24), 0.8)
	_text(font, Vector2(x + 12, 29), "x%d" % Progress.items.mushroom, 16, Color.WHITE)
	x += 52
	_star(Vector2(x, 22), 9.0, Color(1.0, 0.85, 0.2))
	_text(font, Vector2(x + 12, 29), "x%d" % Progress.items.star, 16, Color.WHITE)
	x += 64
	_coin(Vector2(x, 22), 10.0)
	_text(font, Vector2(x + 16, 30), str(Progress.coins), 22, Color(1.0, 0.9, 0.5))


func _mushroom(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p + Vector2(-4, 0) * s, Vector2(8, 9) * s), Color(0.98, 0.92, 0.8))
	draw_circle(p, 9.0 * s, Color(0.7, 0.35, 0.9))
	draw_rect(Rect2(p + Vector2(-10, 0) * s, Vector2(20, 4) * s), Color(0.98, 0.92, 0.8))
	draw_circle(p + Vector2(-3, -3) * s, 2.5 * s, Color(1, 1, 1))
	draw_circle(p + Vector2(4, -4) * s, 2.0 * s, Color(1, 1, 1))


func _draw_info(font: Font) -> void:
	var r := Rect2(50, 470, 860, 60)
	draw_rect(r.grow(3), Color(0, 0, 0, 0.5))
	draw_rect(r, Color(0.08, 0.05, 0.12, 0.9))
	if not is_equal_approx(hero_t, float(target)):
		_text(font, Vector2(r.position.x, r.position.y + 37), "Walking...", 20, Color(0.8, 0.8, 0.9), int(r.size.x), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var node: Dictionary = NODES[target]
	var title := ""
	var sub := ""
	if node.type == "level":
		var info: Dictionary = Progress.LEVELS[node.level - 1]
		title = "LEVEL %d: %s" % [node.level, info.name.to_upper()]
		if node.has("area"):
			title = node.area.to_upper() + "  -  " + title
		if node.get("boss", false):
			title += "  (BOSS)"
		if Progress.cleared[node.level - 1]:
			sub = "Cleared!  Best: %d %s     Space: play again" % [Progress.best_books[node.level - 1], info.unit.to_lower()]
		else:
			sub = "Space: play"
		var packed := []
		if Progress.items.mushroom > 0:
			packed.append("Mushroom")
		if Progress.items.star > 0:
			packed.append("Star Candy")
		if packed.size() > 0:
			sub += "     Packed: " + ", ".join(packed)
	else:
		title = Progress.SHOPS[node.shop].name
		sub = "Space: go shopping"
	_text(font, Vector2(r.position.x, r.position.y + 25), title, 20, Color(1.0, 0.85, 0.35), int(r.size.x), HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(r.position.x, r.position.y + 49), sub + "     Left / Right: walk     Esc: title", 14, Color(0.85, 0.85, 0.95), int(r.size.x), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_title(font: Font) -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.05, 0.03, 0.08, 0.8))
	_text(font, Vector2(0, 150), "THE EVIL BOOK STEALER", 52, Color(1.0, 0.85, 0.35), 960, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(0, 200), "A hooded thief has stolen every book from the Grand Library!", 20, Color.WHITE, 960, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(0, 228), "Travel the world, beat each level, and spend your coins in the shops.", 20, Color.WHITE, 960, HORIZONTAL_ALIGNMENT_CENTER)
	# Continue / New Game menu
	var options := _title_options()
	var labels := {"continue": "CONTINUE", "new": "NEW GAME"}
	for i in options.size():
		var y := 285.0 + i * 46.0
		var sel := i == title_sel
		var box := Rect2(360, y - 30, 240, 40)
		draw_rect(box, Color(1, 1, 1, 0.14) if sel else Color(1, 1, 1, 0.04))
		if sel:
			draw_rect(box, Color(1.0, 0.85, 0.35), false, 2.0)
			_star(Vector2(box.position.x + 22, y - 10), 9.0, Color(1.0, 0.85, 0.35))
		_text(font, Vector2(0, y), labels[options[i]], 26, Color(1, 1, 1) if sel else Color(0.65, 0.65, 0.75), 960, HORIZONTAL_ALIGNMENT_CENTER)
	if options[title_sel] == "continue":
		var beaten := Progress.cleared.count(true)
		_text(font, Vector2(0, 390), "%d / %d levels cleared     %d coins" % [beaten, Progress.LEVELS.size(), Progress.coins], 16, Color(0.75, 0.9, 0.75), 960, HORIZONTAL_ALIGNMENT_CENTER)
	elif confirm_new:
		_text(font, Vector2(0, 390), "This ERASES your save! Press Space again to start over  (Esc: cancel)", 16, Color(1.0, 0.45, 0.45), 960, HORIZONTAL_ALIGNMENT_CENTER)

	var picks := []
	for m in D.MODES:
		picks.append(("[ %s ]" if m == D.mode else "  %s  ") % m.to_upper())
	_text(font, Vector2(0, 432), "Difficulty  (Left / Right):   " + "   ".join(picks), 20, D.color(), 960, HORIZONTAL_ALIGNMENT_CENTER)
	var blurb: String = {
		"easy": "%d hearts, slower enemies, weaker bosses. Great for learning!",
		"normal": "%d hearts. A real challenge.",
		"hard": "%d hearts, fast tough enemies, huge bosses. Good luck!",
	}[D.mode] % D.PLAYER_MAX_HP
	_text(font, Vector2(0, 458), blurb, 16, Color(0.9, 0.9, 0.95), 960, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(0, 515), "Up / Down: choose     Space / Enter: select", 14, Color(0.6, 0.6, 0.7), 960, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_shop(font: Font) -> void:
	var shop: Dictionary = Progress.SHOPS[shop_id]
	var items: Array = shop.items
	var panel := Rect2(70, 60, 820, 450)
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.45))
	draw_rect(panel.grow(4), Color(0.25, 0.15, 0.08))
	draw_rect(panel, Color(0.16, 0.1, 0.07) if shop.keeper == "owl" else Color(0.08, 0.07, 0.16))
	# awning
	for k in 21:
		var c := (Color(0.3, 0.5, 0.95) if shop.keeper == "owl" else Color(0.85, 0.35, 0.8)) if k % 2 == 0 else Color(0.95, 0.92, 0.85)
		draw_rect(Rect2(panel.position.x + k * 39.05, panel.position.y, 39.05, 22), c)
		draw_circle(Vector2(panel.position.x + k * 39.05 + 19.5, panel.position.y + 22), 19.5, c)
	_text(font, Vector2(panel.position.x, panel.position.y + 78), shop.name, 32, Color(1.0, 0.85, 0.35), int(panel.size.x), HORIZONTAL_ALIGNMENT_CENTER)

	# shopkeeper and speech bubble
	var kp := Vector2(200, 330)
	if shop.keeper == "owl":
		_draw_owl(kp)
	else:
		_draw_robot(kp)
	draw_rect(Rect2(kp + Vector2(-140, 54), Vector2(280, 16)), Color(0.45, 0.28, 0.15))   # counter
	var bubble := Rect2(95, 115, 230, 120)
	draw_rect(bubble, Color(0.98, 0.96, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(190, 235), Vector2(215, 235), Vector2(200, 255)]), Color(0.98, 0.96, 0.9))
	_wrap(font, shop_say, bubble.grow(-10), 15, Color(0.15, 0.1, 0.1))

	# item list
	var lx := 370.0
	var ly := 150.0
	for i in items.size() + 1:
		var row := Rect2(lx, ly + i * 47, 490, 43)
		var sel := i == shop_sel
		draw_rect(row, Color(1, 1, 1, 0.14) if sel else Color(1, 1, 1, 0.04))
		if sel:
			draw_rect(row, Color(1.0, 0.85, 0.35), false, 2.0)
		if i == items.size():
			_text(font, row.position + Vector2(52, 29), "Leave shop", 20, Color(0.85, 0.85, 0.95))
			continue
		var item: Dictionary = items[i]
		_item_icon(item, row.position + Vector2(24, 22))
		var cost := Progress.price(item)
		var afford := cost >= 0 and Progress.coins >= cost
		_text(font, row.position + Vector2(52, 20), item.name, 18, Color.WHITE)
		_text(font, row.position + Vector2(52, 38), Progress.status(item), 13, Color(0.6, 0.95, 0.65))
		var tag := "SOLD OUT"
		if cost == 0:
			tag = "WEAR" if Progress.scarf != item.id else ""
		elif cost > 0:
			tag = str(cost)
		if tag != "":
			var col := Color(1.0, 0.9, 0.5) if (afford or cost == 0) else Color(0.6, 0.55, 0.5)
			if cost > 0:
				_coin(row.position + Vector2(row.size.x - 80, 22), 8.0)
			_text(font, row.position + Vector2(row.size.x - 66, 29), tag, 20, col)

	# description of the selected item
	var desc := "Come back any time!"
	if shop_sel < items.size():
		desc = items[shop_sel].desc
	_text(font, Vector2(lx, 470), desc, 16, Color(0.9, 0.9, 0.95))
	_text(font, Vector2(panel.position.x, 500), "Up / Down: choose     Space: buy     Esc: leave", 13, Color(0.65, 0.65, 0.75), int(panel.size.x), HORIZONTAL_ALIGNMENT_CENTER)


func _wrap(font: Font, s: String, r: Rect2, size: int, col: Color) -> void:
	var words := s.split(" ")
	var line := ""
	var y := r.position.y + size
	for w in words:
		var test := w if line == "" else line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > r.size.x and line != "":
			draw_string(font, Vector2(r.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size + 5
			line = w
		else:
			line = test
	draw_string(font, Vector2(r.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _item_icon(item: Dictionary, p: Vector2) -> void:
	match item.id:
		"heart":
			_heart(p, 1.0, Color(1.0, 0.3, 0.4))
		"ink":
			draw_circle(p + Vector2(0, 4), 9.0, Color(0.3, 0.4, 1.0))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8.5, 1), p + Vector2(8.5, 1), p + Vector2(0, -13)]), Color(0.3, 0.4, 1.0))
			draw_circle(p + Vector2(-3, 2), 2.5, Color(0.7, 0.8, 1.0))
		"mushroom":
			_mushroom(p, 1.1)
		"star":
			_star(p, 13.0, Color.from_hsv(fmod(anim, 1.0), 0.5, 1.0))
		_:
			var col: Color = item.color
			if item.id == "scarf_rainbow":
				col = Color.from_hsv(fmod(anim * 0.6, 1.0), 0.75, 1.0)
			draw_rect(Rect2(p + Vector2(-13, -6), Vector2(26, 7)), col)
			draw_rect(Rect2(p + Vector2(6, -2), Vector2(7, 14)), col.darkened(0.15))


func _draw_owl(p: Vector2) -> void:
	var body := Color(0.55, 0.38, 0.22)
	draw_circle(p + Vector2(0, 20), 34.0, body)
	draw_circle(p + Vector2(0, 26), 22.0, Color(0.85, 0.75, 0.55))
	draw_circle(p + Vector2(0, -22), 28.0, body)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-26, -36), p + Vector2(-18, -60), p + Vector2(-8, -44)]), body)
	draw_colored_polygon(PackedVector2Array([p + Vector2(26, -36), p + Vector2(18, -60), p + Vector2(8, -44)]), body)
	var blink := fmod(anim, 3.2) < 0.12
	for sx in [-1, 1]:
		draw_circle(p + Vector2(sx * 11, -24), 10.0, Color(1, 1, 0.9))
		if blink:
			draw_line(p + Vector2(sx * 11 - 7, -24), p + Vector2(sx * 11 + 7, -24), Color(0.2, 0.1, 0.05), 2.0)
		else:
			draw_circle(p + Vector2(sx * 11, -24), 4.5, Color(0.1, 0.05, 0.02))
		draw_arc(p + Vector2(sx * 11, -24), 10.0, 0, TAU, 16, Color(0.2, 0.2, 0.2), 2.0)   # spectacles
	draw_line(p + Vector2(-1, -24), p + Vector2(1, -24), Color(0.2, 0.2, 0.2), 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -14), p + Vector2(5, -14), p + Vector2(0, -6)]), Color(1.0, 0.7, 0.2))


func _draw_robot(p: Vector2) -> void:
	var metal := Color(0.6, 0.65, 0.75)
	draw_rect(Rect2(p + Vector2(-30, -6), Vector2(60, 60)), metal.darkened(0.15))
	draw_rect(Rect2(p + Vector2(-16, 6), Vector2(32, 22)), Color(0.1, 0.12, 0.2))
	for i in 3:
		draw_circle(p + Vector2(-8 + i * 8, 17), 3.0, Color.from_hsv(fmod(anim * 0.8 + i * 0.3, 1.0), 0.7, 1.0))
	draw_rect(Rect2(p + Vector2(-28, -56), Vector2(56, 44)), metal)
	draw_rect(Rect2(p + Vector2(-20, -46), Vector2(40, 18)), Color(0.08, 0.1, 0.18))
	var scan := sin(anim * 3.0) * 10.0
	draw_circle(p + Vector2(-8 + scan * 0.3, -37), 4.0, Color(0.3, 1.0, 0.9))
	draw_circle(p + Vector2(8 + scan * 0.3, -37), 4.0, Color(0.3, 1.0, 0.9))
	draw_line(p + Vector2(0, -56), p + Vector2(0, -70), metal, 3.0)
	draw_circle(p + Vector2(0, -72), 4.0, Color(1.0, 0.3, 0.4) if int(anim * 2.0) % 2 == 0 else Color(0.5, 0.15, 0.2))
	# a little clock face on its chest
	draw_arc(p + Vector2(0, 40), 9.0, 0, TAU, 16, Color(1, 0.9, 0.5), 2.0)
	draw_line(p + Vector2(0, 40), p + Vector2(0, 40) + Vector2.from_angle(anim * 2.0) * 7.0, Color(1, 0.9, 0.5), 1.5)
