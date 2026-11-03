class_name HitEffects
extends Control
## Zeichnet die Slapstick-Treffer über dem Zielbild: Farbspritzer, Beulen, Pflaster,
## kreisende Sterne sowie Zahl- und Comic-Wort-Popups. Kein Blut, nur Cartoon.
## Positionen werden relativ zum Bild (UV 0..1) gespeichert, damit sie beim Skalieren mitwandern.

const MAX_MARKS := 60
const MAX_POPUPS := 30
const INK := Color("2b2118")
const SPLAT_COLORS: Array[Color] = [
	Color("ff6fae"), Color("ffd43b"), Color("3bc9db"), Color("b197fc"), Color("69db7c"),
]
const WORD_COLORS: Array[Color] = [
	Color("ff6fae"), Color("ffd43b"), Color("3bc9db"), Color("ff922b"),
]
# i18n: Texte werden bei der Anzeige mit tr() übersetzt
const HIT_WORDS: Array[String] = [
	"WUMMS!", "KLATSCH!", "AUA-UA!", "BONK!", "PATSCH!", "ZACK!", "BOING!", "PLONK!",
]

var area: TargetArea
var _marks: Array = []  # Spritzer, Beulen, Pflaster
var _stars: Array = []  # kreisende Sternchen
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	area = get_parent() as TargetArea
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_hit(uv: Vector2, value: float, crit: bool) -> void:
	var reduced := GameState.reduced_effects
	var size_mult := (1.8 if crit else 1.0) * (1.0 + GameState.combo / 200.0)

	var blobs: Array = []
	for i in _rng.randi_range(5, 9):
		blobs.append([Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.6, 1.25), _rng.randf_range(0.18, 0.45)])
	_marks.append({
		"kind": "splat", "uv": uv, "age": 0.0, "life": 5.0,
		"radius": _rng.randf_range(16.0, 28.0) * size_mult,
		"color": SPLAT_COLORS[_rng.randi() % SPLAT_COLORS.size()],
		"blobs": blobs,
	})
	var roll := _rng.randf()
	if roll < 0.3 or crit:
		_marks.append({"kind": "bump", "uv": uv + _jitter(0.02), "age": 0.0, "life": INF,
			"radius": _rng.randf_range(9.0, 16.0) * size_mult})
	elif roll < 0.36:
		_marks.append({"kind": "plaster", "uv": uv + _jitter(0.03), "age": 0.0, "life": INF,
			"rot": _rng.randf_range(-0.6, 0.6)})
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()

	if not reduced:
		_stars.append({"uv": uv, "age": 0.0, "life": 0.9, "phase": _rng.randf() * TAU})
		# Aufprall-Ring: kurzer weißer Kreis, der aufploppt und verblasst
		_marks.append({"kind": "ring", "uv": uv, "age": 0.0, "life": 0.22, "radius": 34.0 * size_mult})

	var pos := area.uv_to_local(uv)
	_popup("+" + Num.fmt(value), pos + Vector2(0, -10), 34 if not crit else 50, Color.WHITE, 0.9)
	if crit:
		_popup(tr("KRITISCH!"), pos + Vector2(0, -70), 64, Color("ff4d6d"), 1.2, true)
	elif not reduced and _rng.randf() < 0.35:
		var word := tr(HIT_WORDS[_rng.randi() % HIT_WORDS.size()])
		_popup(word, pos + _jitter(40.0) + Vector2(0, -50), 40, WORD_COLORS[_rng.randi() % WORD_COLORS.size()], 0.8, true)
	queue_redraw()


## Kurzer Text an einer Stelle (z. B. "Geblockt!" im Boss-Kampf).
func popup_text(text: String, pos: Vector2, color: Color) -> void:
	_popup(text, pos, 34, color, 0.8, true)


var _heading: Font


func _heading_font() -> Font:
	if _heading == null:
		_heading = load("res://scripts/ui/main.gd").heading_font()
	return _heading


## "Duschen": entfernt alle Spuren, Fortschritt bleibt.
func clear() -> void:
	_marks.clear()
	_stars.clear()
	for child in get_children():
		child.queue_free()
	queue_redraw()


func _jitter(amount: float) -> Vector2:
	return Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


