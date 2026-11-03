class_name MiniGame
extends Control
## Mini-Spiele: "dojo" (Reaktions-Dojo: Ziele treffen, bevor sie verschwinden) und
## "pie" (Tortenwurf-Schießbude: Torten auf vorbeiziehende Pappfiguren werfen).
## 30 Sekunden, Punkte bringen Beulen-Marken (max. 5 pro Spiel und Tag, siehe GameState.record_minigame).

signal finished

const INK := Color("2b2118")
const DURATION := 30.0
const AREA_SIZE := Vector2(900, 560)
const COLORS: Array[Color] = [Color("ff6fae"), Color("ffd43b"), Color("3bc9db"), Color("b197fc"), Color("69db7c")]

var game := "dojo"
var _time_left := DURATION
var _score := 0
var _targets: Array = []       # {pos, radius, age, life, lane, speed, color}
var _splats: Array = []        # {pos, age, color, text}
var _spawn_timer := 0.0
var _running := false
var _rng := RandomNumberGenerator.new()
var _area_rect := Rect2()
var _result_box: PanelContainer


static func open(parent: Control, which: String) -> MiniGame:
	var m := MiniGame.new()
	m.game = which
	parent.add_child(m)
	m._build()
	return m


func _build() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = load("res://scripts/ui/main.gd").paper_theme()
	_running = true
	_spawn_timer = 0.3


func _process(delta: float) -> void:
	_area_rect = Rect2((size - AREA_SIZE) * 0.5, AREA_SIZE)
	if _running:
		_time_left -= delta
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn()
		for t in _targets:
			t.age += delta
			if game == "pie":
				t.pos.x += t.speed * delta
		_targets = _targets.filter(func(t: Dictionary) -> bool:
			return t.age < t.life and t.pos.x < _area_rect.end.x + 60.0 and t.pos.x > _area_rect.position.x - 60.0)
		if _time_left <= 0.0:
			_end_game()
	for s in _splats:
		s.age += delta
	_splats = _splats.filter(func(s: Dictionary) -> bool: return s.age < 0.7)
	queue_redraw()


func _spawn() -> void:
	var progress := 1.0 - _time_left / DURATION
	if game == "dojo":
		_spawn_timer = lerpf(0.75, 0.38, progress)
		var margin := 50.0
		_targets.append({"pos": _area_rect.position + Vector2(_rng.randf_range(margin, AREA_SIZE.x - margin),
			_rng.randf_range(margin + 30.0, AREA_SIZE.y - margin)), "radius": 42.0, "age": 0.0,
			"life": lerpf(1.4, 0.85, progress), "color": COLORS[_rng.randi() % COLORS.size()], "lane": 0, "speed": 0.0})
	else:
		_spawn_timer = lerpf(0.9, 0.5, progress)
		var lane := _rng.randi() % 3
		var speeds: Array[float] = [140.0, 220.0, 320.0]
		var speed: float = speeds[lane] * (1.0 + progress * 0.5)
		var from_left := lane != 1
		var y := _area_rect.position.y + 140.0 + lane * 140.0
		var x := _area_rect.position.x - 40.0 if from_left else _area_rect.end.x + 40.0
		_targets.append({"pos": Vector2(x, y), "radius": 38.0 - lane * 5.0, "age": 0.0, "life": 99.0,
			"color": COLORS[_rng.randi() % COLORS.size()], "lane": lane, "speed": speed if from_left else -speed})


func _gui_input(event: InputEvent) -> void:
	accept_event()
	if not _running or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos: Vector2 = event.position
	for i in range(_targets.size() - 1, -1, -1):
		var t: Dictionary = _targets[i]
		if pos.distance_to(t.pos) <= t.radius * _scale_of(t):
			var points := 1 if game == "dojo" else int(t.lane) + 1
			_score += points
			_splats.append({"pos": t.pos, "age": 0.0, "color": t.color, "text": "+%d" % points})
			_targets.remove_at(i)
			Sfx.play("punch", 0.15, -4.0)
			return
	if game == "pie" and _area_rect.has_point(pos):
		_splats.append({"pos": pos, "age": 0.0, "color": Color("fff5e6"), "text": ""})


func _scale_of(t: Dictionary) -> float:
	if game != "dojo":
		return 1.0
	var p: float = t.age / t.life
	return 1.0 - 0.6 * p


