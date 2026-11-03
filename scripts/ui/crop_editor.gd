class_name CropEditor
extends VBoxContainer
## Ausschnitt-Editor beim Bild-Import: Bild verschieben (ziehen), zoomen (Mausrad oder Regler) und
## die Form wählen (Original, Quadrat, Rund). `result()` liefert den fertigen Ausschnitt.

const INK := Color("2b2118")
const VIEW := 440.0
const FRAME := 360.0
const SHAPES: Array[String] = ["original", "quadrat", "rund"]

var source: Image
var shape := "quadrat"
var zoom := 1.0
var pan := Vector2.ZERO
var _texture: ImageTexture
var _view: Control
var _zoom_slider: HSlider
var _dragging := false


func setup(img: Image) -> void:
	source = img
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(source)
	add_theme_constant_override("separation", 10)

	_view = Control.new()
	_view.custom_minimum_size = Vector2(VIEW, VIEW)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_view_input)
	add_child(_view)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for s in SHAPES:
		var b := Button.new()
		b.text = {"original": tr("Original"), "quadrat": tr("Quadrat"), "rund": tr("Rund")}[s]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s == shape
		b.focus_mode = Control.FOCUS_NONE
		var which := s
		b.pressed.connect(func() -> void:
			shape = which
			_view.queue_redraw())
		row.add_child(b)
	var zoom_label := Label.new()
	zoom_label.text = "  " + tr("Zoom")
	row.add_child(zoom_label)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 1.0
	_zoom_slider.max_value = 4.0
	_zoom_slider.step = 0.01
	_zoom_slider.value = zoom
	_zoom_slider.custom_minimum_size = Vector2(150, 20)
	_zoom_slider.focus_mode = Control.FOCUS_NONE
	_zoom_slider.value_changed.connect(func(v: float) -> void:
		zoom = v
		_view.queue_redraw())
	row.add_child(_zoom_slider)
	add_child(row)

	var hint := Label.new()
	hint.text = tr("Ziehen zum Verschieben, Mausrad zum Zoomen.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("a99fdc"))
	add_child(hint)


## Grundmaßstab: das Bild füllt den Rahmen gerade so aus.
func _base_scale() -> float:
	var f := frame_rect().size
	var s := source.get_size()
	return maxf(f.x / s.x, f.y / s.y)


func frame_rect() -> Rect2:
	var size := Vector2(FRAME, FRAME)
	if shape == "original":
		var s := Vector2(source.get_size())
		var fit := minf(FRAME / s.x, FRAME / s.y)
		size = s * fit
	return Rect2((Vector2(VIEW, VIEW) - size) * 0.5, size)


func image_rect() -> Rect2:
	var scaled := Vector2(source.get_size()) * _base_scale() * zoom
	return Rect2(Vector2(VIEW, VIEW) * 0.5 + pan - scaled * 0.5, scaled)


func _clamp_pan() -> void:
	# Das Bild soll den Rahmen immer ganz bedecken.
	var img := Vector2(source.get_size()) * _base_scale() * zoom
	var f := frame_rect().size
	var limit := ((img - f) * 0.5).max(Vector2.ZERO)
	pan = pan.clamp(-limit, limit)


func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			_zoom_slider.value = clampf(zoom * factor, 1.0, 4.0)
		_view.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan += event.relative
		_clamp_pan()
		_view.queue_redraw()
		_view.accept_event()


func _draw_view() -> void:
	_clamp_pan()
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW, VIEW)), Color("0f0b24"))
	_view.draw_texture_rect(_texture, image_rect(), false)
	var f := frame_rect()
	var shade := Color(0, 0, 0, 0.55)
	if shape == "rund":
		var center := f.get_center()
		var r := f.size.x * 0.5
		# Außenbereich abdunkeln: Ring aus dicken Bögen
		_view.draw_arc(center, r + VIEW * 0.5, 0.0, TAU, 96, shade, VIEW, true)
		_view.draw_arc(center, r, 0.0, TAU, 96, Color.WHITE, 3.0, true)
	else:
		_view.draw_rect(Rect2(0, 0, VIEW, f.position.y), shade)
		_view.draw_rect(Rect2(0, f.end.y, VIEW, VIEW - f.end.y), shade)
		_view.draw_rect(Rect2(0, f.position.y, f.position.x, f.size.y), shade)
		_view.draw_rect(Rect2(f.end.x, f.position.y, VIEW - f.end.x, f.size.y), shade)
		_view.draw_rect(f, Color.WHITE, false, 3.0)


## Der fertige Ausschnitt (bei "rund" mit transparenten Ecken).
func result() -> Image:
	_clamp_pan()
	var img_rect := image_rect()
	var f := frame_rect()
	var px_scale := img_rect.size.x / source.get_width()
	var region := Rect2i(((f.position - img_rect.position) / px_scale).round(), (f.size / px_scale).round())
	region = region.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	if region.size.x < 4 or region.size.y < 4:
		return source
	var out := source.get_region(region)
	var longest := maxi(out.get_width(), out.get_height())
	if longest > GameState.MAX_IMAGE_EDGE:
		var k := float(GameState.MAX_IMAGE_EDGE) / longest
		out.resize(maxi(1, roundi(out.get_width() * k)), maxi(1, roundi(out.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	if shape == "rund":
		out = round_mask(out)
	return out


## Kreisförmige Maske mit weicher Kante. Zeilenweise: außen ganze Spannen leeren, nur die Kante pro Pixel.
static func round_mask(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var w := out.get_width()
	var h := out.get_height()
	var c := Vector2(w, h) * 0.5
	var r := minf(c.x, c.y)
	var clear := Color(0, 0, 0, 0)
	for y in h:
		var dy := y + 0.5 - c.y
		if absf(dy) >= r:
			out.fill_rect(Rect2i(0, y, w, 1), clear)
			continue
		var half := sqrt(r * r - dy * dy)
		var left := int(floor(c.x - half))
		var right := int(ceil(c.x + half))
		if left > 0:
			out.fill_rect(Rect2i(0, y, left, 1), clear)
		if right < w:
			out.fill_rect(Rect2i(right, y, w - right, 1), clear)
		for x in [left - 1, left, left + 1, right - 2, right - 1, right]:
			if x < 0 or x >= w:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := out.get_pixel(x, y)
			col.a *= clampf(r - d, 0.0, 1.0)
			out.set_pixel(x, y, col)
	return out
