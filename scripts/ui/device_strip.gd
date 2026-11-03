class_name DeviceStrip
extends Control
## Animierte Geräte-Reihe unter dem Zielbild: jedes gekaufte Gerät als kleine Karte, die im Takt auf
## das Opfer einhaut. Der Rahmen zeigt die Meilenstein-Stufe (1, 5, 25, 50, 100, 150, 200 Stück):
## Holz → Bronze → Silber → Gold → Platin → Rubin → Regenbogen, dazu Sternchen.

const INK := Color("2b2118")
const CARD := Vector2(66, 84)
const GAP := 6.0
const TIER_COLORS: Array[Color] = [
	Color("c0895a"), Color("c0895a"), Color("cd7f32"), Color("adb5bd"), Color("fcc419"), Color("e5dbff"), Color("ff6b6b"), Color.WHITE,
]

var _icons: Dictionary = {}   # Geräte-ID -> Texture2D
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _icon(d: Dictionary) -> Texture2D:
	if not _icons.has(d.id) and ResourceLoader.exists(String(d.get("icon", ""))):
		_icons[d.id] = load(d.icon)
	return _icons.get(d.id)


func _owned() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in GameState.device_defs:
		if GameState.device_count(d.id) > 0:
			out.append(d)
	return out


func _draw() -> void:
	var owned := _owned()
	var font := get_theme_default_font()
	if owned.is_empty():
		var hint := tr("Hier tauchen deine Geräte auf, sobald du welche kaufst.")
		draw_string(font, Vector2(0, size.y * 0.55), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color("a99fdc"))
		return
	var scale_f := minf(1.0, size.x / (owned.size() * (CARD.x + GAP)))
	var card := CARD * scale_f
	var total := owned.size() * (card.x + GAP * scale_f) - GAP * scale_f
	var x := (size.x - total) * 0.5
	var animate := not GameState.reduced_effects
	for i in owned.size():
		var d: Dictionary = owned[i]
		var count := GameState.device_count(d.id)
		var tier := Balance.milestone_tier(count)
		var rect := Rect2(Vector2(x, size.y - card.y), card)
		_draw_card(rect, d, count, tier, i, animate, font, scale_f)
		x += card.x + GAP * scale_f


func _draw_card(rect: Rect2, d: Dictionary, count: int, tier: int, index: int, animate: bool, font: Font, k: float) -> void:
	var frame: Color = TIER_COLORS[mini(tier, TIER_COLORS.size() - 1)]
	if tier >= 7:
		frame = Color.from_hsv(fmod(_time * 0.3 + index * 0.1, 1.0), 0.6, 1.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("2a2156")
	panel.set_corner_radius_all(int(10 * k))
	panel.set_border_width_all(int(maxf(2.0, (2.0 + tier * 0.6) * k)))
	panel.border_color = frame
	draw_style_box(panel, rect)
	# Takt: mehr Geräte = schneller, versetzt pro Karte
	var speed := clampf(0.6 + log(float(count) + 1.0) * 0.6, 0.6, 4.0)
	var phase := fmod(_time * speed + index * 0.37, 1.0)
	var hop := 0.0
	var tilt := 0.0
	if animate:
		hop = -absf(sin(phase * PI)) * 8.0 * k if phase < 0.5 else 0.0
		tilt = -0.35 * sin(phase * TAU) if phase < 0.5 else 0.0
	var icon := _icon(d)
	if icon:
		var icon_size := Vector2(44, 44) * k
		var center := rect.position + Vector2(rect.size.x * 0.5, 30 * k + hop)
		draw_set_transform(center, tilt)
		draw_texture_rect(icon, Rect2(-icon_size * 0.5, icon_size), false)
		draw_set_transform(Vector2.ZERO)
	# Sternchen für Meilensteine ab 5 Stück
	var stars := maxi(0, tier - 1)
	for s in stars:
		var p := rect.position + Vector2(rect.size.x * 0.5 + (s - (stars - 1) * 0.5) * 9.0 * k, 6 * k)
		_star(p, 4.5 * k, Color("fcc419"))
	var label := Num.whole(count)
	draw_string_outline(font, rect.position + Vector2(0, rect.size.y - 8 * k), label, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, int(15 * k), 4, Color("0f0b24"))
	draw_string(font, rect.position + Vector2(0, rect.size.y - 8 * k), label, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, int(15 * k), Color.WHITE)


func _star(center: Vector2, radius: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rad)
	draw_colored_polygon(pts, fill)


## Tooltip: Name, Anzahl, nächster Meilenstein.
func _get_tooltip(at_position: Vector2) -> String:
	var owned := _owned()
	if owned.is_empty():
		return ""
	var scale_f := minf(1.0, size.x / (owned.size() * (CARD.x + GAP)))
	var step := (CARD.x + GAP) * scale_f
	var total := owned.size() * step - GAP * scale_f
	var i := int((at_position.x - (size.x - total) * 0.5) / step)
	if i < 0 or i >= owned.size():
		return ""
	var d: Dictionary = owned[i]
	var count := GameState.device_count(d.id)
	var next := -1
	for m in Balance.MILESTONES:
		if count < m:
			next = m
			break
	var text := "%s: %s" % [d.name, Num.whole(count)]
	if next > 0:
		text += "\n" + tr("Nächster Meilenstein bei %d Stück") % next
	else:
		text += "\n" + tr("Alle Meilensteine erreicht!")
	return text
