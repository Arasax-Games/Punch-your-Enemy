extends Node
## Sound-Manager (Autoload "Sfx").
## Erzeugt im MVP alle Geräusche prozedural, damit keine Audiodateien nötig sind.
## Später durch echte Sounds in assets/audio/ ersetzen (8–12 Varianten pro Gerät, siehe Konzept).

const RATE := 22050
const VOICES := 12

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}  # name -> Array[AudioStreamWAV]


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["punch"] = [_make_punch(110.0, 0.16, 0.55), _make_punch(85.0, 0.2, 0.45), _make_punch(140.0, 0.13, 0.65)]
	_streams["crit"] = [_make_punch(55.0, 0.4, 0.9)]
	_streams["boing"] = [_make_boing()]
	_streams["squeak"] = [_make_squeak()]
	_streams["buy"] = [_make_bling()]
	_streams["golden"] = [_make_arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.07, 0.35)]
	_streams["achievement"] = [_make_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.11, 0.4)]
	_streams["bad"] = [_make_arpeggio([392.0, 370.0, 349.0, 262.0], 0.16, 0.35)]
	_streams["shoe_appear"] = [_make_arpeggio([1319.0, 1760.0], 0.06, 0.25)]


func play(sound: String, pitch_spread: float = 0.1, volume_db: float = 0.0) -> void:
	if not GameState.sound_on or not _streams.has(sound):
		return
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
