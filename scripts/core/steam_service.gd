extends Node
## Steam-Anbindung (Autoload "SteamService").
##
## Nutzt GodotSteam (GDExtension), wenn es installiert ist – sonst passiert einfach nichts, das Spiel
## läuft ganz normal ohne Steam (Editor, Tests, DRM-freie Builds). Einrichtung: docs/steam.md.
##
## Was es tut:
## - Steam initialisieren (App-ID aus den Projekteinstellungen, Schlüssel "steam/app_id").
## - Erfolge an Steam melden. Steam-API-Name = Erfolgs-ID in Großbuchstaben (z. B. ERSTES_AUA).
##   Beim Start werden bereits freigeschaltete Erfolge nachgemeldet.
## - Bestenlisten (nur nicht-bildbezogene Werte): Rekorde der Mini-Spiele und Lorbeeren.
## - Rich Presence: "Haut gerade auf Generalissimo Bombastus" (eigene Bilder nur als "ein eigenes Bild").
## - Steam Cloud braucht keinen Code: Auto-Cloud synchronisiert savegame.json (siehe docs/steam.md).
##   Importierte Bilder werden bewusst NICHT synchronisiert – sie bleiben lokal.

const DEFAULT_APP_ID := 480  # Spacewar, die offizielle Test-App von Valve – vor Release ersetzen!

## Bestenlisten in Steamworks (Sortierung absteigend, Anzeige numerisch).
const LEADERBOARDS := {"dojo": "DOJO_BEST", "pie": "PIE_BEST", "laurels": "LAURELS"}
const PRESENCE_INTERVAL := 30.0
# i18n: Texte für die Rich-Presence-Dateien (tools/steam_rich_presence.gd), nicht im Spiel angezeigt
const PRESENCE_TEXTS: Array[String] = ["Haut auf %target%", "Kämpft gegen einen Boss!", "ein eigenes Bild"]

var steam: Object = null
var enabled := false
var _embedded_callbacks := false
var _boards: Dictionary = {}          # API-Name -> Handle
var _pending_scores: Dictionary = {}  # API-Name -> Punktzahl (bis die Bestenliste gefunden ist)
var _presence_timer := 0.0


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var app_id := int(ProjectSettings.get_setting("steam/app_id", DEFAULT_APP_ID))
	var result: Variant = _init_steam(app_id)
	var status := int(result.get("status", -1)) if result is Dictionary else (0 if result == true else -1)
	if status != 0:
		push_warning("Steam konnte nicht gestartet werden (%s). Das Spiel läuft ohne Steam weiter." % str(result))
		steam = null
		return
	enabled = true
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	GameState.minigame_finished.connect(func(game: String, score: int) -> void:
		submit_score(LEADERBOARDS.get(game, ""), score))
	GameState.prestiged.connect(func(_gain: int) -> void: submit_score(LEADERBOARDS.laurels, GameState.laurels_total))
	sync_achievements()
	_find_leaderboards()
	update_presence()


## GodotSteam hat die Signatur von steamInitEx zwischen Versionen geändert – beide Varianten unterstützen.
func _init_steam(app_id: int) -> Variant:
	var arg_count := -1
	for m in steam.get_method_list():
		if m.name == "steamInitEx":
			arg_count = (m.args as Array).size()
			break
	_embedded_callbacks = true
	match arg_count:
		2:
			return steam.call("steamInitEx", app_id, true)
		3:
			return steam.call("steamInitEx", false, app_id, true)
	_embedded_callbacks = false
	if steam.has_method("steamInit"):
		return steam.call("steamInit")
	return null


func _process(delta: float) -> void:
	if not enabled:
		return
	if not _embedded_callbacks and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")
	_presence_timer += delta
	if _presence_timer >= PRESENCE_INTERVAL:
		_presence_timer = 0.0
		update_presence()


# --- Bestenlisten ---

func _find_leaderboards() -> void:
	if not steam.has_method("findLeaderboard") or not steam.has_signal("leaderboard_find_result"):
		return
	steam.connect("leaderboard_find_result", _on_leaderboard_found)
	for api in LEADERBOARDS.values():
		steam.call("findLeaderboard", api)


func _on_leaderboard_found(handle: int, found: int) -> void:
	if found == 0 or not steam.has_method("getLeaderboardName"):
		return
	var api := String(steam.call("getLeaderboardName", handle))
	_boards[api] = handle
	if _pending_scores.has(api):
		submit_score(api, int(_pending_scores[api]))
		_pending_scores.erase(api)


## Meldet einen Wert an eine Bestenliste (Steam behält automatisch den besten).
func submit_score(api: String, score: int) -> void:
	if not enabled or api == "" or not steam.has_method("uploadLeaderboardScore"):
		return
	if not _boards.has(api):
		_pending_scores[api] = maxi(score, int(_pending_scores.get(api, 0)))
		return
	steam.call("uploadLeaderboardScore", score, true, PackedInt32Array(), _boards[api])


# --- Rich Presence ---

## Texte kommen aus den Rich-Presence-Dateien in Steamworks (docs/steam_rich_presence_*.vdf).
func update_presence() -> void:
	if not enabled or not steam.has_method("setRichPresence"):
		return
	steam.call("setRichPresence", "target", presence_target_token(GameState.target_id, GameState.is_figure(GameState.target_id)))
	steam.call("setRichPresence", "steam_display", "#Status_Boss" if GameState.boss_active else "#Status_Punching")


## Eigene Bilder werden nie mit Namen gezeigt – nur als "ein eigenes Bild".
static func presence_target_token(target_id: String, is_figure: bool) -> String:
	return "Fig_%s" % target_id if is_figure else "Fig_custom"


static func api_name(achievement_id: String) -> String:
	return achievement_id.to_upper()


func _on_achievement_unlocked(id: String) -> void:
	if not enabled:
		return
	steam.call("setAchievement", api_name(id))
	steam.call("storeStats")


## Meldet alle lokal freigeschalteten Erfolge an Steam (z. B. nach dem ersten Start mit Steam).
func sync_achievements() -> void:
	if not enabled:
		return
	for id in GameState.achievements:
		steam.call("setAchievement", api_name(id))
	steam.call("storeStats")
