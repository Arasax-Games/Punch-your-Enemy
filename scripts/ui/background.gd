class_name GameBackground
extends Control
## Zeichnet den Hintergrund je nach Einstellung: Standard (warm), Zirkuszelt oder Weltraum.
## Hintergründe werden im Lorbeer-Baum (Zweig "Show") mit Beulen-Marken freigeschaltet.

var _stars: Array = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 160:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.0, 2.6), rng.randf() * TAU])


func _process(delta: float) -> void:
	_time += delta
	if GameState.background == "weltraum" and not GameState.reduced_effects:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	match GameState.background:
		"zirkus":
			_draw_circus()
		"weltraum":
			_draw_space()
		_:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.996, 0.925, 0.8))


func _draw_circus() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff4e6"))
	var top := Vector2(size.x * 0.5, -size.y * 0.6)
	var stripes := 24
	for i in stripes:
		if i % 2 == 1:
			continue
		var a1 := PI * float(i) / stripes
		var a2 := PI * float(i + 1) / stripes
		var far := size.length() * 2.0
		draw_colored_polygon(PackedVector2Array([top, top + Vector2.from_angle(a1) * far, top + Vector2.from_angle(a2) * far]),
			Color("ff8787"))
	# Manege-Boden
	draw_rect(Rect2(0, size.y * 0.88, size.x, size.y * 0.12), Color("e8a33d"))
	draw_line(Vector2(0, size.y * 0.88), Vector2(size.x, size.y * 0.88), Color("2b2118"), 4.0)


func _draw_space() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1f3b"))
	draw_circle(Vector2(size.x * 0.85, size.y * 0.22), size.y * 0.12, Color("3b3f73"))
	draw_circle(Vector2(size.x * 0.12, size.y * 0.8), size.y * 0.2, Color("2c2f5a"))
	for s in _stars:
		var twinkle := 0.6 + 0.4 * sin(_time * 2.0 + s[2])
		draw_circle(s[0] * size, s[1], Color(1, 1, 0.85, twinkle))
