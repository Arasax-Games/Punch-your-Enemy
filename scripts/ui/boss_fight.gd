class_name BossFight
extends Control
## Boss-Kampf über dem Zielbild: Lebensleiste, Zeit, wandernde Schwachstelle (×5) und harmlose Gimmicks
## (Wegducken, Pappschild, Gummiente). Die Logik (Lebenspunkte, Zeit, Belohnung) liegt in GameState.

const INK := Color("2b2118")
const WEAK_RADIUS := 0.07       # in UV-Einheiten
const WEAK_MOVE_INTERVAL := 2.2

var area: TargetArea
var _time := 0.0
var _weak_uv := Vector2(0.5, 0.5)
var _weak_timer := 0.0
var _gimmick_timer := 0.0
var _gimmick_on := false
var _shield_left := true
var _duck_uv := Vector2(0.3, 0.6)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	area = get_parent() as TargetArea
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	visible = false


func start() -> void:
	visible = true
	_time = 0.0
	_gimmick_on = false
	_gimmick_timer = 2.0
	_move_weak_spot()


func stop() -> void:
	visible = false
	area.position_offset(Vector2.ZERO)


func _gimmick() -> String:
	return String(GameState.boss_gimmick.get("id", ""))


func _move_weak_spot() -> void:
	_weak_uv = Vector2(_rng.randf_range(0.3, 0.7), _rng.randf_range(0.3, 0.75))
	_weak_timer = WEAK_MOVE_INTERVAL


func _process(delta: float) -> void:
	if not visible:
		return
	if not GameState.boss_active:
		stop()
		return
	_time += delta
	_weak_timer -= delta
	if _weak_timer <= 0.0:
		_move_weak_spot()
	_gimmick_timer -= delta
	if _gimmick_timer <= 0.0:
		_gimmick_on = not _gimmick_on
		_gimmick_timer = 1.0 if _gimmick_on else _rng.randf_range(2.0, 3.5)
		if _gimmick_on:
			_shield_left = _rng.randf() < 0.5
			_duck_uv = Vector2(_rng.randf_range(0.3, 0.7), _rng.randf_range(0.35, 0.7))
	if _gimmick() == "ducken":
		var target := 0.35 if _gimmick_on else 0.0
		area.position_offset(Vector2(0, lerpf(0.0, area.image_rect().size.y, target)))
	queue_redraw()


## Was ein Treffer an dieser Stelle bewirkt: -1 = geblockt, sonst Schadens-Multiplikator.
func filter_hit(uv: Vector2) -> float:
	if not visible or not GameState.boss_active:
		return 1.0
	if _gimmick_on:
		match _gimmick():
			"ducken":
				return -1.0
			"pappschild":
				if (uv.x < 0.5) == _shield_left:
					return -1.0
			"gummiente":
				if uv.distance_to(_duck_uv) < 0.09:
					return -1.0
	if uv.distance_to(_weak_uv) < WEAK_RADIUS:
		return float(GameState.boss_config.get("weak_spot_mult", 5))
	return 1.0


func _draw() -> void:
	if not visible:
		return
	var r := area.image_rect()
	var k := clampf(minf(r.size.x, r.size.y) / 520.0, 0.5, 2.0)
	# Schwachstelle
	var weak := r.position + _weak_uv * r.size
	var pulse := 1.0 + 0.15 * sin(_time * 10.0)
	draw_circle(weak, WEAK_RADIUS * r.size.x * pulse, Color(1.0, 0.85, 0.1, 0.35))
	draw_arc(weak, WEAK_RADIUS * r.size.x * pulse, 0.0, TAU, 32, Color("e67700"), 4.0 * k, true)
	draw_line(weak + Vector2(-12, 0) * k, weak + Vector2(12, 0) * k, Color("e67700"), 3.0 * k)
	draw_line(weak + Vector2(0, -12) * k, weak + Vector2(0, 12) * k, Color("e67700"), 3.0 * k)
	# Gimmicks
	if _gimmick_on:
		match _gimmick():
			"pappschild":
				var half := Rect2(r.position + Vector2(0 if _shield_left else r.size.x * 0.5, r.size.y * 0.15),
					Vector2(r.size.x * 0.5, r.size.y * 0.8))
				draw_rect(half, Color("d9a066"))
				for i in 4:
					var y := half.position.y + half.size.y * (i + 1) / 5.0
					draw_line(Vector2(half.position.x + 10, y), Vector2(half.end.x - 10, y), Color(INK, 0.25), 3.0)
				draw_rect(half, INK, false, 4.0 * k)
			"gummiente":
				_draw_duck(r.position + _duck_uv * r.size, 38.0 * k, k)
	# Lebensleiste und Zeit
	var bar := Rect2(Vector2(r.position.x + r.size.x * 0.1, size.y - 40.0), Vector2(r.size.x * 0.8, 28))
	draw_rect(bar, Color("eee3d0"))
	var frac := GameState.boss_hp / maxf(GameState.boss_max_hp, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("fa5252"))
	draw_rect(bar, INK, false, 3.0)
	var font := get_theme_default_font()
	var label := "BOSS · %s · %d s" % [GameState.boss_gimmick.get("name", ""), ceili(GameState.boss_time)]
	draw_string_outline(font, bar.position + Vector2(10, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, INK)
	draw_string(font, bar.position + Vector2(10, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_duck(pos: Vector2, size: float, k: float) -> void:
	draw_circle(pos + Vector2(0, size * 0.3), size, Color("ffd43b"))
	draw_arc(pos + Vector2(0, size * 0.3), size, 0.0, TAU, 32, INK, 3.0 * k, true)
	var head := pos + Vector2(size * 0.55, -size * 0.55)
	draw_circle(head, size * 0.55, Color("ffd43b"))
	draw_arc(head, size * 0.55, 0.0, TAU, 24, INK, 3.0 * k, true)
	draw_circle(head + Vector2(size * 0.15, -size * 0.1), size * 0.1, INK)
	draw_colored_polygon(PackedVector2Array([head + Vector2(size * 0.45, 0), head + Vector2(size * 0.95, size * 0.1),
		head + Vector2(size * 0.45, size * 0.25)]), Color("ff922b"))
