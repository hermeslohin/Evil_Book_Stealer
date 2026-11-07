extends AnimatableBody2D
## An anti-gravity platform that drifts side to side over a bottomless drop. Ride it across!

const WIDTH := 96.0
const RANGE := 80.0     # how far it drifts each way
const PERIOD := 4.0     # seconds for a full back-and-forth

var home := Vector2.ZERO
var phase := 0.0
var t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	z_index = 2
	home = position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(WIDTH, 12)
	cs.shape = r
	cs.position = Vector2(0, 6)
	cs.one_way_collision = true
	add_child(cs)


func _physics_process(delta: float) -> void:
	t += delta
	position.x = home.x + sin(t * TAU / PERIOD + phase) * RANGE
	queue_redraw()


func _draw() -> void:
	var w := WIDTH / 2.0
	draw_rect(Rect2(-w, 0, WIDTH, 10), Color(0.25, 0.27, 0.36))
	draw_rect(Rect2(-w, 0, WIDTH, 3), Color(0.95, 0.35, 0.85))
	draw_rect(Rect2(-w + 6, 5, WIDTH - 12, 2), Color(0.15, 0.15, 0.2))
	# anti-grav thrusters
	for x in [-w + 14, w - 14]:
		var flick := 0.6 + 0.4 * sin(t * 30.0 + x)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 10), Vector2(x + 6, 10), Vector2(x, 10 + 16 * flick)]), Color(0.4, 0.9, 1.0, 0.7))
		draw_circle(Vector2(x, 11), 4.0, Color(0.8, 1.0, 1.0))
