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
signal prestiged(gain: int)
signal rage_changed(active: bool)
signal bump_level_up(target: String, level: int)
signal laurel_node_bought(id: String)
signal boss_started
signal boss_finished(won: bool, reward: Dictionary)
signal quests_changed
signal event_completed(event: Dictionary)
signal challenge_changed
signal cosmetics_changed
signal minigame_finished(game: String, score: int)

const SAVE_VERSION := 5
const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"
const IMAGE_DIR := "user://images"
const MAX_IMAGE_EDGE := 1024
const AUTOSAVE_INTERVAL := 30.0
const ACHIEVEMENT_CHECK_INTERVAL := 0.5
const DEFAULT_TARGET := "bombastus"
# i18n
const DEFAULT_TARGET_NAME := "Generalissimo Bombastus von Größenwahn"
const DEFAULT_TEXTURE_PATH := "res://assets/figures/bombastus.svg"
const DEVICES_PATH := "res://data/devices.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const LAURELS_PATH := "res://data/laurels.json"
const FIGURES_PATH := "res://data/figures.json"
const CUSTOM_FIGURE := "_custom"
const BOSSES_PATH := "res://data/bosses.json"
const QUESTS_PATH := "res://data/quests.json"
const EVENTS_PATH := "res://data/events.json"
const COSMETICS_PATH := "res://data/cosmetics.json"
const CHALLENGES_PATH := "res://data/challenges.json"
const MARKET_PATH := "res://data/market.json"
const SLOW_MOTION_SCALE := 0.4
const LANGUAGES := {"de": "Deutsch", "en": "English"}
## Datenfelder, die beim Laden übersetzt werden (Quelltext Deutsch = msgid in locale/*.po).
## Pokalnamen werden bewusst erst bei der Anzeige übersetzt, weil sie im Spielstand stehen.
const LOCALIZED_FIELDS: Array[String] = ["name", "description", "text", "intro"]
const QUESTS_PER_DAY := 3
const DAY_CHECK_INTERVAL := 5.0
const MAX_STATS: Array[String] = ["max_combo", "best_streak", "dojo_best", "pie_best"]
# i18n
const MINIGAMES := {
	"dojo": {"name": "Reaktions-Dojo", "points_per_marke": 8, "stat": "dojo_best"},
	"pie": {"name": "Tortenwurf-Schießbude", "points_per_marke": 12, "stat": "pie_best"},
}

const SHOE_GOLDEN := "golden"
const SHOE_SILVER := "silver"
const GOLDEN_LIFETIME := 13.0
const SILVER_LIFETIME := 8.0
const OFFLINE_RATE := 0.5
const OFFLINE_CAP := 8.0 * 3600.0
const OFFLINE_MIN_SECONDS := 60.0
const CHAIN_MAX := 7
const COMBO_MAX := 100.0
const COMBO_STEP := 2.0
const COMBO_GRACE := 2.0
const COMBO_DECAY := 40.0
const RAGE_MAX := 150.0
const RAGE_DURATION := 10.0
const RAGE_MULT := 3.0
const AUTOBUY_INTERVAL := 1.0
const TIME_WARP_FACTOR := 2.0

const STAT_KEYS: Array[String] = [
	"crits", "golden_shoes", "silver_slippers", "frenzies", "bad_luck",
	"images_imported", "play_time", "showers", "devices_sold", "long_return",
	"prestiges", "rages", "max_combo", "renames",
	"bosses_defeated", "quests_done", "best_streak", "dojo_best", "pie_best", "events_done", "screenshots",
	"devices_bought", "upgrades_bought", "combo_maxed", "minigames_played",
	"challenges_done", "market_wins", "cosmetics_bought",
]

# --- Daten (aus JSON) ---
var device_defs: Array[Dictionary] = []
var upgrade_defs: Array[Dictionary] = []
var achievement_defs: Array[Dictionary] = []
var laurel_defs: Array[Dictionary] = []
var figure_defs: Array[Dictionary] = []
var boss_config: Dictionary = {}
var quest_defs: Array[Dictionary] = []
var event_defs: Array[Dictionary] = []
var cosmetic_defs: Array[Dictionary] = []
var challenge_defs: Array[Dictionary] = []
var market_config: Dictionary = {}
var _device_by_id: Dictionary = {}
var _upgrade_by_id: Dictionary = {}
var _achievement_by_id: Dictionary = {}
var _laurel_by_id: Dictionary = {}
var _figure_by_id: Dictionary = {}

# --- Spielstand ---
var wumms: float = 0.0
var total_wumms: float = 0.0            # in diesem Durchlauf (seit dem letzten Neuanfang)
var lifetime_wumms: float = 0.0         # über alle Durchläufe
var laurels_total: int = 0              # je Lorbeer +1 % WPS und Klick, bleibt beim Ausgeben erhalten
var laurels_spent: int = 0
var laurel_nodes: Dictionary = {}       # id -> true
var next_boss_at: int = 100000          # bei so vielen Treffern insgesamt kommt der nächste Boss
var trophies: Array = []                # Namen gewonnener Pokale (Bosse, Events)
var quests_day: String = ""
var quests: Array = []                  # [{id, amount, reward, start, claimed}]
var login_streak: int = 0
var last_login_day: String = ""
var event_progress: Dictionary = {}     # "halloween-2026" -> Treffer
var events_done: Dictionary = {}        # "halloween-2026" -> true
var minigame_day: String = ""
var minigame_rewards_today: Dictionary = {}  # Spiel -> heute schon ausgezahlte Marken
var owned_cosmetics: Dictionary = {}    # Laden-Käufe: id -> true
var laurels_extra: int = 0              # Lorbeeren aus Herausforderungen (zählen nicht für den Neuanfang)
var challenge_active: String = ""
var challenges_done: Dictionary = {}    # id -> true
var market_factors: Dictionary = {}     # Ware -> Kursfaktor (0,3 … 3)
var market_holdings: Dictionary = {}    # Ware -> Stück
var market_paid: Dictionary = {}        # Ware -> insgesamt bezahlt (für den Einkaufsschnitt)
var market_scale: float = 1.0           # höchste WPS in diesem Durchlauf – Basis der Börsenpreise
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
var autobuy_enabled: bool = true
var time_warp: bool = false
var background: String = "standard"
var fist_skin: String = "standard"
var sound_pack: String = "standard"
var language: String = ""               # "" = Systemsprache, sonst "de" oder "en"
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var ambient_volume: float = 0.8

