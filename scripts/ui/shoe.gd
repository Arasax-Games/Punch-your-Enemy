class_name Shoe
extends Control
## Ein Goldener Schuh oder Silberner Pantoffel, der kurz irgendwo erscheint.
## Schwebt, dreht Strahlen hinter sich und verblasst in den letzten Sekunden.

signal claimed(kind: String)
signal expired(kind: String)

const GOLDEN_TEXTURE := preload("res://assets/events/golden_shoe.svg")
const SILVER_TEXTURE := preload("res://assets/events/silver_slipper.svg")

var kind: String = "golden"
var lifetime: float = 13.0
var _age: float = 0.0
var _base_position: Vector2
var _done := false
var _texture: Texture2D


func setup(shoe_kind: String, life: float, at: Vector2) -> void:
	kind = shoe_kind
	lifetime = life
	_texture = GOLDEN_TEXTURE if kind == "golden" else SILVER_TEXTURE
	var edge := 120.0 if kind == "golden" else 90.0
	size = Vector2(edge, edge)
	pivot_offset = size * 0.5
	position = at - size * 0.5
	_base_position = position
	tooltip_text = tr("Klick mich!")
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	position = _base_position + Vector2(sin(_age * 1.7) * 6.0, sin(_age * 3.1) * 8.0)
	rotation = sin(_age * 2.3) * 0.12
	var fade_start := lifetime - 3.0
	modulate.a = 1.0 if _age < fade_start else clampf(1.0 - (_age - fade_start) / 3.0, 0.0, 1.0)
	queue_redraw()
	if _age >= lifetime:
		_done = true
		expired.emit(kind)
		queue_free()


func _draw() -> void:
	var c := size * 0.5
	var rays := 10
	var ray_color := Color(1.0, 0.92, 0.4, 0.45) if kind == "golden" else Color(0.9, 0.95, 1.0, 0.45)
	if not GameState.reduced_effects:
		for i in rays:
			var a := _age * 0.8 + i * TAU / rays
			var p1 := c + Vector2.from_angle(a - 0.12) * size.x * 0.75
			var p2 := c + Vector2.from_angle(a + 0.12) * size.x * 0.75
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), ray_color)
	if _texture:
		var tex_size := _texture.get_size()
		var s := minf(size.x / tex_size.x, size.y / tex_size.y)
		var drawn := tex_size * s
		draw_texture_rect(_texture, Rect2((size - drawn) * 0.5, drawn), false)


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_done = true
		accept_event()
		claimed.emit(kind)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)
