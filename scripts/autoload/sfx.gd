extends Node
## Sound effects synthesized at startup (placeholder until recorded audio exists).
## 2D for UI, 3D (positional) for battlefield sounds. Throttled so swarms stay readable.

const RATE := 22050

var _sounds := {}
var _players2d: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players2d.append(p)
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 12.0
		p.max_distance = 80.0
		add_child(p)
		_players3d.append(p)
	_sounds["ui"] = _tone([[900.0, 900.0, 0.04]], 0.22, "sine")
	_sounds["ui_back"] = _tone([[600.0, 450.0, 0.06]], 0.22, "sine")
	_sounds["build"] = _tone([[220.0, 160.0, 0.08], [330.0, 330.0, 0.06]], 0.4, "square")
	_sounds["sell"] = _tone([[800.0, 1200.0, 0.08]], 0.3, "triangle")
	_sounds["upgrade"] = _tone([[440.0, 440.0, 0.06], [660.0, 660.0, 0.06], [880.0, 880.0, 0.1]], 0.3, "triangle")
	_sounds["deny"] = _tone([[180.0, 140.0, 0.12]], 0.35, "square")
	_sounds["bow"] = _tone([[1400.0, 500.0, 0.07]], 0.25, "noise")
	_sounds["arrow_tower"] = _tone([[1100.0, 600.0, 0.05]], 0.15, "noise")
	_sounds["cannon"] = _tone([[110.0, 45.0, 0.25]], 0.55, "noise")
	_sounds["frost"] = _tone([[1800.0, 2400.0, 0.12]], 0.15, "sine")
	_sounds["hit"] = _tone([[300.0, 150.0, 0.05]], 0.2, "noise")
	_sounds["crit"] = _tone([[1500.0, 900.0, 0.08]], 0.3, "square")
	_sounds["death"] = _tone([[260.0, 90.0, 0.14]], 0.25, "noise")
	_sounds["explosion"] = _tone([[90.0, 30.0, 0.4]], 0.6, "noise")
	_sounds["spring"] = _tone([[200.0, 900.0, 0.15]], 0.35, "triangle")
	_sounds["spikes"] = _tone([[700.0, 400.0, 0.06]], 0.2, "square")
	_sounds["leak"] = _tone([[300.0, 200.0, 0.2], [200.0, 120.0, 0.25]], 0.45, "square")
	_sounds["gold"] = _tone([[1300.0, 1300.0, 0.04], [1760.0, 1760.0, 0.08]], 0.2, "sine")
	_sounds["synergy"] = _tone([[660.0, 990.0, 0.12], [1320.0, 1320.0, 0.12]], 0.3, "triangle")
	_sounds["wave_start"] = _tone([[220.0, 220.0, 0.25], [330.0, 330.0, 0.35]], 0.4, "square")
	_sounds["wave_clear"] = _tone([[523.0, 523.0, 0.1], [659.0, 659.0, 0.1], [784.0, 784.0, 0.25]], 0.35, "triangle")
	_sounds["level_up"] = _tone([[523.0, 1046.0, 0.3]], 0.35, "triangle")
	_sounds["stomp"] = _tone([[70.0, 30.0, 0.5]], 0.7, "noise")
	_sounds["hex"] = _tone([[400.0, 200.0, 0.3]], 0.3, "sine")
	_sounds["hurt"] = _tone([[240.0, 120.0, 0.12]], 0.4, "square")
	_sounds["dodge"] = _tone([[500.0, 300.0, 0.1]], 0.2, "noise")
	_sounds["victory"] = _tone([[523.0, 523.0, 0.15], [659.0, 659.0, 0.15], [784.0, 784.0, 0.15], [1046.0, 1046.0, 0.5]], 0.4, "triangle")
	_sounds["defeat"] = _tone([[392.0, 392.0, 0.25], [330.0, 330.0, 0.25], [262.0, 200.0, 0.7]], 0.4, "triangle")


func play(name: String, min_gap: float = 0.0, pitch: float = 1.0) -> void:
	if not _ok(name, min_gap):
		return
	var p := _players2d[_i2]
	_i2 = (_i2 + 1) % _players2d.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()


func play_at(name: String, pos: Vector3, min_gap: float = 0.0, pitch: float = 1.0) -> void:
	if not _ok(name, min_gap):
		return
	var p := _players3d[_i3]
	_i3 = (_i3 + 1) % _players3d.size()
	p.stream = _sounds[name]
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


func _ok(name: String, min_gap: float) -> bool:
	if not _sounds.has(name):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last.get(name, -10.0)) < min_gap:
		return false
	_last[name] = now
	return true


func _tone(notes: Array, volume: float, wave: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var phase := 0.0
	for note in notes:
		var n := int(RATE * float(note[2]))
		var offset := data.size()
		data.resize(offset + n * 2)
		for i in n:
			var t := float(i) / n
			var f := lerpf(note[0], note[1], t)
			phase += TAU * f / RATE
			var s := 0.0
			match wave:
				"sine":
					s = sin(phase)
				"square":
					s = 0.6 if sin(phase) >= 0.0 else -0.6
				"triangle":
					s = 2.0 / PI * asin(sin(phase))
				"noise":
					s = lerpf(sin(phase), rng.randf_range(-1.0, 1.0), 0.75)
			var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.5)
			data.encode_s16(offset + i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