# --- Laufzeit (wird nicht gespeichert) ---
var buffs: Array = []       # {id, name, remaining, duration, wps_mult, click_mult}
var idle_time: float = 0.0              # Sekunden seit dem letzten Treffer (diese Sitzung)
var pending_offline: Dictionary = {}    # {seconds, gain} für den Willkommen-zurück-Bildschirm
var _shoe_timers: Dictionary = {}       # kind -> Sekunden bis zum Erscheinen
var _shoe_active: Dictionary = {}       # kind -> true, solange ein Schuh sichtbar ist
var _chain_count: int = 0
var combo: float = 0.0
var rage_meter: float = 0.0
var rage_time: float = 0.0
var _autobuy_timer: float = 0.0
var boss_active: bool = false
var boss_hp: float = 0.0
var boss_max_hp: float = 0.0
var boss_time: float = 0.0
var boss_gimmick: Dictionary = {}
var pending_login: Dictionary = {}      # Login-Belohnung für den Willkommens-Dialog
var _day_timer: float = 0.0
var _today_override: String = ""        # nur für Tests
var _market_timer: float = 0.0
var _autosave_timer: float = 0.0
## false in Tests und Simulationen, damit der echte Spielstand nie überschrieben wird.
var persist: bool = true
var _achievement_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_data()
	_reset_stats()
	_migrate_user_dir()
	var loaded := load_game()
	set_language(language)
	if loaded:
		_apply_offline_since_save()
	reset_shoe_timers()
	check_new_day()


func _process(delta: float) -> void:
	# In der Zeitlupe läuft die Darstellung langsamer, die Spiellogik aber in Echtzeit weiter.
	delta /= maxf(Engine.time_scale, 0.01)
	tick(delta)
	_update_shoes(delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()
	_day_timer += delta
	if _day_timer >= DAY_CHECK_INTERVAL:
		_day_timer = 0.0
		check_new_day()
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
	laurel_defs.clear()
	for n in _read_json_array(LAURELS_PATH):
		laurel_defs.append(n)
	figure_defs.clear()
	for f in _read_json_array(FIGURES_PATH):
		figure_defs.append(f)
	_device_by_id.clear()
	for d in device_defs:
		_device_by_id[d.id] = d
	_upgrade_by_id.clear()
	for u in upgrade_defs:
		_upgrade_by_id[u.id] = u
	_achievement_by_id.clear()
	for a in achievement_defs:
		_achievement_by_id[a.id] = a
	_laurel_by_id.clear()
	for n in laurel_defs:
		_laurel_by_id[n.id] = n
	_figure_by_id.clear()
	for f in figure_defs:
		_figure_by_id[f.id] = f
	var bosses: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSSES_PATH))
	boss_config = bosses if bosses is Dictionary else {}
	quest_defs.clear()
	for q in _read_json_array(QUESTS_PATH):
		quest_defs.append(q)
	event_defs.clear()
	for e in _read_json_array(EVENTS_PATH):
		event_defs.append(e)
	cosmetic_defs.clear()
	for c in _read_json_array(COSMETICS_PATH):
		cosmetic_defs.append(c)
	challenge_defs.clear()
	for c in _read_json_array(CHALLENGES_PATH):
		challenge_defs.append(c)
	var market: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKET_PATH))
	market_config = market if market is Dictionary else {}
	_localize_data()


## Übersetzt die Anzeigetexte aller Daten in die aktuelle Sprache.
func _localize_data() -> void:
	var lists: Array = [device_defs, upgrade_defs, achievement_defs, laurel_defs, figure_defs, quest_defs,
		event_defs, cosmetic_defs, challenge_defs, boss_config.get("gimmicks", []), market_config.get("goods", [])]
	for list in lists:
		for entry in list:
			for field in LOCALIZED_FIELDS:
				if entry.has(field) and entry[field] is String:
					entry[field] = tr(entry[field])


## Sprache setzen ("" = Systemsprache) und alle Daten neu laden.
func set_language(lang: String) -> void:
	language = lang
	TranslationServer.set_locale(effective_language())
	load_data()


func effective_language() -> String:
	if LANGUAGES.has(language):
		return language
	return "de" if OS.get_locale_language() == "de" else "en"


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


func laurel_def(id: String) -> Dictionary:
	return _laurel_by_id.get(id, {})


func figure_def(id: String) -> Dictionary:
	return _figure_by_id.get(id, _figure_by_id.get(CUSTOM_FIGURE, {}))


func _reset_stats() -> void:
	stats.clear()
	for key in STAT_KEYS:
		stats[key] = 0.0 if key == "play_time" else 0


func stat(key: String) -> float:
	return float(stats.get(key, 0))


func add_stat(key: String, amount: float = 1.0) -> void:
	if key in MAX_STATS:
		stats[key] = maxi(int(stats.get(key, 0)), int(amount))
	elif key == "play_time":
		stats[key] = stat(key) + amount
	else:
		stats[key] = int(stats.get(key, 0)) + int(amount)


# =====================================================================
# Produktion und Klicks
# =====================================================================

func tick(delta: float) -> void:
	var production_delta := delta * (TIME_WARP_FACTOR if time_warp_active() else 1.0)
	earn(wps() * production_delta)
	add_stat("play_time", delta)
	idle_time += delta
	_update_buffs(delta)
	_update_combo(delta)
	_update_rage(delta)
	_update_autobuy(delta)
	_update_boss(delta)
	_update_challenge()
	_update_market(delta)


func earn(amount: float) -> void:
	if amount <= 0.0:
		return
	wumms += amount
	total_wumms += amount
	lifetime_wumms += amount


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
	return m * Balance.laurel_bonus(laurels_total)


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
	return base_wps() * buff_wps_multiplier() * rage_multiplier()


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


## Klick-Wert ohne Combo (z. B. für die Anzeige "pro Klick" und die Simulation).
func base_click_value() -> float:
	return (1.0 * click_multiplier() * Balance.laurel_bonus(laurels_total) + wps() * click_wps_percent()) \
		* buff_click_multiplier() * rage_multiplier()


func click_value() -> float:
	return base_click_value() * Balance.combo_multiplier(combo)


func crit_chance() -> float:
	var c := 0.0
	for e in _owned_effects("crit"):
		c += float(e.chance)
	for e in _laurel_effects("crit_chance"):
		c += float(e.chance)
	return c


func crit_factor() -> float:
	var f := 10.0 if not _laurel_effects("crit_chance").is_empty() else 1.0
	for e in _owned_effects("crit"):
		f = maxf(f, float(e.factor))
	return f


func has_autofire() -> bool:
	return autofire_rate() > 0.0


