extends Node
## Musik (Autoload "Music"): fünf entspannte Titel, die sich abwechseln (oder einer in Dauerschleife).
## Jeder Titel besteht aus fünf gleich langen Schichten – Tasten → Bass → Beat → Melodie → Extras –,
## die mit dem Fortschritt dazukommen. Im Wutmodus läuft die Musik etwas schneller.
##
## Die Dateien erzeugt `python3 tools/make_music.py` (assets/audio/music/tracks/<id>_<schicht>.ogg).
## Wer eigene Musik hat, legt sie als assets/audio/music/loop.ogg (oder .wav/.mp3) ab – dann läuft nur diese.

signal track_changed(index: int)

const TRACK_DIR := "res://assets/audio/music/tracks"
const CUSTOM_DIR := "res://assets/audio/music"
const LAYERS: Array[String] = ["keys", "bass", "beat", "lead", "extra"]
# i18n: "name" und "style" werden bei der Anzeige mit tr() übersetzt
const TRACKS: Array[Dictionary] = [
	{"id": "pflaster_pause", "name": "Pflaster-Pause", "style": "Lo-Fi"},
	{"id": "haengematten_bossa", "name": "Hängematten-Bossa", "style": "Bossa Nova"},
	{"id": "eisbeutel_lounge", "name": "Eisbeutel-Lounge", "style": "Jazz-Lounge"},
	{"id": "tortenstrand", "name": "Tortenstrand", "style": "Strand-Chill"},
	{"id": "sternchen_kreisen", "name": "Sternchen kreisen", "style": "Ambient"},
]
const LOOPS_PER_TRACK := 2   # so oft läuft ein Titel durch, bevor der nächste kommt
const CROSSFADE := 4.0       # Sekunden Überblendung zwischen zwei Titeln
const MUTED_DB := -60.0
const RAGE_PITCH := 1.1

var _players: Array[AudioStreamPlayer] = []
var _syncs: Array[AudioStreamSynchronized] = [null, null]
var _layer_db: Array[float] = []
var _active := 0             # welcher der beiden Player gerade führt
var _track := -1             # Index in TRACKS
var _track_time := 0.0
var _track_length := 0.0
var _fade := 1.0             # Fortschritt der Überblendung (1 = fertig)
var _custom := false
var _ready_to_play := false


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_players.append(p)
	var custom := _find_custom_loop()
	if custom != null:
		_custom = true
		_players[0].stream = custom
		_players[0].play()
		_ready_to_play = true
		return
	if DisplayServer.get_name() == "headless":
		return  # Tests und Simulationen brauchen keine Musik
	var wanted := track_index(GameState.music_track)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	play_track(wanted if wanted >= 0 else rng.randi() % TRACKS.size(), false)


func _find_custom_loop() -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s/loop.%s" % [CUSTOM_DIR, ext]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
				stream.loop = true
			return stream
	return null


## Titel starten (mit Überblendung vom laufenden Titel).
func play_track(index: int, crossfade: bool = true) -> void:
	index = posmod(index, TRACKS.size())
	var sync := _build_sync(TRACKS[index].id)
	if sync == null:
		return
	var next := 1 - _active if _ready_to_play else _active
	var player := _players[next]
	player.stream = sync
	player.pitch_scale = _players[_active].pitch_scale
	player.volume_db = MUTED_DB if crossfade and _ready_to_play else 0.0
	player.play()
	_fade = 0.0 if crossfade and _ready_to_play else 1.0
	if not crossfade and _ready_to_play and next != _active:
		_players[_active].stop()
	_active = next
	_syncs[_active] = sync
	_track = index
	_track_time = 0.0
	_track_length = 0.0
	var first: AudioStream = sync.get_sync_stream(0)
	if first != null:
		_track_length = first.get_length()
	_ready_to_play = true
	_apply_layers(true)
	track_changed.emit(index)


func _build_sync(id: String) -> AudioStreamSynchronized:
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = LAYERS.size()
	_layer_db.resize(LAYERS.size())
	for i in LAYERS.size():
		var path := "%s/%s_%s.ogg" % [TRACK_DIR, id, LAYERS[i]]
		if not ResourceLoader.exists(path):
			push_warning("Musik fehlt: %s" % path)
			return null
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = true
		sync.set_sync_stream(i, stream)
		sync.set_sync_stream_volume(i, MUTED_DB)
	return sync


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	delta /= maxf(Engine.time_scale, 0.01)  # Zeitlupe verlangsamt nur das Bild, nicht die Musik
	var target_pitch := RAGE_PITCH if GameState.rage_active() else 1.0
	for p in _players:
		p.pitch_scale = move_toward(p.pitch_scale, target_pitch, delta * 0.5)
	if _custom:
		return
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / CROSSFADE)
		_players[_active].volume_db = linear_to_db(maxf(_fade, 0.001))
		var old := _players[1 - _active]
		old.volume_db = linear_to_db(maxf(1.0 - _fade, 0.001))
		if _fade >= 1.0:
			old.stop()
			_syncs[1 - _active] = null
	_apply_layers(false, delta)
	_track_time += delta * _players[_active].pitch_scale
	if GameState.music_track == "" and _track_length > 0.0 \
			and _track_time >= _track_length * LOOPS_PER_TRACK - CROSSFADE:
		play_track(next_track(_track, TRACKS.size()))


func _apply_layers(instant: bool, delta: float = 0.0) -> void:
	var sync := _syncs[_active]
	if sync == null:
		return
	var active := active_layers()
	for i in LAYERS.size():
		var target := 0.0 if i < active else MUTED_DB
		_layer_db[i] = target if instant else move_toward(_layer_db[i], target, delta * 20.0)
		sync.set_sync_stream_volume(i, _layer_db[i])


## Titel im Menü gewählt: "" = alle abwechselnd, sonst eine Titel-ID in Dauerschleife.
func select_track(id: String) -> void:
	GameState.music_track = id if track_index(id) >= 0 else ""
	var index := track_index(id)
	if index >= 0 and index != _track and not _custom and DisplayServer.get_name() != "headless":
		play_track(index)


func current_track() -> int:
	return _track


func track_name(index: int) -> String:
	if index < 0 or index >= TRACKS.size():
		return ""
	return tr(String(TRACKS[index].name))


func track_style(index: int) -> String:
	if index < 0 or index >= TRACKS.size():
		return ""
	return tr(String(TRACKS[index].style))


func has_custom_music() -> bool:
	return _custom


static func track_index(id: String) -> int:
	for i in TRACKS.size():
		if TRACKS[i].id == id:
			return i
	return -1


static func next_track(current: int, count: int) -> int:
	return posmod(current + 1, count)


## Wie viele Schichten spielen: wächst mit den Gerätetypen, nach dem ersten Neuanfang spielt alles.
static func layers_for(device_types: int, prestiges: int) -> int:
	if prestiges > 0:
		return 5
	if device_types >= 8:
		return 5
	if device_types >= 5:
		return 4
	if device_types >= 3:
		return 3
	if device_types >= 1:
		return 2
	return 1


func active_layers() -> int:
	return layers_for(GameState.device_types_owned(), int(GameState.stat("prestiges")))
