extends Node
## Musik (Autoload "Music"): eine schräge Ragtime-Schleife, die mit dem Fortschritt um
## Instrumente wächst (Schlagzeug → Bass → Klavier → Klarinette → Bläser) und im Wutmodus schneller wird.
##
## Die Schleife wird beim Start prozedural erzeugt (in einem Hintergrund-Thread). Wer echte Musik hat,
## legt sie als assets/audio/music/loop.ogg (oder .wav/.mp3) ab – dann wird diese Datei gespielt.

const RATE := 22050
const BPM := 112.0
const BEATS := 16                       # 4 Takte à 4 Schläge
const LAYERS: Array[String] = ["drums", "bass", "piano", "melody", "brass"]
const MUTED_DB := -60.0
const RAGE_PITCH := 1.12
const CUSTOM_DIR := "res://assets/audio/music"
const LAYER_PEAK := {"drums": 0.75, "bass": 0.7, "piano": 0.55, "melody": 0.5, "brass": 0.35}
const ATTACK := {"piano": 0.004, "bass": 0.01, "clarinet": 0.03, "brass": 0.05}

# Akkordfolge (C – A7 – D7 – G7): Bassgrundton, Quinte, Akkord-Töne (MIDI)
const CHORDS := [
	{"root": 36, "fifth": 43, "notes": [60, 64, 67], "tones": [72, 76, 79, 84]},
	{"root": 45, "fifth": 40, "notes": [61, 64, 67], "tones": [73, 76, 79, 81]},
	{"root": 38, "fifth": 45, "notes": [62, 66, 69], "tones": [74, 78, 81, 84]},
	{"root": 43, "fifth": 38, "notes": [62, 65, 71], "tones": [74, 77, 79, 83]},
]
# Synkopierte Melodie pro Takt: [Schlag, Länge in Schlägen, Index in "tones"]
const MELODY := [[0.0, 0.5, 1], [0.75, 0.5, 2], [1.5, 0.5, 3], [2.0, 0.75, 2], [3.0, 0.5, 1], [3.5, 0.5, 0]]

var player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _layer_db: Array[float] = []
var _ready_to_play := false
var _custom := false


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	var custom := _find_custom_loop()
	if custom != null:
		_custom = true
		player.stream = custom
		_start()
		return
	if DisplayServer.get_name() == "headless":
		return  # Tests und Simulationen brauchen keine Musik
	WorkerThreadPool.add_task(_generate_all)


func _find_custom_loop() -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s/loop.%s" % [CUSTOM_DIR, ext]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
				stream.loop = true
			return stream
	return null


func _generate_all() -> void:
	var streams: Array[AudioStreamWAV] = []
	for layer in LAYERS:
		streams.append(_render_layer(layer))
	_finish_generation.call_deferred(streams)


func _finish_generation(streams: Array[AudioStreamWAV]) -> void:
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = streams.size()
	for i in streams.size():
		_sync.set_sync_stream(i, streams[i])
		_sync.set_sync_stream_volume(i, MUTED_DB)
		_layer_db.append(MUTED_DB)
	player.stream = _sync
	_start()


func _start() -> void:
	_ready_to_play = true
	player.play()


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	var target_pitch := RAGE_PITCH if GameState.rage_active() else 1.0
	player.pitch_scale = move_toward(player.pitch_scale, target_pitch, delta * 0.5)
	if _custom or _sync == null:
		return
	var active := active_layers()
	for i in LAYERS.size():
		var target := 0.0 if i < active else MUTED_DB
		_layer_db[i] = move_toward(_layer_db[i], target, delta * 20.0)
		_sync.set_sync_stream_volume(i, _layer_db[i])


## Wie viele Instrumente spielen: wächst mit den Gerätetypen, nach dem ersten Neuanfang spielt alles.
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


# =====================================================================
# Synthese
# =====================================================================

func _beat() -> float:
	return 60.0 / BPM