func autofire_rate() -> float:
	var r := 0.0
	for e in _owned_effects("autofire") + _laurel_effects("autofire"):
		r = maxf(r, float(e.rate))
	return r


func golden_luck() -> float:
	var l := 1.0
	for e in _owned_effects("golden_luck") + _laurel_effects("golden_luck"):
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
	var combo_before := combo
	combo = minf(COMBO_MAX, combo + COMBO_STEP)
	add_stat("max_combo", combo)
	if combo >= COMBO_MAX and combo_before < COMBO_MAX:
		add_stat("combo_maxed")
	if not rage_active():
		rage_meter = minf(RAGE_MAX, rage_meter + 1.0)
	var level_before := current_bump_level()
	target_hits[target_id] = int(target_hits.get(target_id, 0)) + 1
	var level_after := current_bump_level()
	if level_after > level_before:
		beulen_marken += 1
		bump_level_up.emit(target_id, level_after)
	_count_event_hit()
	_check_boss_start()
	return {"value": value, "crit": crit}


# =====================================================================
# Combo und Wutmodus
# =====================================================================

func _update_combo(delta: float) -> void:
	if combo > 0.0 and idle_time > COMBO_GRACE:
		combo = maxf(0.0, combo - COMBO_DECAY * delta)


func rage_active() -> bool:
	return rage_time > 0.0


func rage_ready() -> bool:
	return not rage_active() and rage_meter >= RAGE_MAX


func rage_multiplier() -> float:
	return RAGE_MULT if rage_active() else 1.0


## Entfesselt den Wutmodus, wenn die Leiste voll ist: 10 s lang alles ×3, aber keine Goldenen Schuhe.
func start_rage() -> bool:
	if not rage_ready():
		return false
	rage_time = RAGE_DURATION
	rage_meter = 0.0
	add_stat("rages")
	rage_changed.emit(true)
	return true


func _update_rage(delta: float) -> void:
	if rage_time <= 0.0:
		return
	rage_time -= delta
	if rage_time <= 0.0:
		rage_time = 0.0
		rage_changed.emit(false)


func time_warp_unlocked() -> bool:
	return stat("prestiges") > 0


func time_warp_active() -> bool:
	return time_warp and time_warp_unlocked()


# =====================================================================
# Buffs (Raserei & Co.)
# =====================================================================

func add_buff(id: String, buff_name: String, duration: float, wps_mult: float = 1.0, click_mult: float = 1.0) -> void:
	if wps_mult >= 1.0 and click_mult >= 1.0:
		for e in _laurel_effects("buff_duration"):
			duration *= float(e.factor)
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
	if rage_active():
		return
	for kind in [SHOE_GOLDEN, SHOE_SILVER]:
		if _shoe_active.get(kind, false):
			continue
		_shoe_timers[kind] = float(_shoe_timers.get(kind, 300.0)) - delta
		if _shoe_timers[kind] <= 0.0:
			_shoe_active[kind] = true
			shoe_spawned.emit(kind)


func shoe_lifetime(kind: String) -> float:
	var life := GOLDEN_LIFETIME if kind == SHOE_GOLDEN else SILVER_LIFETIME
	for e in _laurel_effects("shoe_lifetime"):
		life *= float(e.factor)
	return life


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
		add_buff("pech", tr("Pech-Schuh"), 66.0, 0.5)
		result = {"title": tr("Pech-Schuh!"), "text": tr("Halbe WPS für 66 s. Trostpreis: 3 Beulen-Marken."), "good": false}
	elif roll < 0.50:
		var gain := Balance.blessing(wps(), wumms, 15.0, 0.15, 13.0)
		earn(gain)
		result = {"title": tr("Wumms-Segen!"), "text": tr("+%s Wumms") % Num.whole(gain), "good": true}
	elif roll < 0.80:
		add_stat("frenzies")
		add_buff("raserei", tr("Raserei"), 77.0, 7.0)
		result = {"title": tr("Raserei!"), "text": tr("Alle Geräte ×7 für 77 s."), "good": true}
	elif roll < 0.92:
		add_stat("frenzies")
		add_buff("klick_raserei", tr("Klick-Raserei"), 13.0, 1.0, 777.0)
		result = {"title": tr("Klick-Raserei!"), "text": tr("Klick-Wert ×777 für 13 s. Hau drauf!"), "good": true}
	elif roll >= 0.97:
		add_buff("zeitlupe", tr("Zeitlupe"), 10.0, 1.0, 3.0)
		result = {"title": tr("Zeitlupe!"), "text": tr("Alles ganz langsam … und jeder Klick zählt dreifach."), "good": true}
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
	var text := tr("Glied %d: +%s Wumms") % [_chain_count, Num.whole(gain)]
	if _chain_count < CHAIN_MAX and _rng.randf() < 0.75:
		_shoe_timers[SHOE_GOLDEN] = 1.2
		text += tr(" … da kommt noch einer!")
	else:
		text += tr(" Die Kette ist gerissen.")
		_chain_count = 0
		_restart_shoe_timer(SHOE_GOLDEN)
	return {"title": tr("Kettenreaktion!"), "text": text, "good": true}


func _silver_effect(roll: float) -> Dictionary:
	if roll < 0.7:
		var gain := Balance.blessing(wps(), wumms, 1.0, 0.05, 7.0)
		earn(gain)
		return {"title": tr("Silberner Pantoffel!"), "text": tr("+%s Wumms") % Num.whole(gain), "good": true}
	add_buff("mini_raserei", tr("Kleine Raserei"), 30.0, 2.0)
	return {"title": tr("Silberner Pantoffel!"), "text": tr("Alle Geräte ×2 für 30 s."), "good": true}


# =====================================================================
# Geräte kaufen und verkaufen
# =====================================================================

## Wie viele Geräte bei der gewählten Kaufmenge gekauft würden (-1 = Max).
func amount_for_mode(id: String, mode: int) -> int:
	if mode > 0:
		return mode
	return Balance.max_affordable(device_base_cost(id), device_count(id), wumms)


## Grundpreis eines Geräts inklusive Rabatten aus dem Lorbeer-Baum.
func device_base_cost(id: String) -> float:
	var d := device_def(id)
	if d.is_empty():
		return INF
	return float(d.base_cost) * device_cost_factor()


func device_cost_factor() -> float:
	var f := 1.0
	for e in _laurel_effects("device_cost"):
		f *= float(e.factor)
	return f * float(challenge_rules().get("device_cost_mult", 1.0))


func device_cost(id: String, amount: int) -> float:
	if device_def(id).is_empty():
		return INF
	return Balance.bulk_cost(device_base_cost(id), device_count(id), maxi(amount, 1))


