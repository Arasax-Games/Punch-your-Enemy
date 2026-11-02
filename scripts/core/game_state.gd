extends Node
## Zentraler Spielzustand (Autoload "GameState").
## Hält Währung, Geräte, Upgrades und Zielbilder und kümmert sich ums Speichern.
## Die UI liest den Zustand regelmäßig aus; Signale gibt es nur für strukturelle Änderungen.

signal device_bought(id: String, amount: int)
signal device_sold(id: String)
signal upgrade_bought(id: String)
signal target_changed

const SAVE_VERSION := 1
const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"
const IMAGE_DIR := "user://images"
const MAX_IMAGE_EDGE := 1024
const AUTOSAVE_INTERVAL := 30.0
const DEFAULT_TARGET := "bombastus"
const DEFAULT_TARGET_NAME := "Generalissimo Bombastus von Größenwahn"
const DEFAULT_TEXTURE_PATH := "res://assets/figures/bombastus.svg"
const DEVICES_PATH := "res://data/devices.json"
const UPGRADES_PATH := "res://data/upgrades.json"

# --- Daten (aus JSON) ---
var device_defs: Array[Dictionary] = []
var upgrade_defs: Array[Dictionary] = []
var _device_by_id: Dictionary = {}
var _upgrade_by_id: Dictionary = {}

# --- Spielstand ---
var wumms: float = 0.0
var total_wumms: float = 0.0
var total_hits: int = 0
var devices: Dictionary = {}            # id -> Anzahl
var upgrades: Dictionary = {}           # id -> true
var revealed_upgrades: Dictionary = {}  # id -> true (einmal sichtbar = bleibt sichtbar)
var target_id: String = DEFAULT_TARGET
var target_names: Dictionary = {}       # target_id -> Anzeigename
var target_hits: Dictionary = {}        # target_id -> Treffer
var reduced_effects: bool = false
var sound_on: bool = true

var _autosave_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_data()
	load_game()


func _process(delta: float) -> void:
	tick(delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# =====================================================================
# Daten laden
# =====================================================================

func load_data() -> void:
	device_defs.clear()
	upgrade_defs.clear()
	for d in _read_json_array(DEVICES_PATH):
		device_defs.append(d)
	for u in _read_json_array(UPGRADES_PATH):
		upgrade_defs.append(u)
	_device_by_id.clear()
	for d in device_defs:
		_device_by_id[d.id] = d
	_upgrade_by_id.clear()
	for u in upgrade_defs:
		_upgrade_by_id[u.id] = u


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


# =====================================================================
# Produktion und Klicks
# =====================================================================

func tick(delta: float) -> void:
	earn(wps() * delta)


func earn(amount: float) -> void:
	if amount <= 0.0:
		return
	wumms += amount
	total_wumms += amount


func device_count(id: String) -> int:
	return int(devices.get(id, 0))


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func _owned_effects(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in upgrade_defs:
		if has_upgrade(u.id) and u.effect.type == type:
			out.append(u.effect)
	return out


func device_multiplier(id: String) -> float:
	var m := 1.0
	for e in _owned_effects("device_mult"):
		if e.device == id:
			m *= float(e.factor)
	return m


func global_multiplier() -> float:
	var m := 1.0
	for e in _owned_effects("wps_mult"):
		m *= float(e.factor)
	return m


## Produktion eines einzelnen Geräts dieses Typs pro Sekunde.
func device_unit_wps(id: String) -> float:
	var d := device_def(id)
	if d.is_empty():
		return 0.0
	return float(d.base_wps) * device_multiplier(id) * global_multiplier()


func device_total_wps(id: String) -> float:
	return device_unit_wps(id) * device_count(id)


func wps() -> float:
	var total := 0.0
	for d in device_defs:
		total += device_total_wps(d.id)
	return total


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
	return 1.0 * click_multiplier() + wps() * click_wps_percent()


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


## Ein Treffer auf das Zielbild. Gibt {"value": float, "crit": bool} zurück.
func hit() -> Dictionary:
	var value := click_value()
	var crit := crit_chance() > 0.0 and _rng.randf() < crit_chance()
	if crit:
		value *= crit_factor()
	earn(value)
	total_hits += 1
	target_hits[target_id] = int(target_hits.get(target_id, 0)) + 1
	return {"value": value, "crit": crit}


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
	if req.has("upgrade") and not has_upgrade(req.upgrade):
		return false
	if req.has("total_wumms") and total_wumms < float(req.total_wumms):
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
			return "%s produziert ×%s" % [device_def(e.device).get("name", e.device), Num.fmt(float(e.factor))]
		"wps_mult":
			return "Alle Geräte +%d %%" % roundi((float(e.factor) - 1.0) * 100.0)
		"click_wps":
			return "Jeder Klick bringt zusätzlich %s %% deiner WPS" % Num.fmt(float(e.percent) * 100.0)
		"crit":
			return "%d %% Chance auf ×%s-Treffer" % [roundi(float(e.chance) * 100.0), Num.fmt(float(e.factor))]
		"autofire":
			return "Maus gedrückt halten schlägt %d× pro Sekunde" % int(e.rate)
	return ""


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
# Speichern und Laden
# =====================================================================

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"wumms": wumms,
		"total_wumms": total_wumms,
		"total_hits": total_hits,
		"devices": devices.duplicate(),
		"upgrades": upgrades.keys(),
		"revealed_upgrades": revealed_upgrades.keys(),
		"target_id": target_id,
		"target_names": target_names.duplicate(),
		"target_hits": target_hits.duplicate(),
		"settings": {"reduced_effects": reduced_effects, "sound_on": sound_on},
	}


func from_dict(data: Dictionary) -> void:
	data = _migrate(data)
	wumms = float(data.get("wumms", 0.0))
	total_wumms = float(data.get("total_wumms", 0.0))
	total_hits = int(data.get("total_hits", 0))
	devices.clear()
	var saved_devices: Dictionary = data.get("devices", {})
	for id in saved_devices:
		devices[id] = int(saved_devices[id])
	upgrades.clear()
	for id in data.get("upgrades", []):
		upgrades[String(id)] = true
	revealed_upgrades.clear()
	for id in data.get("revealed_upgrades", []):
		revealed_upgrades[String(id)] = true
	target_id = String(data.get("target_id", DEFAULT_TARGET))
	target_names = data.get("target_names", {})
	target_hits.clear()
	var saved_hits: Dictionary = data.get("target_hits", {})
	for id in saved_hits:
		target_hits[id] = int(saved_hits[id])
	var settings: Dictionary = data.get("settings", {})
	reduced_effects = bool(settings.get("reduced_effects", false))
	sound_on = bool(settings.get("sound_on", true))


## Ältere Spielstände auf die aktuelle Version bringen.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 1))
	# if version < 2: ... (künftige Migrationen hier ergänzen)
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


## Setzt den Spielstand komplett zurück (Bilder bleiben erhalten).
func reset_progress() -> void:
	var names := target_names.duplicate()
	var keep_settings := {"reduced_effects": reduced_effects, "sound_on": sound_on}
	from_dict({"settings": keep_settings})
	target_names = names
	save_game()
	target_changed.emit()
