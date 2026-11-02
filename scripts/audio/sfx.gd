extends Node
## Sound-Manager (Autoload "Sfx").
## Erzeugt im MVP alle Geräusche prozedural, damit keine Audiodateien nötig sind.
## Später durch echte Sounds in assets/audio/ ersetzen (8–12 Varianten pro Gerät, siehe Konzept).

const RATE := 22050
const VOICES := 12
const PACK_PREFIX := {"retro": "retro_", "kampfsport": "kampf_"}
const BUSES: Array[String] = ["Music", "SFX", "Ambient"]
const CUSTOM_DIR := "res://assets/audio/sfx"

var _ambient: AudioStreamPlayer

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}  # name -> Array[AudioStreamWAV]


func _ready() -> void:
	setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	_streams["punch"] = [_make_punch(110.0, 0.16, 0.55), _make_punch(85.0, 0.2, 0.45), _make_punch(140.0, 0.13, 0.65),
		_make_punch(100.0, 0.18, 0.8), _make_punch(125.0, 0.12, 0.4), _make_slap(0.09), _make_slap(0.12), _make_slap(0.07)]
	_streams["crit"] = [_make_punch(55.0, 0.4, 0.9)]
	_streams["boing"] = [_make_boing()]
	_streams["squeak"] = [_make_squeak()]
	_streams["buy"] = [_make_bling()]
	_streams["golden"] = [_make_arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.07, 0.35)]
	_streams["achievement"] = [_make_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.11, 0.4)]
	_streams["bad"] = [_make_arpeggio([392.0, 370.0, 349.0, 262.0], 0.16, 0.35)]
	_streams["shoe_appear"] = [_make_arpeggio([1319.0, 1760.0], 0.06, 0.25)]
	_streams["rage"] = [_make_square(110.0, 55.0, 0.6, 0.35), ]
	_streams["prestige"] = [_make_arpeggio([262.0, 330.0, 392.0, 523.0, 659.0, 784.0, 1047.0], 0.09, 0.4)]
	# Retro-Soundpaket (Lorbeer-Baum, Zweig "Show"): Rechteckwellen wie am Spielautomaten
	_streams["retro_punch"] = [_make_square(220.0, 80.0, 0.09, 0.3), _make_square(180.0, 70.0, 0.1, 0.3)]
	_streams["retro_crit"] = [_make_square(440.0, 60.0, 0.3, 0.35)]
	_streams["retro_buy"] = [_make_square(660.0, 1320.0, 0.12, 0.25)]
	_streams["retro_boing"] = [_make_square(300.0, 600.0, 0.2, 0.2)]
	_streams["retro_squeak"] = [_make_square(1200.0, 1600.0, 0.08, 0.15)]
	# Kampfsport-Paket (Kosmetik-Laden): Wusch und Zack, beim Kaufen ein Gong
	_streams["kampf_punch"] = [_make_whoosh(0.16, 900.0), _make_whoosh(0.13, 1300.0), _make_whoosh(0.18, 700.0)]
	_streams["kampf_crit"] = [_make_whoosh(0.3, 500.0)]
	_streams["kampf_buy"] = [_make_gong()]
	_streams["kampf_boing"] = [_make_whoosh(0.22, 1600.0)]
	_streams["applause_small"] = [_make_applause(1.6, 14)]
	_streams["applause_big"] = [_make_applause(3.2, 40)]
	_load_custom_sounds()
	apply_volumes()


## Eigene Audio-Busse für Musik, Effekte und Publikum (Lautstärke getrennt einstellbar).
static func setup_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


## Lautstärken aus den Einstellungen übernehmen (0..1, linear).
func apply_volumes() -> void:
	AudioServer.set_bus_mute(0, not GameState.sound_on)
	var levels := {"Music": GameState.music_volume, "SFX": GameState.sfx_volume, "Ambient": GameState.ambient_volume}
	for bus in levels:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			var v: float = levels[bus]
			AudioServer.set_bus_mute(idx, v <= 0.001)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## Publikum: Applaus bei Erfolgen ("small") und großen Momenten ("big").
func applause(big: bool = false) -> void:
	if not GameState.sound_on:
		return
	_ambient.stream = _streams["applause_big" if big else "applause_small"][0]
	_ambient.volume_db = 0.0 if big else -6.0
	_ambient.play()


## Echte Sounds: Dateien in assets/audio/sfx/ ersetzen die erzeugten Platzhalter.
## Name = Sound-Name, Varianten mit Unterstrich: punch_1.ogg, punch_2.ogg, buy.wav, applause_big.ogg …
func _load_custom_sounds() -> void:
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		return
	var custom: Dictionary = {}
	for file in DirAccess.get_files_at(CUSTOM_DIR):
		file = file.trim_suffix(".import").trim_suffix(".remap")
		var ext := file.get_extension().to_lower()
		if ext not in ["ogg", "wav", "mp3"]:
			continue
		var base := file.get_basename()
		var sound := base
		var cut := base.rfind("_")
		if cut > 0 and base.substr(cut + 1).is_valid_int():
			sound = base.substr(0, cut)
		var path := "%s/%s" % [CUSTOM_DIR, file]
		if ResourceLoader.exists(path):
			if not custom.has(sound):
				custom[sound] = []
			custom[sound].append(load(path))
	for sound in custom:
		_streams[sound] = custom[sound]