func buy_device(id: String, amount: int) -> bool:
	if amount <= 0 or device_def(id).is_empty() or challenge_rules().get("no_devices", false):
		return false
	var cost := device_cost(id, amount)
	if wumms < cost:
		return false
	wumms -= cost
	devices[id] = device_count(id) + amount
	add_stat("devices_bought", amount)
	device_bought.emit(id, amount)
	return true


func sell_device(id: String) -> bool:
	var owned := device_count(id)
	if owned <= 0:
		return false
	wumms += Balance.sell_refund(device_base_cost(id), owned)
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
	if u.is_empty() or has_upgrade(id) or not upgrade_requirement_met(u) or challenge_rules().get("no_upgrades", false):
		return false
	if wumms < float(u.cost):
		return false
	wumms -= float(u.cost)
	upgrades[id] = true
	add_stat("upgrades_bought")
	upgrade_bought.emit(id)
	return true


## Lesbare Wirkung eines Upgrades für Tooltips.
func upgrade_effect_text(u: Dictionary) -> String:
	var e: Dictionary = u.effect
	match e.type:
		"click_mult":
			return tr("Klick-Wert ×%s") % Num.fmt(float(e.factor))
		"device_mult":
			return tr("%s produziert ×%s") % [_device_name(e.device), Num.fmt(float(e.factor))]
		"wps_mult":
			return tr("Alle Geräte +%d %%") % roundi((float(e.factor) - 1.0) * 100.0)
		"click_wps":
			return tr("Jeder Klick bringt zusätzlich %s %% deiner WPS") % Num.fmt(float(e.percent) * 100.0)
		"crit":
			return tr("%d %% Chance auf ×%s-Treffer") % [roundi(float(e.chance) * 100.0), Num.fmt(float(e.factor))]
		"autofire":
			return tr("Maus gedrückt halten schlägt %d× pro Sekunde") % int(e.rate)
		"synergy":
			return tr("%s: +%d %% je %d %s") % [_device_name(e.target), roundi(float(e.percent) * 100.0),
				int(e.per), _device_name(e.source)]
		"achievement_wps":
			return tr("Alle Geräte +%s %% pro Erfolg (aktuell %d Erfolge)") % [
				Num.fmt(float(e.percent) * 100.0), achievement_count()]
		"fanclub":
			return tr("Alle Geräte +%d %% je %d Erfolge") % [roundi(float(e.percent) * 100.0), int(e.per)]
		"golden_luck":
			return tr("Goldene Schuhe und Silberne Pantoffel erscheinen %d %% häufiger") % roundi((float(e.factor) - 1.0) * 100.0)
	return ""


func _device_name(id: String) -> String:
	return String(device_def(id).get("name", id))


# =====================================================================
# Neuanfang (Prestige) und Lorbeer-Baum
# =====================================================================

func prestige_gain() -> int:
	return Balance.laurel_gain(lifetime_wumms, laurels_total - laurels_extra)


func can_prestige() -> bool:
	return lifetime_wumms >= Balance.PRESTIGE_THRESHOLD and prestige_gain() >= 1


## Setzt den Durchlauf zurück und schreibt Lorbeeren gut. Erfolge, Statistiken, Bilder,
## Lorbeer-Baum und Beulen-Marken bleiben erhalten.
func perform_prestige() -> int:
	if not can_prestige():
		return 0
	var gain := prestige_gain()
	laurels_total += gain
	add_stat("prestiges")
	challenge_active = ""
	_reset_run()
	prestiged.emit(gain)
	save_game()
	return gain


## Setzt den laufenden Durchlauf zurück (Neuanfang, Herausforderung).
func _reset_run() -> void:
	wumms = 0.0
	total_wumms = 0.0
	devices.clear()
	upgrades.clear()
	revealed_upgrades.clear()
	buffs.clear()
	combo = 0.0
	rage_meter = 0.0
	rage_time = 0.0
	market_holdings.clear()
	market_paid.clear()
	market_scale = 1.0
	if not challenge_rules().get("no_devices", false):
		_apply_start_devices()
	reset_shoe_timers()


func _apply_start_devices() -> void:
	for e in _laurel_effects("start_devices"):
		for id in e.devices:
			devices[id] = device_count(id) + int(e.devices[id])


func laurels_available() -> int:
	return laurels_total - laurels_spent


func has_laurel_node(id: String) -> bool:
	return laurel_nodes.has(id)


