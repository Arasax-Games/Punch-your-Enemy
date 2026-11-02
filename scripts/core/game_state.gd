extends Node
## Zentraler Spielzustand (Autoload "GameState").
## Hält Währung, Geräte, Upgrades, Erfolge, Buffs und Zielbilder und kümmert sich ums Speichern.
## Die UI liest den Zustand regelmäßig aus; Signale gibt es nur für strukturelle Änderungen und Ereignisse.

signal device_bought(id: String, amount: int)
signal device_sold(id: String)
signal upgrade_bought(id: String)
signal target_changed
signal achievement_unlocked(id: String)
signal shoe_spawned(kind: String)
signal buffs_changed

const SAVE_VERSION := 2
const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"
const IMAGE_DIR := "user://images"
const MAX_IMAGE_EDGE := 1024
const AUTOSAVE_INTERVAL := 30.0
const ACHIEVEMENT_CHECK_INTERVAL := 0.5
const DEFAULT_TARGET := "bombastus"
const DEFAULT_TARGET_NAME := "Generalissimo Bombastus von Größenwahn"
const DEFAULT_TEXTURE_PATH := "res://assets/figures/bombastus.svg"
const DEVICES_PATH := "res://data/devices.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"

const SHOE_GOLDEN := "golden"
const SHOE_SILVER := "silver"
const GOLDEN_LIFETIME := 13.0
const SILVER_LIFETIME := 8.0
const OFFLINE_RATE := 0.5
const OFFLINE_CAP := 8.0 * 3600.0
const OFFLINE_MIN_SECONDS := 60.0
const CHAIN_MAX := 7

const STAT_KEYS: Array[String] = [
	"crits", "golden_shoes", "silver_slippers", "frenzies", "bad_luck",
	"images_imported", "play_time", "showers", "devices_sold", "long_return",
]

# --- Daten (aus JSON) ---
var device_defs: Array[Dictionary] = []
var upgrade_defs: Array[Dictionary] = []
var achievement_defs: Array[Dictionary] = []
var _device_by_id: Dictionary = {}
var _upgrade_by_id: Dictionary = {}
var _achievement_by_id: Dictionary = {}

# --- Spielstand ---
var wumms: float = 0.0
var total_wumms: float = 0.0
var total_hits: int = 0
var beulen_marken: int = 0
var devices: Dictionary = {}            # id -> Anzahl
var upgrades: Dictionary = {}           # id -> true
var revealed_upgrades: Dictionary = {}  # id -> true (einmal sichtbar = bleibt sichtbar)
var achievements: Dictionary = {}       # id -> true
var stats: Dictionary = {}              # siehe STAT_KEYS
var target_id: String = DEFAULT_TARGET
var target_names: Dictionary = {}       # target_id -> Anzeigename
var target_hits: Dictionary = {}        # target_id -> Treffer
var reduced_effects: bool = false
var sound_on: bool = true

# --- Laufzeit (wird nicht gespeichert) ---
var buffs: Array = []       # {id, name, remaining, duration, wps_mult, click_mult}
var idle_time: float = 0.0              # Sekunden seit dem letzten Treffer (diese Sitzung)
var pending_offline: Dictionary = {}    # {seconds, gain} für den Willkommen-zurück-Bildschirm
var _shoe_timers: Dictionary = {}       # kind -> Sekunden bis zum Erscheinen
var _shoe_active: Dictionary = {}       # kind -> true, solange ein Schuh sichtbar ist
var _chain_count: int = 0
var _autosave_timer: float = 0.0
var _achievement_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_data()
	_reset_stats()
	if load_game():
		_apply_offline_since_save()
	reset_shoe_timers()


