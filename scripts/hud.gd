extends CanvasLayer
## Hearts, book counter, boss health bar, banners and the big message box.

var hearts := 5
var max_hearts := 5
var ink := 10
var max_ink := 10
var ink_flash := 0.0
var books := 0
var books_total := 0
var boss_visible := false
var boss_name := "THE EVIL BOOK STEALER"
var boss_hp := 1
var boss_max := 1
var boss_shown_hp := 1.0
var banner_text := ""
var banner_color := Color.WHITE
var banner_t := 0.0
var invincible_t := 0.0
var invincible_max := 1.0

var canvas: Control
var panel: ColorRect
var title_label: Label
var body_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)

	panel = ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.08, 0.85)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_label.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.4))
	title_label.add_theme_constant_override("outline_size", 10)
	box.add_child(title_label)

	body_label = Label.new()
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 20)
	box.add_child(body_label)


func _process(delta: float) -> void:
	banner_t = max(banner_t - delta, 0.0)
	ink_flash = max(ink_flash - delta, 0.0)
	invincible_t = max(invincible_t - delta, 0.0)
	boss_shown_hp = move_toward(boss_shown_hp, float(boss_hp), 10.0 * delta)
	canvas.queue_redraw()


func set_hearts(hp: int, max_hp: int) -> void:
	hearts = hp
	max_hearts = max_hp


func set_ink(n: int, max_n: int) -> void:
	ink = n
	max_ink = max_n


func flash_ink() -> void:
	ink_flash = 0.4


func set_books(n: int, total: int) -> void:
	books = n
	books_total = total


func show_boss_bar(hp: int, max_hp: int) -> void:
	boss_visible = true
	boss_hp = hp
	boss_max = max_hp
	boss_shown_hp = 0.0


func set_boss_hp(hp: int, max_hp: int) -> void:
	boss_hp = hp
	boss_max = max_hp


func hide_boss_bar() -> void:
	boss_visible = false


func set_invincible(t: float, max_t: float) -> void:
	invincible_t = t
	invincible_max = max_t


func banner(text: String, color := Color.WHITE) -> void:
	banner_text = text
	banner_color = color
	banner_t = 2.2


func show_message(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	panel.visible = true


func hide_message() -> void:
	panel.visible = false


func message_visible() -> bool:
	return panel.visible


func _heart(c: Control, pos: Vector2, filled: bool) -> void:
	var col := Color(1.0, 0.3, 0.4) if filled else Color(0.3, 0.25, 0.3)
	c.draw_circle(pos + Vector2(-5, -3), 6.0, col)
	c.draw_circle(pos + Vector2(5, -3), 6.0, col)
	c.draw_colored_polygon(PackedVector2Array([pos + Vector2(-10.5, -1), pos + Vector2(10.5, -1), pos + Vector2(0, 11)]), col)


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var size := canvas.get_viewport_rect().size
	for i in max_hearts:
		_heart(canvas, Vector2(28 + i * 28, 28), i < hearts)

	# ink supply: a drop icon and a segmented bar
	var ip := Vector2(18, 56)
	var low := ink <= 2
	var icol := Color(0.3, 0.4, 1.0)
	if ink_flash > 0.0 and int(ink_flash * 20.0) % 2 == 0:
		icol = Color(1.0, 0.3, 0.3)
	canvas.draw_circle(ip + Vector2(8, 11), 7.0, icol)
	canvas.draw_colored_polygon(PackedVector2Array([ip + Vector2(1.5, 9), ip + Vector2(14.5, 9), ip + Vector2(8, -3)]), icol)
	canvas.draw_circle(ip + Vector2(5.5, 9), 2.0, Color(0.7, 0.8, 1.0))
	for i in max_ink:
		var seg := Rect2(ip + Vector2(24 + i * 12, 4), Vector2(10, 14))
		canvas.draw_rect(seg.grow(1), Color(0, 0, 0, 0.7))
		canvas.draw_rect(seg, icol.darkened(0.1) if i < ink else Color(0.18, 0.16, 0.25))

	# book counter
	var bp := Vector2(size.x - 130, 14)
	canvas.draw_rect(Rect2(bp, Vector2(16, 22)), Color(0.85, 0.3, 0.3))
	canvas.draw_rect(Rect2(bp, Vector2(4, 22)), Color(0.55, 0.15, 0.15))
	canvas.draw_rect(Rect2(bp + Vector2(15, 2), Vector2(2, 18)), Color(0.95, 0.92, 0.8))
	canvas.draw_string_outline(font, bp + Vector2(26, 19), "%d / %d" % [books, books_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0))
	canvas.draw_string(font, bp + Vector2(26, 19), "%d / %d" % [books, books_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.8))

	if invincible_t > 0.0:
		var sw := 160.0
		var sp := Vector2((size.x - sw) / 2.0, 72)
		var gold := Color.from_hsv(fmod(invincible_t * 2.5, 1.0), 0.6, 1.0)
		canvas.draw_rect(Rect2(sp, Vector2(sw, 10)).grow(2), Color(0, 0, 0, 0.7))
		canvas.draw_rect(Rect2(sp, Vector2(sw, 10)), Color(0.15, 0.1, 0.05))
		canvas.draw_rect(Rect2(sp, Vector2(sw * clampf(invincible_t / invincible_max, 0.0, 1.0), 10)), gold)

	if boss_visible:
		var bw := 420.0
		var bar := Rect2((size.x - bw) / 2.0, 40, bw, 16)
		canvas.draw_string_outline(font, Vector2(bar.position.x, bar.position.y - 8), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0, 0, 0))
		canvas.draw_string(font, Vector2(bar.position.x, bar.position.y - 8), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.7, 1.0))
		canvas.draw_rect(bar.grow(3), Color(0, 0, 0, 0.8))
		canvas.draw_rect(bar, Color(0.25, 0.1, 0.15))
		var frac := clampf(boss_shown_hp / float(boss_max), 0.0, 1.0)
		canvas.draw_rect(Rect2(bar.position, Vector2(bw * frac, bar.size.y)), Color(0.75, 0.25, 0.85))
		canvas.draw_rect(Rect2(bar.position, Vector2(bw * frac, 5)), Color(0.9, 0.55, 1.0))

	if banner_t > 0.0:
		var a := clampf(banner_t / 0.4, 0.0, 1.0)
		var col := banner_color
		col.a = a
		var y := 150.0 - (1.0 - clampf((2.2 - banner_t) / 0.25, 0.0, 1.0)) * 30.0
		canvas.draw_string_outline(font, Vector2(0, y), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, 10, Color(0, 0, 0, a))
		canvas.draw_string(font, Vector2(0, y), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, col)
