class_name Confetti
extends Control
## Kurzer Konfetti-Regen, z. B. bei einem neuen Erfolg. Entfernt sich danach selbst.

const COLORS: Array[Color] = [
	Color("ff6fae"), Color("ffd43b"), Color("3bc9db"), Color("b197fc"), Color("69db7c"), Color("ff922b"),
]
const DURATION := 1.8

var _pieces: Array = []
var _age := 0.0


static func burst(parent: Control, origin: Vector2, count: int = 70) -> void:
	var c := Confetti.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	for i in count:
		c._pieces.append({
			"pos": origin,
			"vel": Vector2(randf_range(-320, 320), randf_range(-480, -120)),
			"rot": randf() * TAU,
			"spin": randf_range(-10, 10),
			"color": COLORS[randi() % COLORS.size()],
			"size": Vector2(randf_range(6, 12), randf_range(4, 8)),
		})


func _process(delta: float) -> void:
	_age += delta
	for p in _pieces:
		p.vel.y += 900.0 * delta
		p.vel.x *= 0.985
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	queue_redraw()
	if _age >= DURATION:
		queue_free()


func _draw() -> void:
	var alpha := clampf(1.0 - (_age - DURATION * 0.6) / (DURATION * 0.4), 0.0, 1.0)
	for p in _pieces:
		var col: Color = p.color
		col.a = alpha
		draw_set_transform(p.pos, p.rot)
		draw_rect(Rect2(-p.size * 0.5, p.size), col)
	draw_set_transform(Vector2.ZERO)
