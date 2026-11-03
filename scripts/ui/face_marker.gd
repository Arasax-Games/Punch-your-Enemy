class_name FaceMarker
extends VBoxContainer
## Gesicht markieren bei eigenen Bildern: zwei Augen-Punkte ziehen, daraus werden Pflaster, Veilchen,
## Beulen und Kopfverband platziert (Balance.face_anchors). Die Vorschau zeigt gleich, wo alles landet.

const VIEW := 420.0
const MARKER_RADIUS := 14.0
const EYE_COLOR := Color("ffc929")
const LINE := Color("0f0b24")

var eye_left := Vector2(0.38, 0.4)
var eye_right := Vector2(0.62, 0.4)
var _texture: Texture2D
var _view: Control
var _drag := -1  # 0 = linkes Auge, 1 = rechtes Auge


func setup(tex: Texture2D, eyes: Array[Vector2]) -> void:
	_texture = tex
	if eyes.size() == 2:
		eye_left = eyes[0]
		eye_right = eyes[1]
	add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = tr("Zieh die beiden gelben Punkte auf die Augen. Danach sitzen Pflaster, Veilchen und Verband an der richtigen Stelle.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(VIEW, 0)
	add_child(hint)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(VIEW, VIEW)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_view_input)
	add_child(_view)


func _image_rect() -> Rect2:
	if _texture == null:
		return Rect2(Vector2.ZERO, Vector2(VIEW, VIEW))
	var s := _texture.get_size()
	var fit := minf(VIEW / s.x, VIEW / s.y)
	var drawn := s * fit
	return Rect2((Vector2(VIEW, VIEW) - drawn) * 0.5, drawn)


func _to_local(uv: Vector2) -> Vector2:
	var r := _image_rect()
	return r.position + uv * r.size


func _to_uv(pos: Vector2) -> Vector2:
	var r := _image_rect()
	return ((pos - r.position) / r.size).clamp(Vector2.ZERO, Vector2.ONE)


func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var dl: float = event.position.distance_to(_to_local(eye_left))
			var dr: float = event.position.distance_to(_to_local(eye_right))
			_drag = 0 if dl <= dr else 1
			_move(event.position)
		else:
			_drag = -1
		_view.accept_event()
	elif event is InputEventMouseMotion and _drag >= 0:
		_move(event.position)
		_view.accept_event()


func _move(pos: Vector2) -> void:
	if _drag == 0:
		eye_left = _to_uv(pos)
	else:
		eye_right = _to_uv(pos)
	_view.queue_redraw()


func _draw_view() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW, VIEW)), LINE)
	if _texture:
		_view.draw_texture_rect(_texture, _image_rect(), false)
	var size := _texture.get_size() if _texture else Vector2.ONE
	var anchors := Balance.face_anchors(eye_left, eye_right, size)
	var l := _to_local(eye_left)
	var r := _to_local(eye_right)
	var k := l.distance_to(r) / 100.0
	# Vorschau: Verband über der Stirn, Pflaster auf der Wange, Beule oben am Kopf
	var forehead := _to_local(_v(anchors.forehead))
	var w := l.distance_to(r) * 2.86
	_view.draw_set_transform(forehead, (r - l).angle())
	_view.draw_rect(Rect2(-w * 0.5, -15.0 * k, w, 30.0 * k), Color(1, 1, 1, 0.55))
	_view.draw_rect(Rect2(-w * 0.5, -15.0 * k, w, 30.0 * k), LINE, false, 2.0)
	_view.draw_set_transform(Vector2.ZERO)
	var cheek := _to_local(_v(anchors.cheek))
	_view.draw_set_transform(cheek, 0.785)
	_view.draw_rect(Rect2(-32.0 * k, -10.0 * k, 64.0 * k, 20.0 * k), Color(0.96, 0.83, 0.63, 0.8))
	_view.draw_set_transform(Vector2.ZERO)
	_view.draw_circle(_to_local(_v(anchors.head_top)), 24.0 * k, Color(0.96, 0.62, 0.62, 0.7))
	_view.draw_line(l, r, Color(EYE_COLOR, 0.6), 2.0)
	for p in [l, r]:
		_view.draw_circle(p, MARKER_RADIUS, Color(EYE_COLOR, 0.35))
		_view.draw_arc(p, MARKER_RADIUS, 0.0, TAU, 32, EYE_COLOR, 3.0, true)
		_view.draw_circle(p, 3.0, EYE_COLOR)


static func _v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])
