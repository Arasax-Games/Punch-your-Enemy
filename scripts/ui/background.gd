class_name GameBackground
extends Control
## Zeichnet den Hintergrund je nach Einstellung: Standard, Zirkuszelt, Weltraum, Arena oder Wohnzimmer.
## Hintergründe werden im Lorbeer-Baum (Zweig "Show") mit Beulen-Marken freigeschaltet.

var _stars: Array = []
var _time := 0.0
## Höhe der Bühnenkante (lokale Koordinaten); setzt der Hauptbildschirm passend zum Podest unter dem Opfer.
var floor_y := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 160:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.0, 2.6), rng.randf() * TAU])


static var _dots: Texture2D


static func _dot_texture() -> Texture2D:
	if _dots == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for y in 16:
			for x in 16:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
				img.set_pixel(x, y, Color(1, 1, 1, 0.06 * clampf(2.1 - d, 0.0, 1.0)))
		_dots = ImageTexture.create_from_image(img)
	return _dots


func _process(delta: float) -> void:
	_time += delta
	if GameState.background in ["weltraum", "arena"] and not GameState.reduced_effects:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	match GameState.background:
		"zirkus":
			_draw_circus()
		"weltraum":
			_draw_space()
		"arena":
			_draw_arena()
		"wohnzimmer":
			_draw_living_room()
		_:
			_draw_night_arena()


## Standard: Comic-Arena bei Nacht – dunkles Lila mit Rasterpunkten und einem Bühnenboden.
func _draw_night_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("231a4a"))
	# Rasterpunkte als gekachelte Textur: ein Zeichenaufruf statt Tausender einzelner Kreise.
	draw_texture_rect(_dot_texture(), Rect2(Vector2.ZERO, size), true)
	var fy := floor_y if floor_y > 0.0 else size.y * 0.74
	draw_rect(Rect2(0, fy, size.x, size.y - fy), Color("1a1338"))
	draw_line(Vector2(0, fy), Vector2(size.x, fy), Color("0f0b24"), 3.0)


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


func _draw_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("4a3f6b"))
	# Scheinwerfer
	for i in 3:
		var top := Vector2(size.x * (0.2 + 0.3 * i), 0)
		var sway := sin(_time * 0.6 + i) * size.x * 0.05 if not GameState.reduced_effects else 0.0
		draw_colored_polygon(PackedVector2Array([top, Vector2(top.x - size.x * 0.12 + sway, size.y),
			Vector2(top.x + size.x * 0.12 + sway, size.y)]), Color(1.0, 0.95, 0.7, 0.10))
	# Ringboden und Seile
	draw_rect(Rect2(0, size.y * 0.78, size.x, size.y * 0.22), Color("1971c2"))
	for i in 3:
		var y := size.y * (0.52 + i * 0.09)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("e03131"), 8.0)
	draw_rect(Rect2(size.x * 0.03, size.y * 0.45, 26, size.y * 0.4), Color("adb5bd"))
	draw_rect(Rect2(size.x * 0.97 - 26, size.y * 0.45, 26, size.y * 0.4), Color("adb5bd"))


func _draw_living_room() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f3d9a4"))
	# Tapete mit Streifen
	var stripe := 48.0
	var x := 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, stripe * 0.5, size.y * 0.75), Color("ead09a"))
		x += stripe
	# Teppichboden und Sockelleiste
	draw_rect(Rect2(0, size.y * 0.75, size.x, size.y * 0.25), Color("a9714b"))
	draw_rect(Rect2(0, size.y * 0.74, size.x, 10), Color("6b4226"))
	# Sofa
	var sofa := Rect2(size.x * 0.06, size.y * 0.58, size.x * 0.2, size.y * 0.18)
	draw_rect(sofa, Color("2f9e44"))
	draw_rect(Rect2(sofa.position - Vector2(0, size.y * 0.08), Vector2(sofa.size.x, size.y * 0.1)), Color("2b8a3e"))
	# Stehlampe
	var lamp := Vector2(size.x * 0.9, size.y * 0.75)
	draw_line(lamp, lamp - Vector2(0, size.y * 0.42), Color("495057"), 6.0)
	draw_colored_polygon(PackedVector2Array([lamp - Vector2(50, size.y * 0.42), lamp - Vector2(-50, size.y * 0.42),
		lamp - Vector2(-30, size.y * 0.52), lamp - Vector2(30, size.y * 0.52)]), Color("ffd43b"))
	# Bilderrahmen
	draw_rect(Rect2(size.x * 0.08, size.y * 0.12, 120, 90), Color("ffffff"))
	draw_rect(Rect2(size.x * 0.08, size.y * 0.12, 120, 90), Color("6b4226"), false, 8.0)
