class_name TargetArea
extends Control
## Der Bereich mit dem Zielbild. Erkennt Treffer (nur auf nicht-transparenten Pixeln),
## steuert Dauerfeuer, Squash-Animation, Screen-Shake und den Faust-Cursor.

signal hit(uv: Vector2)

const CURSOR_DIR := "res://assets/cursor"
const CURSOR_HOTSPOT := Vector2(30, 26)
const ALPHA_THRESHOLD := 0.1

@onready var image: TextureRect = $TargetImage
@onready var effects: HitEffects = $Effects
@onready var bumps: BumpOverlay = $BumpOverlay

var _alpha_image: Image
var _held := false
var _autofire_timer := 0.0
var _shake_time := 0.0
var _cursor_timer := 0.0
var _squash_tween: Tween
var _podium: Control


func _ready() -> void:
	_set_cursor(_cursor(0))
	resized.connect(_update_pivot)
	image.resized.connect(_update_pivot)
	# Podest vor dem unteren Bildrand: Das Opfer steht im Scheinwerferkreis statt abgeschnitten zu enden.
	_podium = Control.new()
	_podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podium.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_podium)
	move_child(_podium, image.get_index() + 1)
	_podium.draw.connect(_draw_podium)
	resized.connect(_podium.queue_redraw)


func set_texture(tex: Texture2D) -> void:
	image.texture = tex
	if _podium:
		_podium.queue_redraw()
	_alpha_image = null
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			_alpha_image = img
	effects.clear()
	bumps.refresh()


## Rechteck, in dem das Bild tatsächlich gezeichnet wird (lokale Koordinaten dieses Controls).
func image_rect() -> Rect2:
	if image.texture == null:
		return Rect2()
	var tex_size := image.texture.get_size()
	var s := minf(image.size.x / tex_size.x, image.size.y / tex_size.y)
	var drawn := tex_size * s
	return Rect2(image.position + (image.size - drawn) * 0.5, drawn)


## Wie image_rect(), aber ohne Wackeln (für Podest und Bühnenkante, die still stehen sollen).
func _resting_image_rect() -> Rect2:
	if image.texture == null:
		return Rect2()
	var inner := Rect2(Vector2(24, 24), size - Vector2(48, 48))
	var tex_size := image.texture.get_size()
	var s := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
	var drawn := tex_size * s
	return Rect2(inner.position + (inner.size - drawn) * 0.5, drawn)


func _podium_height(r: Rect2) -> float:
	return clampf(r.size.x * 0.1, 14.0, 40.0)


## Bühnenkante hinter dem Opfer (lokale y-Koordinate), passend zum Podest.
func floor_y() -> float:
	var r := _resting_image_rect()
	if r.size == Vector2.ZERO:
		return -1.0
	return r.end.y - _podium_height(r) * 0.2


func _draw_podium() -> void:
	var r := _resting_image_rect()
	if r.size == Vector2.ZERO:
		return
	var h := _podium_height(r)
	var rx := r.size.x * 0.48
	var top := Vector2(r.get_center().x, r.end.y - h * 0.2)
	var bottom := top + Vector2(0, h * 0.35)
	_ellipse(bottom, rx, h * 0.5, Color("0f0b24"))
	_podium.draw_rect(Rect2(top.x - rx, top.y, rx * 2.0, bottom.y - top.y), Color("0f0b24"))
	_ellipse(top, rx, h * 0.5, Color("3b2f7a"))
	_ellipse(top, rx * 0.62, h * 0.32, Color("4a3d94"))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	_podium.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	_podium.draw_circle(Vector2.ZERO, rx, color)
	_podium.draw_set_transform(Vector2.ZERO)


func uv_to_local(uv: Vector2) -> Vector2:
	var r := image_rect()
	return r.position + uv * r.size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_held = event.pressed
		if event.pressed:
			_autofire_timer = 1.0 / maxf(GameState.autofire_rate(), 1.0)
			try_hit(event.position)
		accept_event()


## Versucht einen Treffer an einer Position. Gibt true zurück, wenn das Bild getroffen wurde.
func try_hit(pos: Vector2) -> bool:
	var r := image_rect()
	if not r.has_point(pos):
		return false
	var uv := (pos - r.position) / r.size
	if not _is_opaque(uv):
		return false
	_punch_cursor()
	hit.emit(uv)
	return true


## Treffer per Tastatur: zufälliger Punkt in der Bildmitte.
func hit_somewhere() -> void:
	for attempt in 12:
		var uv := Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.75))
		if _is_opaque(uv):
			hit.emit(uv)
			return
	hit.emit(Vector2(0.5, 0.5))


func _is_opaque(uv: Vector2) -> bool:
	if _alpha_image == null:
		return true
	var px := Vector2i(
		clampi(int(uv.x * _alpha_image.get_width()), 0, _alpha_image.get_width() - 1),
		clampi(int(uv.y * _alpha_image.get_height()), 0, _alpha_image.get_height() - 1))
	return _alpha_image.get_pixelv(px).a > ALPHA_THRESHOLD


func _process(delta: float) -> void:
	# Dauerfeuer
	if _held and GameState.has_autofire():
		_autofire_timer -= delta
		if _autofire_timer <= 0.0:
			_autofire_timer += 1.0 / GameState.autofire_rate()
			try_hit(get_local_mouse_position())
	# Screen-Shake
	if _shake_time > 0.0:
		_shake_time -= delta
		var strength := 10.0 * clampf(_shake_time / 0.3, 0.0, 1.0)
		position_offset(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength)
		if _shake_time <= 0.0:
			position_offset(Vector2.ZERO)
	# Cursor zurück auf "ausgeholt"
	if _cursor_timer > 0.0:
		_cursor_timer -= delta
		if _cursor_timer <= 0.0:
			_set_cursor(_cursor(0))


func position_offset(offset: Vector2) -> void:
	image.offset_left = 24.0 + offset.x
	image.offset_right = -24.0 + offset.x
	image.offset_top = 24.0 + offset.y
	image.offset_bottom = -24.0 + offset.y


func squash() -> void:
	if GameState.reduced_effects:
		return
	if _squash_tween:
		_squash_tween.kill()
	image.scale = Vector2(1.07, 0.92)
	_squash_tween = create_tween()
	_squash_tween.tween_property(image, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func shake() -> void:
	if GameState.reduced_effects:
		return
	_shake_time = 0.3


func _update_pivot() -> void:
	image.pivot_offset = image.size * 0.5


func _punch_cursor() -> void:
	_set_cursor(_cursor(1))
	_cursor_timer = 0.09


var _cursor_cache: Dictionary = {}


## Faust-Skin-Texturen: fist_open[_skin].svg und fist_hit[_skin].svg.
func _cursor(frame: int) -> Texture2D:
	var skin := GameState.fist_skin
	if not _cursor_cache.has(skin):
		var suffix := "" if skin == "standard" else "_" + skin
		var open_path := "%s/fist_open%s.svg" % [CURSOR_DIR, suffix]
		if not ResourceLoader.exists(open_path):
			suffix = ""
			open_path = "%s/fist_open.svg" % CURSOR_DIR
		_cursor_cache[skin] = [load(open_path), load("%s/fist_hit%s.svg" % [CURSOR_DIR, suffix])]
	return _cursor_cache[skin][frame]


func refresh_cursor() -> void:
	_set_cursor(_cursor(0))


func _set_cursor(tex: Texture2D) -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(tex, shape, CURSOR_HOTSPOT)