func _render_layer(layer: String) -> AudioStreamWAV:
	var length := int(RATE * _beat() * BEATS)
	var buf := PackedFloat32Array()
	buf.resize(length)
	var b := _beat()
	for bar in 4:
		var c: Dictionary = CHORDS[bar]
		var t0 := bar * 4 * b
		match layer:
			"drums":
				for beat in 4:
					var t := t0 + beat * b
					if beat % 2 == 0:
						_kick(buf, t)
					else:
						_snare(buf, t)
					_hihat(buf, t + b * 0.5, 0.18)
					_hihat(buf, t, 0.1)
			"bass":
				_note(buf, t0, b * 0.9, c.root, "bass", 0.55)
				_note(buf, t0 + 2 * b, b * 0.9, c.fifth, "bass", 0.5)
				_note(buf, t0 + 3.5 * b, b * 0.4, c.fifth + 2, "bass", 0.3)
			"piano":
				for beat in [1, 3]:
					for n in c.notes:
						_note(buf, t0 + beat * b, b * 0.5, n, "piano", 0.22)
			"melody":
				for m in MELODY:
					_note(buf, t0 + m[0] * b, m[1] * b, c.tones[m[2]], "clarinet", 0.28)
			"brass":
				for n in c.notes:
					_note(buf, t0, b * 1.8, n, "brass", 0.12)
				_note(buf, t0 + 2.5 * b, b * 0.4, c.tones[0], "brass", 0.2)
				_note(buf, t0 + 3.0 * b, b * 0.8, c.tones[1], "brass", 0.22)
	return _to_wav(buf, LAYER_PEAK[layer])


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _note(buf: PackedFloat32Array, start: float, duration: float, midi: int, timbre: String, volume: float) -> void:
	var f := _freq(midi)
	var from := int(start * RATE)
	var tail := 0.25 if timbre == "piano" else 0.08
	var count := int((duration + tail) * RATE)
	var attack: float = ATTACK[timbre]
	for i in count:
		var idx := (from + i) % buf.size()  # Nachhall läuft in den Schleifenanfang
		var t := float(i) / RATE
		var env := _envelope(timbre, t, duration, attack)
		if env <= 0.0005:
			continue
		var ph := TAU * f * t
		var s := 0.0
		match timbre:
			"piano":
				s = sin(ph) + 0.5 * sin(2.0 * ph) + 0.25 * sin(3.0 * ph) + 0.1 * sin(4.0 * ph)
			"bass":
				s = (2.0 / PI) * asin(sin(ph)) + 0.3 * sin(2.0 * ph)
			"clarinet":
				var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t)
				var p := ph * vib
				s = sin(p) + 0.45 * sin(3.0 * p) + 0.2 * sin(5.0 * p)
			"brass":
				for h in range(1, 7):
					s += sin(h * ph) / h
				s *= 0.8
		buf[idx] += s * env * volume


func _envelope(timbre: String, t: float, duration: float, attack: float) -> float:
	var a := clampf(t / attack, 0.0, 1.0)
	match timbre:
		"piano":
			return a * exp(-t * 3.5)
		"bass":
			return a * exp(-t * 3.0) * (1.0 if t < duration else exp(-(t - duration) * 30.0))
	var release := 1.0 if t < duration else exp(-(t - duration) * 25.0)
	return a * release * (0.85 + 0.15 * exp(-t * 4.0))


func _kick(buf: PackedFloat32Array, start: float) -> void:
	var from := int(start * RATE)
	var phase := 0.0
	for i in int(0.25 * RATE):
		var t := float(i) / RATE
		phase += TAU * (45.0 + 70.0 * exp(-t * 30.0)) / RATE
		buf[(from + i) % buf.size()] += sin(phase) * exp(-t * 14.0) * 0.6


func _snare(buf: PackedFloat32Array, start: float) -> void:
	var from := int(start * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = from
	for i in int(0.18 * RATE):
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		buf[(from + i) % buf.size()] += (noise * 0.7 + sin(TAU * 190.0 * t) * 0.3) * exp(-t * 22.0) * 0.35


func _hihat(buf: PackedFloat32Array, start: float, volume: float) -> void:
	var from := int(start * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = from + 7
	var last := 0.0
	for i in int(0.05 * RATE):
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		var high := noise - last  # einfacher Hochpass
		last = noise
		buf[(from + i) % buf.size()] += high * exp(-t * 80.0) * volume


func _to_wav(buf: PackedFloat32Array, target_peak: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := target_peak / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buf.size()
	return wav