func _process(delta: float) -> void:
	if _marks.is_empty() and _stars.is_empty():
		return
	for m in _marks:
		m.age += delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return m.age < m.life)
	for s in _stars:
		s.age += delta
	_stars = _stars.filter(func(s: Dictionary) -> bool: return s.age < s.life)
	queue_redraw()


func _draw() -> void:
	if area == null:
		return
	var r := area.image_rect()
	if r.size == Vector2.ZERO:
		return
	var k := clampf(minf(r.size.x, r.size.y) / 520.0, 0.5, 2.0)
	for m in _marks:
		var pos: Vector2 = r.position + m.uv * r.size
		match m.kind:
			"splat":
				_draw_splat(pos, m, k)
			"bump":
				_draw_bump(pos, m, k)
			"plaster":
				_draw_plaster(pos, m, k)
			"ring":
				_draw_ring(pos, m, k)
	for s in _stars:
		_draw_stars(r.position + s.uv * r.size, s, k)


func _draw_splat(pos: Vector2, m: Dictionary, k: float) -> void:
	var pop := minf(1.0, m.age / 0.08)
	var fade := 1.0 - smoothstep(m.life * 0.5, m.life, m.age)
	var col: Color = m.color
	col.a = 0.85 * fade
	var rad: float = m.radius * k * (0.4 + 0.6 * pop)
	draw_circle(pos, rad, col)
	for b in m.blobs:
		draw_circle(pos + b[0] * rad * 1.15, rad * b[1], col)


func _draw_ring(pos: Vector2, m: Dictionary, k: float) -> void:
	var t: float = m.age / m.life
	var rad: float = m.radius * k * (0.4 + 0.8 * t)
	draw_circle(pos, rad * 0.55, Color(1, 1, 1, 0.55 * (1.0 - t)))
	draw_arc(pos, rad, 0.0, TAU, 32, Color(1, 1, 1, 0.9 * (1.0 - t)), 5.0 * k * (1.0 - t) + 1.0, true)


func _draw_bump(pos: Vector2, m: Dictionary, k: float) -> void:
	var grow := minf(1.0, m.age / 0.25)
	var rad: float = m.radius * k * (0.3 + 0.7 * grow)
	draw_circle(pos, rad, Color("f59f9f"))
	draw_arc(pos, rad, 0.0, TAU, 28, INK, 2.0 * k, true)
	draw_circle(pos + Vector2(-0.35, -0.35) * rad, rad * 0.3, Color(1, 1, 1, 0.7))


func _draw_plaster(pos: Vector2, m: Dictionary, k: float) -> void:
	var w := 46.0 * k
	var h := 14.0 * k
	for angle in [m.rot + 0.785, m.rot - 0.785]:
		draw_set_transform(pos, angle)
		var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
		draw_rect(rect, Color("f4d3a1"))
		draw_rect(Rect2(-h * 0.4, -h * 0.4, h * 0.8, h * 0.8), Color("e9b97a"))
		draw_rect(rect, INK, false, 2.0 * k)
	draw_set_transform(Vector2.ZERO)


func _draw_stars(center: Vector2, s: Dictionary, k: float) -> void:
	var alpha := 1.0 - smoothstep(s.life * 0.6, s.life, s.age)
	var orbit := 34.0 * k
	for i in 3:
		var a: float = s.phase + s.age * 9.0 + i * TAU / 3.0
		var p := center + Vector2(cos(a) * orbit, sin(a) * orbit * 0.45) + Vector2(0, -30.0 * k)
		_draw_star(p, 9.0 * k, Color(1.0, 0.85, 0.2, alpha), Color(INK, alpha))


func _draw_star(center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rad)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, outline, 1.5, true)


func _popup(text: String, pos: Vector2, font_size: int, color: Color, duration: float, wobble: bool = false) -> void:
	if get_child_count() >= MAX_POPUPS:
		get_child(0).queue_free()
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _heading_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(8, font_size / 4))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	label.position = pos - label.size * 0.5
	label.scale = Vector2(0.4, 0.4)
	if wobble:
		label.rotation = _rng.randf_range(-0.25, 0.25)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - 70.0, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.chain().tween_callback(label.queue_free)