func _laurel_effects(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in laurel_defs:
		if laurel_nodes.has(n.id) and n.effect.type == type:
			out.append(n.effect)
	return out


func laurel_requirements_met(n: Dictionary) -> bool:
	for req in n.get("requires", []):
		if not has_laurel_node(req):
			return false
	return true


func can_afford_laurel_node(n: Dictionary) -> bool:
	if n.get("currency", "laurels") == "marken":
		return beulen_marken >= int(n.cost)
	return laurels_available() >= int(n.cost)


func buy_laurel_node(id: String) -> bool:
	var n := laurel_def(id)
	if n.is_empty() or has_laurel_node(id) or not laurel_requirements_met(n) or not can_afford_laurel_node(n):
		return false
	if n.get("currency", "laurels") == "marken":
		beulen_marken -= int(n.cost)
	else:
		laurels_spent += int(n.cost)
	laurel_nodes[id] = true
	var e: Dictionary = n.effect
	if e.type == "start_devices" and stat("prestiges") > 0 and total_wumms <= 0.0:
		for dev in e.devices:
			devices[dev] = device_count(dev) + int(e.devices[dev])
	if e.type == "cosmetic":
		apply_cosmetic(String(e.id))
	laurel_node_bought.emit(id)
	return true


func laurel_tree_unlocked() -> bool:
	return laurels_total > 0 or beulen_marken > 0 or not laurel_nodes.is_empty()


func offline_rate() -> float:
	var r := OFFLINE_RATE
	for e in _laurel_effects("offline_rate") + _laurel_effects("offline_full"):
		r = maxf(r, float(e.rate))
	return r


func offline_cap() -> float:
	var hours := OFFLINE_CAP / 3600.0
	for e in _laurel_effects("offline_cap") + _laurel_effects("offline_full"):
		hours = maxf(hours, float(e.hours))
	return hours * 3600.0


func has_autobuy() -> bool:
	return not _laurel_effects("autobuy_upgrades").is_empty()


func _update_autobuy(delta: float) -> void:
	if not has_autobuy() or not autobuy_enabled:
		return
	_autobuy_timer += delta
	if _autobuy_timer < AUTOBUY_INTERVAL:
		return
	_autobuy_timer = 0.0
	for u in visible_upgrades():
		if wumms >= float(u.cost):
			buy_upgrade(u.id)
			return


## Lesbare Wirkung eines Lorbeer-Knotens.
func laurel_cost_text(n: Dictionary) -> String:
	var unit := tr("Beulen-Marken") if n.get("currency", "laurels") == "marken" else (tr("Lorbeer") if int(n.cost) == 1 else tr("Lorbeeren"))
	return "%d %s" % [int(n.cost), unit]


# --- Kosmetik ---

func cosmetic_def(id: String) -> Dictionary:
	for c in cosmetic_defs:
		if c.id == id:
			return c
	return {}


func has_cosmetic(id: String) -> bool:
	if owned_cosmetics.has(id) or cosmetic_def(id).get("source", "") == "default":
		return true
	for e in _laurel_effects("cosmetic"):
		if e.id == id:
			return true
	return false


func buy_cosmetic(id: String) -> bool:
	var c := cosmetic_def(id)
	if c.is_empty() or c.get("source", "") != "shop" or has_cosmetic(id) or beulen_marken < int(c.cost):
		return false
	beulen_marken -= int(c.cost)
	owned_cosmetics[id] = true
	add_stat("cosmetics_bought")
	apply_cosmetic(id)
	return true


## Angelegte Kosmetik, die man (nicht mehr) besitzt, auf Standard zurücksetzen.
func validate_cosmetics() -> void:
	for slot in ["fist", "background", "sound"]:
		var current: String = {"fist": fist_skin, "background": background, "sound": sound_pack}[slot]
		var ok := current == "standard"
		for c in cosmetic_defs:
			if c.slot == slot and c.value == current and has_cosmetic(c.id):
				ok = true
		if not ok:
			match slot:
				"fist":
					fist_skin = "standard"
				"background":
					background = "standard"
				"sound":
					sound_pack = "standard"


## Ist dieses Kosmetik-Teil gerade angelegt?
func cosmetic_equipped(id: String) -> bool:
	var c := cosmetic_def(id)
	match c.get("slot", ""):
		"fist":
			return fist_skin == c.value
		"background":
			return background == c.value
		"sound":
			return sound_pack == c.value
	return false


## Neu gekaufte Kosmetik direkt anlegen.
func apply_cosmetic(id: String) -> void:
	var c := cosmetic_def(id)
	if c.is_empty() or not has_cosmetic(id):
		return
	match c.slot:
		"fist":
			fist_skin = c.value
		"background":
			background = c.value
		"sound":
			sound_pack = c.value
	cosmetics_changed.emit()


func available_backgrounds() -> Array[String]:
	var out: Array[String] = []
	for c in cosmetic_defs:
		if c.slot == "background" and has_cosmetic(c.id):
			out.append(String(c.value))
	return out


# =====================================================================
# Herausforderungen
# =====================================================================

func challenge_def(id: String) -> Dictionary:
	for c in challenge_defs:
		if c.id == id:
			return c
	return {}


func challenge_rules() -> Dictionary:
	if challenge_active == "":
		return {}
	return challenge_def(challenge_active).get("rules", {})


func challenges_unlocked() -> bool:
	return stat("prestiges") > 0


## Startet eine Herausforderung: Der Durchlauf beginnt von vorn (ohne Lorbeeren), mit Einschränkungen.
func start_challenge(id: String) -> bool:
	var c := challenge_def(id)
	if c.is_empty() or not challenges_unlocked() or challenge_active != "" or challenges_done.has(id):
		return false
	challenge_active = id
	_reset_run()
	challenge_changed.emit()
	save_game()
	return true


func abort_challenge() -> void:
	if challenge_active == "":
		return
	challenge_active = ""
	challenge_changed.emit()


func challenge_progress() -> float:
	var c := challenge_def(challenge_active)
	if c.is_empty():
		return 0.0
	return clampf(total_wumms / float(c.goal_wumms), 0.0, 1.0)


func _update_challenge() -> void:
	if challenge_active == "":
		return
	var c := challenge_def(challenge_active)
	if c.is_empty() or total_wumms < float(c.goal_wumms):
		return
	var reward := int(c.reward_laurels)
	laurels_total += reward
	laurels_extra += reward
	challenges_done[challenge_active] = true
	add_stat("challenges_done")
	challenge_active = ""
	challenge_changed.emit()


# =====================================================================
# Börse für Beulen
# =====================================================================

func market_unlocked() -> bool:
	return lifetime_wumms >= float(market_config.get("unlock_lifetime_wumms", 1e7))


func market_goods() -> Array:
	return market_config.get("goods", [])


func market_good(id: String) -> Dictionary:
	for g in market_goods():
		if g.id == id:
			return g
	return {}


func market_factor(id: String) -> float:
	return float(market_factors.get(id, 1.0))


func market_price(id: String) -> float:
	var g := market_good(id)
	if g.is_empty():
		return INF
	return Balance.market_price(float(g.seconds), market_scale, market_factor(id))


func market_capacity() -> int:
	return int(market_config.get("capacity", 50))


func market_buy(id: String, amount: int) -> int:
	var price := market_price(id)
	var space := market_capacity() - int(market_holdings.get(id, 0))
	amount = mini(amount, mini(space, int(floor(wumms / price)) if price > 0.0 else 0))
	if amount <= 0:
		return 0
	wumms -= price * amount
	market_holdings[id] = int(market_holdings.get(id, 0)) + amount
	market_paid[id] = float(market_paid.get(id, 0.0)) + price * amount
	return amount


## Verkauft Ware. Gibt den Gewinn (kann negativ sein) zurück.
func market_sell(id: String, amount: int) -> float:
	var held := int(market_holdings.get(id, 0))
	amount = mini(amount, held)
	if amount <= 0:
		return 0.0
	var avg := float(market_paid.get(id, 0.0)) / held
	var revenue := market_price(id) * amount
	var profit := revenue - avg * amount
	wumms += revenue
	market_holdings[id] = held - amount
	market_paid[id] = avg * (held - amount)
	if profit > 0.0:
		add_stat("market_wins")
	return profit


func market_average_price(id: String) -> float:
	var held := int(market_holdings.get(id, 0))
	return 0.0 if held <= 0 else float(market_paid.get(id, 0.0)) / held


func _update_market(delta: float) -> void:
	market_scale = maxf(market_scale, base_wps())
	if market_config.is_empty():
		return
	_market_timer += delta
	if _market_timer < float(market_config.get("update_seconds", 60)):
		return
	_market_timer = 0.0
	step_market()


func step_market() -> void:
	for g in market_goods():
		market_factors[g.id] = Balance.market_step(market_factor(g.id), _rng.randfn(0.0, 1.0), float(g.volatility))


# =====================================================================
# Boss-Kämpfe
# =====================================================================

func _check_boss_start() -> void:
	if boss_active or boss_config.is_empty() or total_hits < next_boss_at:
		return
	var defeated := int(stat("bosses_defeated"))
	boss_max_hp = Balance.boss_hp(defeated, float(boss_config.get("base_hp", 100)))
	boss_hp = boss_max_hp
	boss_time = float(boss_config.get("time_limit", 30))
	var gimmicks: Array = boss_config.get("gimmicks", [])
	boss_gimmick = gimmicks[defeated % gimmicks.size()] if not gimmicks.is_empty() else {}
	boss_active = true
	boss_started.emit()


## Schaden am Boss. `mult` kommt von der Oberfläche (Schwachstelle ×5).
func boss_damage(mult: float = 1.0) -> void:
	if not boss_active:
		return
	boss_hp = maxf(0.0, boss_hp - mult * rage_multiplier())
	if boss_hp <= 0.0:
		_finish_boss(true)


func _update_boss(delta: float) -> void:
	if not boss_active:
		return
	boss_time -= delta
	if boss_time <= 0.0:
		_finish_boss(false)


func _finish_boss(won: bool) -> void:
	boss_active = false
	var reward := {}
	if won:
		var defeated := int(stat("bosses_defeated"))
		var marken := int(boss_config.get("reward_marken_base", 5)) + int(boss_config.get("reward_marken_per_boss", 2)) * defeated
		var list: Array = boss_config.get("trophies", [tr("Pokal")])
		var trophy := String(list[defeated % list.size()])
		if defeated >= list.size():
			trophy += " (%d.)" % (defeated / list.size() + 1)
		beulen_marken += marken
		trophies.append(trophy)
		add_stat("bosses_defeated")
		next_boss_at = total_hits + int(boss_config.get("interval_hits", 100000))
		reward = {"marken": marken, "trophy": trophy}
	else:
		next_boss_at = total_hits + int(boss_config.get("retry_hits", 10000))
	boss_finished.emit(won, reward)


# =====================================================================
# Tage: Tagesaufträge, Login-Serie, Saison-Events
# =====================================================================

func today() -> String:
	return _today_override if _today_override != "" else Time.get_date_string_from_system()


static func previous_day(day: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)


func check_new_day() -> void:
	var day := today()
	if quests_day != day:
		_generate_quests(day)
	if last_login_day != day:
		_process_login(day)
	if minigame_day != day:
		minigame_day = day
		minigame_rewards_today.clear()


func _generate_quests(day: String) -> void:
	quests_day = day
	quests.clear()
	if quest_defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	var pool: Array = quest_defs.duplicate()
	for i in mini(QUESTS_PER_DAY, pool.size()):
		var q: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var tier := rng.randi() % (q.amounts as Array).size()
		quests.append({"id": q.id, "amount": int(q.amounts[tier]), "reward": int(q.reward) + tier,
			"start": quest_metric(q.metric), "claimed": false})
	quests_changed.emit()


func quest_def(id: String) -> Dictionary:
	for q in quest_defs:
		if q.id == id:
			return q
	return {}


func quest_metric(metric: String) -> int:
	return total_hits if metric == "hits" else int(stat(metric))


func quest_progress(q: Dictionary) -> int:
	var d := quest_def(q.id)
	if d.is_empty():
		return 0
	return clampi(quest_metric(d.metric) - int(q.start), 0, int(q.amount))


func quest_text(q: Dictionary) -> String:
	return String(quest_def(q.id).get("text", "%s")) % Num.whole(float(q.amount))


func quest_done(q: Dictionary) -> bool:
	return quest_progress(q) >= int(q.amount)


func claimable_quests() -> int:
	var n := 0
	for q in quests:
		if quest_done(q) and not q.claimed:
			n += 1
	return n


func claim_quest(index: int) -> int:
	if index < 0 or index >= quests.size():
		return 0
	var q: Dictionary = quests[index]
	if q.claimed or not quest_done(q):
		return 0
	q.claimed = true
	beulen_marken += int(q.reward)
	add_stat("quests_done")
	quests_changed.emit()
	return int(q.reward)


func _process_login(day: String) -> void:
	login_streak = login_streak + 1 if last_login_day == previous_day(day) else 1
	last_login_day = day
	add_stat("best_streak", login_streak)
	var marken := Balance.login_marken(login_streak)
	var gain := Balance.blessing(base_wps(), wumms, 5.0 * Balance.login_day(login_streak), 0.1,
		100.0 * Balance.login_day(login_streak))
	beulen_marken += marken
	earn(gain)
	pending_login = {"streak": login_streak, "day": Balance.login_day(login_streak), "marken": marken, "wumms": gain}


## Das gerade laufende Saison-Event (oder ein leeres Dictionary).
func active_event() -> Dictionary:
	var md := today().substr(5)
	for e in event_defs:
		if md >= String(e.start) and md <= String(e.end):
			return e
	return {}


func event_key(e: Dictionary) -> String:
	return "%s-%s" % [e.id, today().substr(0, 4)]


## Event-Figuren sind während ihres Events verfügbar und bleiben es, sobald man das Event einmal geschafft hat.
func figure_available(id: String) -> bool:
	if id == DEFAULT_TARGET:
		return true
	var is_event_figure := false
	for e in event_defs:
		if e.figure == id:
			is_event_figure = true
	if not is_event_figure:
		return _figure_by_id.has(id)
	for e in event_defs:
		if e.figure != id:
			continue
		if active_event().get("id", "") == e.id:
			return true
		for key in events_done:
			if String(key).begins_with(e.id + "-"):
				return true
	return false


func _is_event_figure(id: String) -> bool:
	for e in event_defs:
		if e.figure == id:
			return true
	return false


func event_hits(e: Dictionary) -> int:
	return int(event_progress.get(event_key(e), 0))


func _count_event_hit() -> void:
	var e := active_event()
	if e.is_empty() or target_id != e.figure:
		return
	var key := event_key(e)
	event_progress[key] = int(event_progress.get(key, 0)) + 1
	if not events_done.has(key) and int(event_progress[key]) >= int(e.goal_hits):
		events_done[key] = true
		beulen_marken += int(e.reward_marken)
		trophies.append(String(e.trophy))
		add_stat("events_done")
		event_completed.emit(e)


# =====================================================================
# Mini-Spiele
# =====================================================================

func minigame_unlocked(game: String) -> bool:
	match game:
		"dojo":
			return total_hits >= 5000
		"pie":
			return device_count("tortenkanone") > 0 or laurels_total > 0
	return false


func minigame_unlock_text(game: String) -> String:
	return tr("Ab 5.000 Treffern") if game == "dojo" else tr("Ab der ersten Tortenwurf-Kanone")


## Wertet ein Mini-Spiel aus. Gibt die heute neu verdienten Beulen-Marken zurück (max. 5 pro Spiel und Tag).
func record_minigame(game: String, score: int) -> int:
	if not MINIGAMES.has(game):
		return 0
	check_new_day()
	var info: Dictionary = MINIGAMES[game]
	minigame_finished.emit(game, score)
	add_stat("minigames_played")
	add_stat(info.stat, score)
	var reward := Balance.minigame_reward(score, int(info.points_per_marke))
	var already := int(minigame_rewards_today.get(game, 0))
	var gain := maxi(0, reward - already)
	minigame_rewards_today[game] = maxi(already, reward)
	beulen_marken += gain
	return gain


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
			return Vector2(lifetime_wumms, target)
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
		"laurels":
			return Vector2(laurels_total, target)
		"laurel_nodes":
			return Vector2(laurel_nodes.size(), target)
		"figures_hit":
			var least := INF
			for f in figure_defs:
				if f.id != CUSTOM_FIGURE and not _is_event_figure(f.id):
					least = minf(least, float(target_hits.get(f.id, 0)))
			return Vector2(0.0 if is_inf(least) else least, target)
		"bump_level":
			var best := 0
			for id in target_hits:
				best = maxi(best, Balance.bump_level(int(target_hits[id])))
			return Vector2(best, target)
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
	beulen_marken += 1
	achievement_unlocked.emit(id)


# =====================================================================
# Zielbild
# =====================================================================

func target_name() -> String:
	if target_id == DEFAULT_TARGET:
		return tr(DEFAULT_TARGET_NAME)
	if is_figure(target_id):
		return String(figure_def(target_id).name)
	return String(target_names.get(target_id, tr("Unbekanntes Opfer")))


func current_target_hits() -> int:
	return int(target_hits.get(target_id, 0))


func current_bump_level() -> int:
	return Balance.bump_level(current_target_hits())


func bump_level_of(id: String) -> int:
	return Balance.bump_level(int(target_hits.get(id, 0)))


## Mimik-Stufe der Standardfigur: 0 = gelassen, 1 = genervt (ab Level 4), 2 = am Ende (ab Level 8).
func mood_index(level: int) -> int:
	return 2 if level >= 8 else (1 if level >= 4 else 0)


func target_figure() -> Dictionary:
	return figure_def(target_id if _figure_by_id.has(target_id) else CUSTOM_FIGURE)


## Mitgelieferte Figur (Bombastus, Event-Figuren) statt eigenes Bild?
func is_figure(id: String) -> bool:
	return id != CUSTOM_FIGURE and _figure_by_id.has(id)


func target_texture() -> Texture2D:
	if is_figure(target_id):
		var moods: Array = target_figure().get("moods", [])
		if not moods.is_empty():
			return load(moods[mini(mood_index(current_bump_level()), moods.size() - 1)]) as Texture2D
	if not is_figure(target_id):
		var img := Image.load_from_file(_image_path(target_id))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		push_warning("Bild %s fehlt, nehme Standardfigur." % target_id)
		target_id = DEFAULT_TARGET
	return load(DEFAULT_TEXTURE_PATH) as Texture2D


func use_default_target() -> void:
	select_target(DEFAULT_TARGET)


func select_target(id: String) -> void:
	if is_figure(id):
		if id != DEFAULT_TARGET and not figure_available(id):
			return
	elif not FileAccess.file_exists(_image_path(id)):
		return
	target_id = id
	target_changed.emit()


## Alle Opfer für die Galerie: Standardfigur zuerst, dann eigene Bilder (neueste zuerst).
func gallery_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": DEFAULT_TARGET, "name": tr(DEFAULT_TARGET_NAME),
		"hits": int(target_hits.get(DEFAULT_TARGET, 0)), "level": bump_level_of(DEFAULT_TARGET), "custom": false}]
	for f in figure_defs:
		if f.id != DEFAULT_TARGET and f.id != CUSTOM_FIGURE and figure_available(f.id):
			out.append({"id": f.id, "name": String(f.name), "hits": int(target_hits.get(f.id, 0)),
				"level": bump_level_of(f.id), "custom": false})
	var ids: Array = target_names.keys()
	ids.sort()
	ids.reverse()
	for id in ids:
		if FileAccess.file_exists(_image_path(id)):
			out.append({"id": id, "name": String(target_names[id]), "hits": int(target_hits.get(id, 0)),
				"level": bump_level_of(id), "custom": true})
	return out