func _process(delta: float) -> void:
	tick(delta)
	_update_shoes(delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()
	_achievement_timer += delta
	if _achievement_timer >= ACHIEVEMENT_CHECK_INTERVAL:
		_achievement_timer = 0.0
		check_achievements()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# =====================================================================
# Daten laden
# =====================================================================

func load_data() -> void:
	device_defs.clear()
	upgrade_defs.clear()
	achievement_defs.clear()
	for d in _read_json_array(DEVICES_PATH):
		device_defs.append(d)
	for u in _read_json_array(UPGRADES_PATH):
		upgrade_defs.append(u)
	for a in _read_json_array(ACHIEVEMENTS_PATH):
		achievement_defs.append(a)
	_device_by_id.clear()
	for d in device_defs:
		_device_by_id[d.id] = d
	_upgrade_by_id.clear()
	for u in upgrade_defs:
		_upgrade_by_id[u.id] = u
	_achievement_by_id.clear()
	for a in achievement_defs:
		_achievement_by_id[a.id] = a


func _read_json_array(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	push_error("Konnte %s nicht lesen." % path)
	return []


func device_def(id: String) -> Dictionary:
	return _device_by_id.get(id, {})


func upgrade_def(id: String) -> Dictionary:
	return _upgrade_by_id.get(id, {})


func achievement_def(id: String) -> Dictionary:
	return _achievement_by_id.get(id, {})


func _reset_stats() -> void:
	stats.clear()
	for key in STAT_KEYS:
		stats[key] = 0.0 if key == "play_time" else 0


func stat(key: String) -> float:
	return float(stats.get(key, 0))


func add_stat(key: String, amount: float = 1.0) -> void:
	if key == "play_time":
		stats[key] = stat(key) + amount
	else:
		stats[key] = int(stats.get(key, 0)) + int(amount)


# =====================================================================
# Produktion und Klicks
# =====================================================================

func tick(delta: float) -> void:
	earn(wps() * delta)
	add_stat("play_time", delta)
	idle_time += delta
	_update_buffs(delta)


func earn(amount: float) -> void:
	if amount <= 0.0:
		return
	wumms += amount
	total_wumms += amount


func device_count(id: String) -> int:
	return int(devices.get(id, 0))


func devices_total() -> int:
	var n := 0
	for id in devices:
		n += int(devices[id])
	return n


func device_types_owned() -> int:
	var n := 0
	for d in device_defs:
		if device_count(d.id) > 0:
			n += 1
	return n


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func achievement_count() -> int:
	return achievements.size()


func _owned_effects(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in upgrade_defs:
		if has_upgrade(u.id) and u.effect.type == type:
			out.append(u.effect)
	return out


## Multiplikator eines Gerätetyps: Geräte-Upgrades (×2) und Synergien.
func device_multiplier(id: String) -> float:
	var m := 1.0
	for e in _owned_effects("device_mult"):
		if e.device == id:
			m *= float(e.factor)
	for e in _owned_effects("synergy"):
		if e.target == id:
			m *= Balance.synergy_bonus(device_count(e.source), float(e.percent), int(e.per))
	return m


## Globaler Multiplikator: Sponsorenvertrag, Wutmilch, Fanclub.
func global_multiplier() -> float:
	var m := 1.0
	for e in _owned_effects("wps_mult"):
		m *= float(e.factor)
	var ach := achievement_count()
	for e in _owned_effects("achievement_wps"):
		m *= 1.0 + float(e.percent) * ach
	for e in _owned_effects("fanclub"):
		m *= 1.0 + float(e.percent) * floorf(float(ach) / float(e.per))
	return m


## Produktion eines einzelnen Geräts dieses Typs pro Sekunde (ohne Buffs).
func device_unit_wps(id: String) -> float:
	var d := device_def(id)
	if d.is_empty():
		return 0.0
	return float(d.base_wps) * device_multiplier(id) * global_multiplier()


func device_total_wps(id: String) -> float:
	return device_unit_wps(id) * device_count(id)


## Produktion ohne zeitlich begrenzte Buffs (z. B. für Offline-Fortschritt).
func base_wps() -> float:
	var total := 0.0
	for d in device_defs:
		total += device_total_wps(d.id)
	return total


## Aktuelle Produktion inklusive Buffs.
func wps() -> float:
	return base_wps() * buff_wps_multiplier()


func click_multiplier() -> float:
	var m := 1.0
	for e in _owned_effects("click_mult"):
		m *= float(e.factor)
	return m


func click_wps_percent() -> float:
	var p := 0.0
	for e in _owned_effects("click_wps"):
		p += float(e.percent)
	return p


func click_value() -> float:
	return (1.0 * click_multiplier() + wps() * click_wps_percent()) * buff_click_multiplier()


func crit_chance() -> float:
	var c := 0.0
	for e in _owned_effects("crit"):
		c += float(e.chance)
	return c


func crit_factor() -> float:
	var f := 1.0
	for e in _owned_effects("crit"):
		f = maxf(f, float(e.factor))
	return f


func has_autofire() -> bool:
	return not _owned_effects("autofire").is_empty()


func autofire_rate() -> float:
	var r := 0.0
	for e in _owned_effects("autofire"):
		r = maxf(r, float(e.rate))
	return r


func golden_luck() -> float:
	var l := 1.0
	for e in _owned_effects("golden_luck"):
		l *= float(e.factor)
	return l


## Ein Treffer auf das Zielbild. Gibt {"value": float, "crit": bool} zurück.
func hit() -> Dictionary:
	var value := click_value()
	var crit := crit_chance() > 0.0 and _rng.randf() < crit_chance()
	if crit:
		value *= crit_factor()
		add_stat("crits")
	earn(value)
	total_hits += 1
	idle_time = 0.0
	target_hits[target_id] = int(target_hits.get(target_id, 0)) + 1
	return {"value": value, "crit": crit}


# =====================================================================
# Buffs (Raserei & Co.)
# =====================================================================

func add_buff(id: String, buff_name: String, duration: float, wps_mult: float = 1.0, click_mult: float = 1.0) -> void:
	for b in buffs:
		if b.id == id:
			b.remaining = duration
			b.duration = duration
			buffs_changed.emit()
			return
	buffs.append({"id": id, "name": buff_name, "remaining": duration, "duration": duration,
		"wps_mult": wps_mult, "click_mult": click_mult})
	buffs_changed.emit()


func _update_buffs(delta: float) -> void:
	if buffs.is_empty():
		return
	var before := buffs.size()
	for b in buffs:
		b.remaining -= delta
	buffs = buffs.filter(func(b: Dictionary) -> bool: return b.remaining > 0.0)
	if buffs.size() != before:
		buffs_changed.emit()


func buff_wps_multiplier() -> float:
	var m := 1.0
	for b in buffs:
		m *= float(b.wps_mult)
	return m


func buff_click_multiplier() -> float:
	var m := 1.0
	for b in buffs:
		m *= float(b.click_mult)
	return m


# =====================================================================
# Goldener Schuh und Silberner Pantoffel
# =====================================================================

func reset_shoe_timers() -> void:
	_shoe_timers[SHOE_GOLDEN] = Balance.golden_interval(_rng.randf(), golden_luck())
	_shoe_timers[SHOE_SILVER] = Balance.silver_interval(_rng.randf(), golden_luck())
	_shoe_active.clear()
	_chain_count = 0


func _update_shoes(delta: float) -> void:
	for kind in [SHOE_GOLDEN, SHOE_SILVER]:
		if _shoe_active.get(kind, false):
			continue
		_shoe_timers[kind] = float(_shoe_timers.get(kind, 300.0)) - delta
		if _shoe_timers[kind] <= 0.0:
			_shoe_active[kind] = true
			shoe_spawned.emit(kind)


func shoe_lifetime(kind: String) -> float:
	return GOLDEN_LIFETIME if kind == SHOE_GOLDEN else SILVER_LIFETIME


## Der Schuh ist ungeklickt verschwunden.
func shoe_expired(kind: String) -> void:
	_shoe_active[kind] = false
	if kind == SHOE_GOLDEN:
		_chain_count = 0
	_restart_shoe_timer(kind)


func _restart_shoe_timer(kind: String) -> void:
	if kind == SHOE_GOLDEN:
		_shoe_timers[kind] = Balance.golden_interval(_rng.randf(), golden_luck())
	else:
		_shoe_timers[kind] = Balance.silver_interval(_rng.randf(), golden_luck())


## Schuh wurde angeklickt. Gibt {"title", "text", "good"} für die Anzeige zurück.
func claim_shoe(kind: String, roll: float = -1.0) -> Dictionary:
	_shoe_active[kind] = false
	if roll < 0.0:
		roll = _rng.randf()
	var result: Dictionary
	if kind == SHOE_SILVER:
		add_stat("silver_slippers")
		result = _silver_effect(roll)
		_restart_shoe_timer(kind)
		return result
	add_stat("golden_shoes")
	if _chain_count > 0:
		result = _chain_effect()
	elif roll < 0.07:
		add_stat("bad_luck")
		beulen_marken += 3
		add_buff("pech", "Pech-Schuh", 66.0, 0.5)
		result = {"title": "Pech-Schuh!", "text": "Halbe WPS für 66 s. Trostpreis: 3 Beulen-Marken.", "good": false}
	elif roll < 0.50:
		var gain := Balance.blessing(wps(), wumms, 15.0, 0.15, 13.0)
		earn(gain)
		result = {"title": "Wumms-Segen!", "text": "+%s Wumms" % Num.whole(gain), "good": true}
	elif roll < 0.80:
		add_stat("frenzies")
		add_buff("raserei", "Raserei", 77.0, 7.0)
		result = {"title": "Raserei!", "text": "Alle Geräte ×7 für 77 s.", "good": true}
	elif roll < 0.92:
		add_stat("frenzies")
		add_buff("klick_raserei", "Klick-Raserei", 13.0, 1.0, 777.0)
		result = {"title": "Klick-Raserei!", "text": "Klick-Wert ×777 für 13 s. Hau drauf!", "good": true}
	else:
		_chain_count = 0
		result = _chain_effect()
	if _chain_count == 0:
		_restart_shoe_timer(kind)
	return result


func _chain_effect() -> Dictionary:
	_chain_count += 1
	var gain := Balance.blessing(wps(), wumms, float(_chain_count), 0.05, 13.0 * _chain_count)
	earn(gain)
	var text := "Glied %d: +%s Wumms" % [_chain_count, Num.whole(gain)]
	if _chain_count < CHAIN_MAX and _rng.randf() < 0.75:
		_shoe_timers[SHOE_GOLDEN] = 1.2
		text += " … da kommt noch einer!"
	else:
		text += " Die Kette ist gerissen."
		_chain_count = 0
		_restart_shoe_timer(SHOE_GOLDEN)
	return {"title": "Kettenreaktion!", "text": text, "good": true}


func _silver_effect(roll: float) -> Dictionary:
	if roll < 0.7:
		var gain := Balance.blessing(wps(), wumms, 1.0, 0.05, 7.0)
		earn(gain)
		return {"title": "Silberner Pantoffel!", "text": "+%s Wumms" % Num.whole(gain), "good": true}
	add_buff("mini_raserei", "Kleine Raserei", 30.0, 2.0)
	return {"title": "Silberner Pantoffel!", "text": "Alle Geräte ×2 für 30 s.", "good": true}


# =====================================================================
# Geräte kaufen und verkaufen
# =====================================================================

## Wie viele Geräte bei der gewählten Kaufmenge gekauft würden (-1 = Max).
func amount_for_mode(id: String, mode: int) -> int:
	if mode > 0:
		return mode
	var d := device_def(id)
	return Balance.max_affordable(float(d.base_cost), device_count(id), wumms)


func device_cost(id: String, amount: int) -> float:
	var d := device_def(id)
	if d.is_empty():
		return INF
	return Balance.bulk_cost(float(d.base_cost), device_count(id), maxi(amount, 1))


func buy_device(id: String, amount: int) -> bool:
	if amount <= 0 or device_def(id).is_empty():
		return false
	var cost := device_cost(id, amount)
	if wumms < cost:
		return false
	wumms -= cost
	devices[id] = device_count(id) + amount
	device_bought.emit(id, amount)
	return true


func sell_device(id: String) -> bool:
	var owned := device_count(id)
	if owned <= 0:
		return false
	var d := device_def(id)
	wumms += Balance.sell_refund(float(d.base_cost), owned)
	devices[id] = owned - 1
	add_stat("devices_sold")
	device_sold.emit(id)
	return true


func is_device_visible(index: int) -> bool:
	if index <= 0:
		return true
	var d: Dictionary = device_defs[index]
	if device_count(d.id) > 0:
		return true
	var prev: Dictionary = device_defs[index - 1]
	return device_count(prev.id) > 0 or total_wumms >= float(d.base_cost) * 0.5


# =====================================================================
# Upgrades
# =====================================================================

func upgrade_requirement_met(u: Dictionary) -> bool:
	var req: Dictionary = u.get("requires", {})
	if req.has("device") and device_count(req.device) < int(req.get("count", 1)):
		return false
	if req.has("devices"):
		for id in req.devices:
			if device_count(id) < int(req.devices[id]):
				return false
	if req.has("upgrade") and not has_upgrade(req.upgrade):
		return false
	if req.has("total_wumms") and total_wumms < float(req.total_wumms):
		return false
	if req.has("achievements") and achievement_count() < int(req.achievements):
		return false
	if req.has("golden_shoes") and stat("golden_shoes") < float(req.golden_shoes):
		return false
	return true


## Sichtbar, sobald die Voraussetzung erfüllt ist und man 50 % des Preises hat (oder schon einmal sichtbar war).
func is_upgrade_visible(u: Dictionary) -> bool:
	if has_upgrade(u.id) or not upgrade_requirement_met(u):
		return false
	if revealed_upgrades.has(u.id):
		return true
	if wumms >= float(u.cost) * 0.5:
		revealed_upgrades[u.id] = true
		return true
	return false


func visible_upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in upgrade_defs:
		if is_upgrade_visible(u):
			out.append(u)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cost) < float(b.cost))
	return out


func buy_upgrade(id: String) -> bool:
	var u := upgrade_def(id)
	if u.is_empty() or has_upgrade(id) or not upgrade_requirement_met(u):
		return false
	if wumms < float(u.cost):
		return false
	wumms -= float(u.cost)
	upgrades[id] = true
	upgrade_bought.emit(id)
	return true


## Lesbare Wirkung eines Upgrades für Tooltips.
func upgrade_effect_text(u: Dictionary) -> String:
	var e: Dictionary = u.effect
	match e.type:
		"click_mult":
			return "Klick-Wert ×%s" % Num.fmt(float(e.factor))
		"device_mult":
			return "%s produziert ×%s" % [_device_name(e.device), Num.fmt(float(e.factor))]
		"wps_mult":
			return "Alle Geräte +%d %%" % roundi((float(e.factor) - 1.0) * 100.0)
		"click_wps":
			return "Jeder Klick bringt zusätzlich %s %% deiner WPS" % Num.fmt(float(e.percent) * 100.0)
		"crit":
			return "%d %% Chance auf ×%s-Treffer" % [roundi(float(e.chance) * 100.0), Num.fmt(float(e.factor))]
		"autofire":
			return "Maus gedrückt halten schlägt %d× pro Sekunde" % int(e.rate)
		"synergy":
			return "%s: +%d %% je %d %s" % [_device_name(e.target), roundi(float(e.percent) * 100.0),
				int(e.per), _device_name(e.source)]
		"achievement_wps":
			return "Alle Geräte +%s %% pro Erfolg (aktuell %d Erfolge)" % [
				Num.fmt(float(e.percent) * 100.0), achievement_count()]
		"fanclub":
			return "Alle Geräte +%d %% je %d Erfolge" % [roundi(float(e.percent) * 100.0), int(e.per)]
		"golden_luck":
			return "Goldene Schuhe und Silberne Pantoffel erscheinen %d %% häufiger" % roundi((float(e.factor) - 1.0) * 100.0)
	return ""


func _device_name(id: String) -> String:
	return String(device_def(id).get("name", id))


# =====================================================================
# Erfolge (Achievements)
# =====================================================================

## Fortschritt einer Bedingung als Vector2(aktuell, ziel).
func condition_progress(cond: Dictionary) -> Vector2:
	var target := float(cond.get("value", 1))
	match cond.type:
		"hits":
			return Vector2(total_hits, target)
		"total_wumms":
			return Vector2(total_wumms, target)
		"wps":
			return Vector2(base_wps(), target)
		"device":
			return Vector2(device_count(cond.device), target)
		"devices_total":
			return Vector2(devices_total(), target)
		"device_types":
			return Vector2(device_types_owned(), target)
		"upgrades":
			return Vector2(upgrades.size(), target)
		"stat":
			return Vector2(stat(cond.stat), target)
		"target_hits":
			return Vector2(int(target_hits.get(cond.target, 0)), target)
		"idle":
			return Vector2(idle_time, target)
		"night":
			var hour := int(Time.get_time_dict_from_system().hour)
			return Vector2(1.0 if hour >= 2 and hour < 4 else 0.0, 1.0)
	return Vector2(0.0, 1.0)


func achievement_met(a: Dictionary) -> bool:
	var p := condition_progress(a.condition)
	return p.x >= p.y


func check_achievements() -> void:
	for a in achievement_defs:
		if not achievements.has(a.id) and achievement_met(a):
			unlock_achievement(a.id)


func unlock_achievement(id: String) -> void:
	if achievements.has(id) or achievement_def(id).is_empty():
		return
	achievements[id] = true
	achievement_unlocked.emit(id)


# =====================================================================
# Zielbild
# =====================================================================

func target_name() -> String:
	if target_id == DEFAULT_TARGET:
		return DEFAULT_TARGET_NAME
	return String(target_names.get(target_id, "Unbekanntes Opfer"))


func current_target_hits() -> int:
	return int(target_hits.get(target_id, 0))


func target_texture() -> Texture2D:
	if target_id != DEFAULT_TARGET:
		var img := Image.load_from_file(_image_path(target_id))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		push_warning("Bild %s fehlt, nehme Standardfigur." % target_id)
		target_id = DEFAULT_TARGET
	return load(DEFAULT_TEXTURE_PATH) as Texture2D


func use_default_target() -> void:
	target_id = DEFAULT_TARGET
	target_changed.emit()


## Übernimmt ein Bild als neues Ziel: verkleinert es auf max. 1024 px und speichert eine Kopie lokal.
func import_image(img: Image, display_name: String) -> bool:
	if img == null or img.is_empty():
		return false
	var copy := img.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	var w := copy.get_width()
	var h := copy.get_height()
	var longest := maxi(w, h)
	if longest > MAX_IMAGE_EDGE:
		var s := float(MAX_IMAGE_EDGE) / float(longest)
		copy.resize(maxi(1, roundi(w * s)), maxi(1, roundi(h * s)), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(IMAGE_DIR)
	var id := "img_%d_%d" % [int(Time.get_unix_time_from_system()), _rng.randi() % 100000]
	if copy.save_png(_image_path(id)) != OK:
		push_error("Bild konnte nicht gespeichert werden.")
		return false
	target_id = id
	target_names[id] = display_name if display_name != "" else "Neues Opfer"
	add_stat("images_imported")
	target_changed.emit()
	save_game()
	return true


func import_image_file(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return false
	return import_image(img, path.get_file().get_basename())


func _image_path(id: String) -> String:
	return "%s/%s.png" % [IMAGE_DIR, id]


# =====================================================================
# Offline-Fortschritt
# =====================================================================

## Schreibt Offline-Ertrag gut und merkt ihn für den Willkommen-zurück-Bildschirm vor.
func apply_offline_progress(seconds: float) -> float:
	pending_offline = {}
	if seconds < OFFLINE_MIN_SECONDS:
		return 0.0
	if seconds >= 86400.0:
		stats["long_return"] = 1
	var gain := Balance.offline_gain(base_wps(), seconds, OFFLINE_RATE, OFFLINE_CAP)
	earn(gain)
	pending_offline = {"seconds": seconds, "gain": gain}
	return gain


func _apply_offline_since_save() -> void:
	var saved_at := float(_last_loaded.get("saved_at", 0.0))
	if saved_at <= 0.0:
		return
	apply_offline_progress(Time.get_unix_time_from_system() - saved_at)


# =====================================================================
# Speichern und Laden
# =====================================================================

var _last_loaded: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"wumms": wumms,
		"total_wumms": total_wumms,
		"total_hits": total_hits,
		"beulen_marken": beulen_marken,
		"devices": devices.duplicate(),
		"upgrades": upgrades.keys(),
		"revealed_upgrades": revealed_upgrades.keys(),
		"achievements": achievements.keys(),
		"stats": stats.duplicate(),
		"target_id": target_id,
		"target_names": target_names.duplicate(),
		"target_hits": target_hits.duplicate(),
		"settings": {"reduced_effects": reduced_effects, "sound_on": sound_on},
	}


func from_dict(data: Dictionary) -> void:
	data = _migrate(data)
	_last_loaded = data
	wumms = float(data.get("wumms", 0.0))
	total_wumms = float(data.get("total_wumms", 0.0))
	total_hits = int(data.get("total_hits", 0))
	beulen_marken = int(data.get("beulen_marken", 0))
	devices.clear()
	var saved_devices: Dictionary = data.get("devices", {})
	for id in saved_devices:
		devices[id] = int(saved_devices[id])
	upgrades = _key_set(data.get("upgrades", []))
	revealed_upgrades = _key_set(data.get("revealed_upgrades", []))
	achievements = _key_set(data.get("achievements", []))
	_reset_stats()
	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		stats[key] = float(saved_stats[key]) if key == "play_time" else int(saved_stats[key])
	target_id = String(data.get("target_id", DEFAULT_TARGET))
	target_names = data.get("target_names", {})
	target_hits.clear()
	var saved_hits: Dictionary = data.get("target_hits", {})
	for id in saved_hits:
		target_hits[id] = int(saved_hits[id])
	var settings: Dictionary = data.get("settings", {})
	reduced_effects = bool(settings.get("reduced_effects", false))
	sound_on = bool(settings.get("sound_on", true))
	buffs.clear()
	idle_time = 0.0


func _key_set(list: Array) -> Dictionary:
	var out := {}
	for id in list:
		out[String(id)] = true
	return out


## Ältere Spielstände auf die aktuelle Version bringen.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 1))
	if version < 2:
		# v1 → v2: Erfolge, Statistiken und Beulen-Marken sind neu. Erfolge werden beim
		# nächsten Check rückwirkend vergeben.
		data["achievements"] = data.get("achievements", [])
		data["stats"] = data.get("stats", {})
		data["beulen_marken"] = data.get("beulen_marken", 0)
	data["version"] = maxi(version, SAVE_VERSION)
	return data


func save_game() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


func load_game() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			from_dict(parsed)
			return true
		push_warning("Spielstand %s ist beschädigt, versuche Backup." % path)
	return false


## Spielstand als Textcode (Base64) zum Sichern oder Übertragen.
func export_save_code() -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(to_dict()))


## Lädt einen Textcode. Gibt false zurück, wenn der Code ungültig ist.
func import_save_code(code: String) -> bool:
	code = code.strip_edges()
	var b64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if code.length() < 8 or code.length() % 4 != 0 or b64.search(code) == null:
		return false
	var json := JSON.new()
	if json.parse(Marshalls.base64_to_utf8(code)) != OK:
		return false
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not parsed.has("version"):
		return false
	from_dict(parsed)
	reset_shoe_timers()
	save_game()
	target_changed.emit()
	return true


## Setzt den Spielstand komplett zurück (Bilder bleiben erhalten).
func reset_progress() -> void:
	var names := target_names.duplicate()
	var keep_settings := {"reduced_effects": reduced_effects, "sound_on": sound_on}
	from_dict({"version": SAVE_VERSION, "settings": keep_settings})
	target_names = names
	reset_shoe_timers()
	save_game()
	target_changed.emit()