func _end_game() -> void:
	_running = false
	_targets.clear()
	var info: Dictionary = GameState.MINIGAMES[game]
	var best_before := int(GameState.stat(info.stat))
	var gain := GameState.record_minigame(game, _score)
	Sfx.play("achievement", 0.0, -4.0)
	_result_box = PanelContainer.new()
	_result_box.custom_minimum_size = Vector2(440, 0)
	add_child(_result_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_result_box.add_child(box)
	var title := Label.new()
	title.text = tr("%d Punkte!") % _score
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("ffd43b"))
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(400, 0)
	text.text = (tr("Neuer Rekord!\n") if _score > best_before else tr("Rekord: %d\n") % best_before) + \
		(tr("+%d Beulen-Marken") % gain if gain > 0 else tr("Heute gibt es dafür keine weiteren Beulen-Marken."))
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for label in [tr("Nochmal"), tr("Fertig")]:
		var b := Button.new()
		b.text = label
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 0)
		row.add_child(b)
		b.pressed.connect(_restart if label == "Nochmal" else _close)
	_center_result.call_deferred()


func _center_result() -> void:
	if not is_instance_valid(_result_box):
		return
	_result_box.reset_size()
	_result_box.position = (size - _result_box.size) * 0.5


func _restart() -> void:
	_result_box.queue_free()
	_score = 0
	_time_left = DURATION
	_running = true
	_spawn_timer = 0.3


func _close() -> void:
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.13, 0.09, 0.6))
	var bg := Color("fff8ec") if game == "dojo" else Color("ffe3e3")
	draw_rect(_area_rect.grow(6), INK)
	draw_rect(_area_rect, bg)
	if game == "pie":
		for lane in 3:
			var y := _area_rect.position.y + 140.0 + lane * 140.0 + 44.0
			draw_rect(Rect2(_area_rect.position.x, y, AREA_SIZE.x, 14), Color("c92a2a"))
	var font := get_theme_default_font()
	var title := tr("Reaktions-Dojo") if game == "dojo" else tr("Tortenwurf-Schießbude")
	_text(font, _area_rect.position + Vector2(20, 44), title, 34, Color("3bc9db"))
	_text(font, _area_rect.position + Vector2(AREA_SIZE.x - 300, 44), tr("Punkte %d · %d s") % [_score, ceili(maxf(_time_left, 0.0))], 28, Color("ffd43b"))
	if _running and _time_left > DURATION - 2.0:
		var hint := tr("Triff die Ziele, bevor sie schrumpfen!") if game == "dojo" else tr("Wirf Torten auf die Pappfiguren! Schnelle Reihen geben mehr Punkte.")
		_text(font, _area_rect.position + Vector2(20, AREA_SIZE.y - 24), hint, 18, Color.WHITE)
	for t in _targets:
		var rad: float = t.radius * _scale_of(t)
		if game == "dojo":
			draw_circle(t.pos, rad, t.color)
			draw_circle(t.pos, rad * 0.55, Color.WHITE)
			draw_circle(t.pos, rad * 0.25, t.color)
			draw_arc(t.pos, rad, 0.0, TAU, 32, INK, 4.0, true)
		else:
			# Pappfigur: Kopf mit Mütze auf einem Stiel
			draw_line(t.pos, t.pos + Vector2(0, rad * 1.6), INK, 5.0)
			draw_circle(t.pos, rad, Color("f6c39b"))
			draw_arc(t.pos, rad, 0.0, TAU, 28, INK, 3.0, true)
			draw_rect(Rect2(t.pos + Vector2(-rad, -rad * 1.1), Vector2(rad * 2.0, rad * 0.6)), t.color)
			draw_circle(t.pos + Vector2(-rad * 0.35, -rad * 0.05), rad * 0.12, INK)
			draw_circle(t.pos + Vector2(rad * 0.35, -rad * 0.05), rad * 0.12, INK)
			draw_line(t.pos + Vector2(-rad * 0.4, rad * 0.35), t.pos + Vector2(rad * 0.4, rad * 0.35), INK, 3.0)
	for s in _splats:
		var a: float = 1.0 - s.age / 0.7
		var col: Color = s.color
		col.a = a
		for i in 7:
			draw_circle(s.pos + Vector2.from_angle(i * TAU / 7.0) * 22.0, 12.0, col)
		draw_circle(s.pos, 22.0, col)
		if s.text != "":
			_text(font, s.pos + Vector2(-14, -30 - s.age * 40.0), s.text, 26, Color(1, 1, 1, a))


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(6, font_size / 4), Color(INK, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