func play(sound: String, pitch_spread: float = 0.1, volume_db: float = 0.0) -> void:
	if not GameState.sound_on or not _streams.has(sound):
		return
	var prefix: String = PACK_PREFIX.get(GameState.sound_pack, "")
	if prefix != "" and _streams.has(prefix + sound):
		sound = prefix + sound
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	var variants: Array = _streams[sound]
	p.stream = variants[randi() % variants.size()]
	p.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	p.volume_db = volume_db
	p.play()


func play_hit(crit: bool) -> void:
	if crit:
		play("crit", 0.05, 2.0)
		play("boing", 0.1, -4.0)
		return
	play("punch", 0.12, -3.0)
	var r := randf()
	if r < 0.12:
		play("squeak", 0.2, -8.0)
	elif r < 0.2:
		play("boing", 0.15, -9.0)


# --- Synthese --------------------------------------------------------------

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _buffer(duration: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * duration))
	return s


## Dumpfer Cartoon-Schlag: abfallender Sinus plus kurzer Rausch-Klatscher.
func _make_punch(freq: float, duration: float, noise: float) -> AudioStreamWAV:
	var s := _buffer(duration)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := freq * (1.0 + 2.5 * exp(-t * 45.0))
		phase += TAU * f / RATE
		var tone := sin(phase) * exp(-t * 16.0)
		var hiss := (randf() * 2.0 - 1.0) * exp(-t * 70.0) * noise
		s[i] = (tone * 0.85 + hiss) * 0.9
	return _to_wav(s)


## "Boing" mit Vibrato.
func _make_boing() -> AudioStreamWAV:
	var s := _buffer(0.5)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 160.0 + 160.0 * exp(-t * 7.0) + 30.0 * sin(t * 45.0)
		phase += TAU * f / RATE
		s[i] = sin(phase) * exp(-t * 5.0) * 0.6
	return _to_wav(s)


## Quietschen wie ein Gummihammer.
func _make_squeak() -> AudioStreamWAV:
	var s := _buffer(0.14)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 1000.0 + 700.0 * sin(t / 0.14 * PI)
		phase += TAU * f / RATE
		var env := sin(t / 0.14 * PI)
		s[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * env * 0.35
	return _to_wav(s)


## Tonfolge (Glockenspiel-artig), z. B. für Goldene Schuhe und Erfolge.
func _make_arpeggio(notes: Array, note_length: float, volume: float) -> AudioStreamWAV:
	var s := _buffer(note_length * notes.size() + 0.25)
	for n in notes.size():
		var start := int(n * note_length * RATE)
		var freq: float = notes[n]
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			var env := exp(-t * 7.0)
			if env < 0.001:
				break
			s[i] += (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * volume
	return _to_wav(s)


## Klatscher: kurzes, helles Rauschen mit schnellem Abfall.
func _make_slap(duration: float) -> AudioStreamWAV:
	var s := _buffer(duration)
	var last := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		var high := noise - last * 0.6
		last = noise
		s[i] = (high * 0.8 + sin(TAU * 240.0 * t) * 0.3) * exp(-t * 45.0) * 0.9
	return _to_wav(s)


## Applaus: viele zufällige Klatscher, die anschwellen und ausklingen.
func _make_applause(duration: float, clappers: int) -> AudioStreamWAV:
	var s := _buffer(duration)
	for c in clappers:
		var t := randf_range(0.0, duration * 0.3)
		while t < duration - 0.05:
			var from := int(t * RATE)
			var loud := sin(clampf(t / duration, 0.0, 1.0) * PI) * randf_range(0.5, 1.0)
			for i in int(0.03 * RATE):
				if from + i < s.size():
					s[from + i] += (randf() * 2.0 - 1.0) * exp(-float(i) / RATE * 120.0) * loud * 0.25
			t += randf_range(0.18, 0.32)
	return _to_wav(s)


## Luftzug ("Wusch") mit anschließendem Klatscher – gefiltertes Rauschen.
func _make_whoosh(duration: float, brightness: float) -> AudioStreamWAV:
	var s := _buffer(duration + 0.08)
	var low := 0.0
	var smoothing := clampf(brightness / RATE * TAU, 0.01, 0.9)
	for i in s.size():
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		low += (noise - low) * smoothing
		var swell := sin(clampf(t / duration, 0.0, 1.0) * PI) * 0.5
		var slap := (randf() * 2.0 - 1.0) * exp(-(t - duration) * 60.0) if t >= duration else 0.0
		s[i] = (low * swell * 2.0 + slap * 0.8) * 0.8
	return _to_wav(s)


## Gong mit langem Ausklingen.
func _make_gong() -> AudioStreamWAV:
	var s := _buffer(1.2)
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t * 3.0)
		s[i] = (sin(TAU * 220.0 * t) + 0.6 * sin(TAU * 331.0 * t) + 0.4 * sin(TAU * 523.0 * t)) * env * 0.25
	return _to_wav(s)


## Rechteckwelle mit Tonhöhen-Rampe (8-Bit-Stil).
func _make_square(freq_from: float, freq_to: float, duration: float, volume: float) -> AudioStreamWAV:
	var s := _buffer(duration)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(freq_from, freq_to, t / duration)
		phase += f / RATE
		var square := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		s[i] = square * volume * (1.0 - t / duration)
	return _to_wav(s)


## Kauf-Geräusch: zwei helle Töne.
func _make_bling() -> AudioStreamWAV:
	var s := _buffer(0.22)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 880.0 if t < 0.07 else 1320.0
		phase += TAU * f / RATE
		var local_t := t if t < 0.07 else t - 0.07
		s[i] = sin(phase) * exp(-local_t * 18.0) * 0.4
	return _to_wav(s)