func gallery_image(id: String) -> Image:
	if id == DEFAULT_TARGET:
		return null
	return Image.load_from_file(_image_path(id))


func rename_target(id: String, new_name: String) -> bool:
	new_name = new_name.strip_edges()
	if id == DEFAULT_TARGET or new_name == "" or not target_names.has(id):
		return false
	target_names[id] = new_name.left(40)
	add_stat("renames")
	return true


func delete_target(id: String) -> bool:
	if id == DEFAULT_TARGET or not target_names.has(id):
		return false
	DirAccess.remove_absolute(_image_path(id))
	target_names.erase(id)
	target_hits.erase(id)
	if target_id == id:
		target_id = DEFAULT_TARGET
		target_changed.emit()
	save_game()
	return true


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
	target_names[id] = display_name if display_name != "" else tr("Neues Opfer")
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
	var gain := Balance.offline_gain(base_wps(), seconds, offline_rate(), offline_cap())
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
		"lifetime_wumms": lifetime_wumms,
		"laurels_total": laurels_total,
		"laurels_spent": laurels_spent,
		"laurel_nodes": laurel_nodes.keys(),
		"next_boss_at": next_boss_at,
		"trophies": trophies.duplicate(),
		"quests_day": quests_day,
		"quests": quests.duplicate(true),
		"login_streak": login_streak,
		"last_login_day": last_login_day,
		"event_progress": event_progress.duplicate(),
		"events_done": events_done.keys(),
		"minigame_day": minigame_day,
		"minigame_rewards_today": minigame_rewards_today.duplicate(),
		"owned_cosmetics": owned_cosmetics.keys(),
		"laurels_extra": laurels_extra,
		"challenge_active": challenge_active,
		"challenges_done": challenges_done.keys(),
		"market_factors": market_factors.duplicate(),
		"market_holdings": market_holdings.duplicate(),
		"market_paid": market_paid.duplicate(),
		"market_scale": market_scale,
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
		"settings": _settings_dict(),
	}


