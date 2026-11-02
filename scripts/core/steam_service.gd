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
## - Steam Cloud braucht keinen Code: Auto-Cloud synchronisiert savegame.json (siehe docs/steam.md).
##   Importierte Bilder werden bewusst NICHT synchronisiert – sie bleiben lokal.

const DEFAULT_APP_ID := 480  # Spacewar, die offizielle Test-App von Valve – vor Release ersetzen!

var steam: Object = null
var enabled := false
var _embedded_callbacks := false


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
	sync_achievements()


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


func _process(_delta: float) -> void:
	if enabled and not _embedded_callbacks and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")


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
