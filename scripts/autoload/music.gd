extends Node
## Dynamic music: two synchronized loops synthesized at startup — a calm pad layer and a
## percussion/bass "battle" layer. `set_intensity(0..1)` crossfades the battle layer, so the
## music follows how dangerous the current wave is. Placeholder for composed stems later
## (same API: swap the generated streams for imported loops).

const RATE := 22050
const BPM := 100.0
const BARS := 4

var _calm: AudioStreamPlayer
var _battle: AudioStreamPlayer
var _intensity := 0.0
var _target := 0.0
var enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	_calm = AudioStreamPlayer.new()
	_battle = AudioStreamPlayer.new()
	for p in [_calm, _battle]:
		p.bus = "Music"
		add_child(p)
	_calm.stream = _make_calm()
	_battle.stream = _make_battle()
	_calm.volume_db = -8.0
	_battle.volume_db = -60.0
	_calm.play()
	_battle.play()


func set_intensity(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	if not enabled:
		return
	_intensity = move_toward(_intensity, _target, delta * 0.35)
	_battle.volume_db = linear_to_db(maxf(0.0005, _intensity)) - 4.0
	_calm.volume_db = linear_to_db(maxf(0.05, 1.0 - _intensity * 0.6)) - 8.0
	# Keep both layers aligned.
	if absf(_calm.get_playback_position() - _battle.get_playback_position()) > 0.08:
		_battle.seek(_calm.get_playback_position())


func _length() -> float:
	return 60.0 / BPM * 4.0 * BARS


func _make_calm() -> AudioStreamWAV:
	# Minor chord progression: Am - F - C - G
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [130.8, 164.8, 196.0], [196.0, 246.9, 293.7]]
	var n := int(_length() * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bar_len := n / BARS
	for i in n:
		var bar := mini(i / bar_len, BARS - 1)
		var t := float(i) / RATE
		var local := float(i % bar_len) / bar_len
		var env := minf(1.0, local * 6.0) * (1.0 - local * 0.4)
		var s := 0.0
		for f in chords[bar]:
			s += sin(TAU * f * t) * 0.18 + sin(TAU * f * 2.0 * t) * 0.04
		buf[i] = s * env * 0.6
	return _to_wav(buf)


func _make_battle() -> AudioStreamWAV:
	var n := int(_length() * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var beat := int(60.0 / BPM * RATE)
	var roots := [110.0, 87.3, 65.4, 98.0]
	var bar_len := n / BARS
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var in_beat := i % beat
		var b := i / beat
		var t := float(i) / RATE
		var s := 0.0
		# Kick on every beat, snare-ish noise on 2 and 4, hats on eighths.
		var kt := float(in_beat) / RATE
		s += sin(TAU * (55.0 + 90.0 * exp(-kt * 30.0)) * kt) * exp(-kt * 9.0) * 0.8
		if b % 2 == 1:
			s += rng.randf_range(-1.0, 1.0) * exp(-kt * 18.0) * 0.35
		var eighth := i % (beat / 2)
		s += rng.randf_range(-1.0, 1.0) * exp(-float(eighth) / RATE * 60.0) * 0.12
		# Driving bass on eighths.
		var root: float = roots[mini(i / bar_len, BARS - 1)]
		s += (1.0 if sin(TAU * root * t) > 0.0 else -1.0) * 0.12 * exp(-float(eighth) / RATE * 6.0)
		buf[i] = s * 0.5
	return _to_wav(buf)


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w