func _settings_dict() -> Dictionary:
	return {"reduced_effects": reduced_effects, "sound_on": sound_on, "autobuy_enabled": autobuy_enabled,
		"time_warp": time_warp, "background": background, "fist_skin": fist_skin, "sound_pack": sound_pack,
		"language": language, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume}


func from_dict(data: Dictionary) -> void:
	data = _migrate(data)
	_last_loaded = data
	wumms = float(data.get("wumms", 0.0))
	total_wumms = float(data.get("total_wumms", 0.0))
	lifetime_wumms = float(data.get("lifetime_wumms", total_wumms))
	laurels_total = int(data.get("laurels_total", 0))
	laurels_spent = int(data.get("laurels_spent", 0))
	laurel_nodes = _key_set(data.get("laurel_nodes", []))
	next_boss_at = int(data.get("next_boss_at", int(boss_config.get("interval_hits", 100000))))
	trophies = (data.get("trophies", []) as Array).duplicate()
	quests_day = String(data.get("quests_day", ""))
	quests = []
	for q in data.get("quests", []):
		quests.append({"id": String(q.id), "amount": int(q.amount), "reward": int(q.reward),
			"start": int(q.start), "claimed": bool(q.claimed)})
	login_streak = int(data.get("login_streak", 0))
	last_login_day = String(data.get("last_login_day", ""))
	event_progress = {}
	var saved_events: Dictionary = data.get("event_progress", {})
	for key in saved_events:
		event_progress[key] = int(saved_events[key])
	events_done = _key_set(data.get("events_done", []))
	minigame_day = String(data.get("minigame_day", ""))
	minigame_rewards_today = {}
	var saved_mg: Dictionary = data.get("minigame_rewards_today", {})
	for key in saved_mg:
		minigame_rewards_today[key] = int(saved_mg[key])
	boss_active = false
	owned_cosmetics = _key_set(data.get("owned_cosmetics", []))
	laurels_extra = int(data.get("laurels_extra", 0))
	challenge_active = String(data.get("challenge_active", ""))
	challenges_done = _key_set(data.get("challenges_done", []))
	market_factors = {}
	var saved_factors: Dictionary = data.get("market_factors", {})
	for key in saved_factors:
		market_factors[key] = float(saved_factors[key])
	market_holdings = {}
	var saved_holdings: Dictionary = data.get("market_holdings", {})
	for key in saved_holdings:
		market_holdings[key] = int(saved_holdings[key])
	market_paid = {}
	var saved_paid: Dictionary = data.get("market_paid", {})
	for key in saved_paid:
		market_paid[key] = float(saved_paid[key])
	market_scale = float(data.get("market_scale", 1.0))
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
	autobuy_enabled = bool(settings.get("autobuy_enabled", true))
	time_warp = bool(settings.get("time_warp", false))
	background = String(settings.get("background", "standard"))
	fist_skin = String(settings.get("fist_skin", "standard"))
	sound_pack = String(settings.get("sound_pack", "standard"))
	language = String(settings.get("language", language))
	music_volume = float(settings.get("music_volume", 0.6))
	sfx_volume = float(settings.get("sfx_volume", 0.9))
	ambient_volume = float(settings.get("ambient_volume", 0.8))
	buffs.clear()
	idle_time = 0.0
	combo = 0.0
	rage_meter = 0.0
	rage_time = 0.0


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
	if version < 3:
		# v2 → v3: Lorbeeren und Lebenszeit-Wumms sind neu. Erfolge geben jetzt je eine
		# Beulen-Marke – bereits verdiente werden nachträglich gutgeschrieben.
		data["lifetime_wumms"] = data.get("lifetime_wumms", data.get("total_wumms", 0.0))
		data["laurels_total"] = data.get("laurels_total", 0)
		data["laurels_spent"] = data.get("laurels_spent", 0)
		data["laurel_nodes"] = data.get("laurel_nodes", [])
		data["beulen_marken"] = int(data.get("beulen_marken", 0)) + (data.get("achievements", []) as Array).size()
	if version < 4:
		# v3 → v4: Bosse, Aufträge, Login-Serie, Events, Mini-Spiele. Wer schon viele Treffer hat,
		# trifft den ersten Boss beim nächsten vollen Hunderttausend.
		var interval := int(boss_config.get("interval_hits", 100000))
		data["next_boss_at"] = (int(data.get("total_hits", 0)) / interval + 1) * interval
		data["trophies"] = data.get("trophies", [])
	if version < 5:
		# v4 → v5: Kosmetik-Laden, Herausforderungen, Börse. Nichts umzurechnen, nur Standardwerte.
		data["owned_cosmetics"] = data.get("owned_cosmetics", [])
		data["laurels_extra"] = data.get("laurels_extra", 0)
	data["version"] = maxi(version, SAVE_VERSION)
	return data


