class_name BumpOverlay
extends Control
## Dauerhafte Beulen-Level-Optik (alle 1.000 Treffer pro Opfer ein Level, max. 10).
## Positionen kommen aus data/figures.json ("anchors", UV 0..1), damit es auch auf eigenen Bildern passt.
##  1 Pflaster · 2 Veilchen links · 3 Riesenbeule · 4 Pflasterkreuz · 5 kreisende Sterne
##  6 Veilchen rechts · 7 Kopfverband · 8 zweite Beule · 9 rauchende Ohren · 10 kreisende Vögelchen

const INK := Color("2b2118")

var area: TargetArea
var _time := 0.0


func _ready() -> void:
	area = get_parent() as TargetArea
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if GameState.current_bump_level() >= 5:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _anchor(key: String) -> Vector2:
	var anchors: Dictionary = GameState.target_figure().get("anchors", {})
	var uv: Array = anchors.get(key, [0.5, 0.5])
	return area.uv_to_local(Vector2(uv[0], uv[1]))


func _draw() -> void:
	if area == null:
		return
	var level := GameState.current_bump_level()
	if level <= 0:
		return
	var r := area.image_rect()
	var k := clampf(minf(r.size.x, r.size.y) / 520.0, 0.4, 2.0)
	var animate := not GameState.reduced_effects
	var t := _time if animate else 0.0
	# Bei der Standardfigur sorgt ab Level 4 schon die Mimik für Ausdruck; Overlays bleiben trotzdem.
	if level >= 1:
		_plaster(_anchor("cheek"), 0.35, k)
	if level >= 2:
		_black_eye(_anchor("eye_left"), k)
	if level >= 3:
		_bump(_anchor("head_top"), 30.0 * k, k)
	if level >= 4:
		_plaster(_anchor("forehead") + Vector2(70, -20) * k, -0.5, k)
	if level >= 5:
		_orbit_stars(_anchor("crown") + Vector2(0, 30) * k, k, t)
	if level >= 6:
		_black_eye(_anchor("eye_right"), k)
	if level >= 7:
		_bandage(_anchor("forehead"), r.size.x * 0.55, k)
	if level >= 8:
		_bump(_anchor("head_top") + Vector2(-150, 20) * k, 22.0 * k, k)
	if level >= 9:
		_smoke(_anchor("ear_left"), k, t, -1.0)
		_smoke(_anchor("ear_right"), k, t, 1.0)
	if level >= 10:
		_orbit_birds(_anchor("crown") + Vector2(0, 10) * k, k, t)


func _plaster(pos: Vector2, rot: float, k: float) -> void:
	var w := 64.0 * k
	var h := 20.0 * k
	for angle in [rot + 0.785, rot - 0.785]:
		draw_set_transform(pos, angle)
		var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
		draw_rect(rect, Color("f4d3a1"))
		draw_rect(Rect2(-h * 0.4, -h * 0.4, h * 0.8, h * 0.8), Color("e9b97a"))
		draw_rect(rect, INK, false, 2.5 * k)
	draw_set_transform(Vector2.ZERO)


func _black_eye(pos: Vector2, k: float) -> void:
	var rad := 40.0 * k
	draw_arc(pos, rad, 0.0, TAU, 40, Color(0.45, 0.25, 0.6, 0.55), 14.0 * k, true)
	draw_arc(pos, rad + 6.0 * k, 0.0, TAU, 40, Color(0.3, 0.6, 0.35, 0.25), 6.0 * k, true)


func _bump(pos: Vector2, rad: float, k: float) -> void:
	draw_circle(pos, rad, Color("f59f9f"))
	draw_arc(pos, rad, 0.0, TAU, 32, INK, 3.0 * k, true)
	draw_circle(pos + Vector2(-0.35, -0.35) * rad, rad * 0.3, Color(1, 1, 1, 0.7))


func _bandage(center: Vector2, width: float, k: float) -> void:
	var h := 30.0 * k
	draw_set_transform(center, -0.06)
	var rect := Rect2(-width * 0.5, -h * 0.5, width, h)
	draw_rect(rect, Color("f8f9fa"))
	for i in 5:
		var x := -width * 0.5 + width * (i + 0.5) / 5.0
		draw_line(Vector2(x - 8 * k, -h * 0.5), Vector2(x + 8 * k, h * 0.5), Color(INK, 0.15), 2.0 * k)
	draw_rect(rect, INK, false, 2.5 * k)
	# Schleife
	draw_circle(Vector2(width * 0.5, 0), 9.0 * k, Color("f8f9fa"))
	draw_arc(Vector2(width * 0.5, 0), 9.0 * k, 0.0, TAU, 16, INK, 2.0 * k, true)
	draw_set_transform(Vector2.ZERO)


func _orbit_stars(center: Vector2, k: float, t: float) -> void:
	for i in 4:
		var a := t * 3.0 + i * TAU / 4.0
		var p := center + Vector2(cos(a) * 120.0 * k, sin(a) * 26.0 * k)
		_star(p, 13.0 * k, Color("ffd43b"))


func _orbit_birds(center: Vector2, k: float, t: float) -> void:
	for i in 3:
		var a := -t * 2.2 + i * TAU / 3.0
		var p := center + Vector2(cos(a) * 95.0 * k, sin(a) * 20.0 * k)
		var flap := sin(t * 18.0 + i) * 6.0 * k
		draw_circle(p, 10.0 * k, Color("74c0fc"))
		draw_arc(p, 10.0 * k, 0.0, TAU, 16, INK, 2.0 * k, true)
		draw_line(p + Vector2(-4, -2) * k, p + Vector2(-14 * k, -8 * k - flap), INK, 2.5 * k)
		draw_line(p + Vector2(4, -2) * k, p + Vector2(14 * k, -8 * k - flap), INK, 2.5 * k)
		draw_colored_polygon(PackedVector2Array([p + Vector2(9, 0) * k, p + Vector2(16, 3) * k, p + Vector2(9, 5) * k]), Color("ff922b"))


func _smoke(ear: Vector2, k: float, t: float, side: float) -> void:
	for i in 3:
		var phase := fmod(t * 0.8 + i / 3.0, 1.0)
		var p := ear + Vector2(side * (14.0 + phase * 30.0), -10.0 - phase * 70.0) * k
		draw_circle(p, (10.0 + phase * 14.0) * k, Color(0.85, 0.85, 0.85, 0.75 * (1.0 - phase)))


func _star(center: Vector2, radius: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rad)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, INK, 1.5, true)