## Früher lag der Spielstand im Standard-Ordner von Godot. Seit Version 4 nutzt das Spiel einen eigenen
## Ordner (für Steam Cloud). Alte Spielstände und Bilder werden einmalig herüberkopiert.
func _migrate_user_dir() -> void:
	if not persist or FileAccess.file_exists(SAVE_PATH):
		return
	var old_dir := OS.get_data_dir().path_join("Godot/app_userdata/Punch your Enemy")
	var new_dir := ProjectSettings.globalize_path("user://")
	if old_dir.simplify_path() == new_dir.simplify_path().trim_suffix("/") or not DirAccess.dir_exists_absolute(old_dir):
		return
	for file in ["savegame.json", "savegame.bak.json"]:
		if FileAccess.file_exists(old_dir.path_join(file)):
			DirAccess.copy_absolute(old_dir.path_join(file), new_dir.path_join(file))
	var old_images := old_dir.path_join("images")
	if DirAccess.dir_exists_absolute(old_images):
		DirAccess.make_dir_recursive_absolute(IMAGE_DIR)
		for file in DirAccess.get_files_at(old_images):
			DirAccess.copy_absolute(old_images.path_join(file), ProjectSettings.globalize_path(IMAGE_DIR).path_join(file))


func save_game() -> bool:
	if not persist:
		return true
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
	var keep_settings := _settings_dict()
	from_dict({"version": SAVE_VERSION, "settings": keep_settings})
	target_names = names
	validate_cosmetics()
	reset_shoe_timers()
	save_game()
	target_changed.emit()
