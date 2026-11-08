extends Node
## Procedural chiptune music (autoload "Music"). Each level has a THEME below; the loop is
## synthesized the first time it is needed, so there are no audio files. Press M to mute.
## Tweak THEMES to change the feel: bpm, root note (MIDI), scale, chord progression (scale
## degrees, one per bar), wave shapes and whether drums play.

const RATE := 22050
const MINOR := [0, 2, 3, 5, 7, 8, 10]
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const DORIAN := [0, 2, 3, 5, 7, 9, 10]

const THEMES := {
	"map": {"bpm": 96, "root": 60, "scale": MAJOR, "prog": [0, 4, 5, 3], "lead": 0.12, "drums": false, "seed": 1},
	"library": {"bpm": 108, "root": 57, "scale": DORIAN, "prog": [0, 5, 3, 4], "lead": 0.25, "drums": true, "seed": 2},
	"chase": {"bpm": 150, "root": 62, "scale": MINOR, "prog": [0, 5, 3, 6], "lead": 0.5, "drums": true, "seed": 3},
	"hideout": {"bpm": 84, "root": 55, "scale": MINOR, "prog": [0, 3, 5, 4], "lead": 0.125, "drums": false, "seed": 4},
	"hack": {"bpm": 128, "root": 59, "scale": MINOR, "prog": [0, 0, 5, 6], "lead": 0.25, "drums": true, "seed": 5},
	"crash": {"bpm": 160, "root": 58, "scale": MINOR, "prog": [0, 1, 0, 6], "lead": 0.5, "drums": true, "seed": 6},
	"time": {"bpm": 100, "root": 62, "scale": DORIAN, "prog": [0, 2, 4, 3], "lead": 0.125, "drums": true, "seed": 7},
	"future": {"bpm": 120, "root": 64, "scale": MAJOR, "prog": [0, 5, 3, 4], "lead": 0.25, "drums": true, "seed": 8},
}

const SCENE_THEMES := {
	"world_map": "map", "main": "library", "chase": "chase", "hideout": "hideout",
	"hack": "hack", "crash": "crash", "time": "time", "future": "future",
}

var _player: AudioStreamPlayer
var _cache := {}
var _current := ""
var _muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -10.0
	add_child(_player)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var key: String = SCENE_THEMES.get(scene.scene_file_path.get_file().get_basename(), "")
	if key != "" and key != _current:
		play_theme(key)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_muted = not _muted
		_player.volume_db = -80.0 if _muted else -10.0


func play_theme(key: String) -> void:
	_current = key
	if not _cache.has(key):
		_cache[key] = _render(THEMES[key])
	_player.stream = _cache[key]
	_player.play()


# ---------------------------------------------------------------- synthesis

func _note_freq(theme: Dictionary, degree: int, octave: int) -> float:
	var scale: Array = theme.scale
	var n: int = degree + octave * 7
	var oct := floori(float(n) / 7.0)
	var midi: int = theme.root + scale[posmod(n, 7)] + 12 * oct
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _osc(kind: int, phase: float, duty: float) -> float:
	match kind:
		0: return 1.0 if phase < duty else -1.0           # pulse
		1: return 4.0 * absf(phase - 0.5) - 1.0           # triangle
		_: return 2.0 * phase - 1.0                       # saw


func _render(theme: Dictionary) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = theme.seed
	var prog: Array = theme.prog
	var bars := prog.size() * 2
	var step_len := int(RATE * 60.0 / theme.bpm / 2.0)  # eighth notes
	var steps := bars * 8
	var buf := PackedFloat32Array()
	buf.resize(step_len * steps)

	# Melody: a seeded random walk over the scale, favouring chord tones.
	var melody: Array = []
	var pos := 4
	for s in steps:
		var chord: int = prog[(s / 8) % prog.size()]
		if rng.randf() < 0.3 and s % 2 == 1:
			melody.append(-99)  # rest
			continue
		if s % 4 == 0:
			pos = chord + [0, 2, 4, 7][rng.randi() % 4]
		else:
			pos += [-2, -1, -1, 0, 1, 1, 2][rng.randi() % 7]
		pos = clampi(pos, -2, 11)
		melody.append(pos)

	for s in steps:
		var chord: int = prog[(s / 8) % prog.size()]
		var beat := s % 8
		var bass_f := _note_freq(theme, chord, -2)
		var arp_deg: int = chord + [0, 2, 4, 2][s % 4]
		var arp_f := _note_freq(theme, arp_deg, 0)
		var lead_deg: int = melody[s]
		var lead_f := 0.0 if lead_deg == -99 else _note_freq(theme, lead_deg, 1)
		var start := s * step_len
		for i in step_len:
			var t := float(i) / step_len
			var ts := float(start + i) / RATE
			var v := 0.0
			# bass: triangle, plays on every beat
			if beat % 2 == 0 or theme.drums:
				v += 0.45 * _osc(1, fmod(ts * bass_f, 1.0), 0.5) * (1.0 - 0.3 * t)
			# arpeggio: quiet pulse
			v += 0.12 * _osc(0, fmod(ts * arp_f, 1.0), 0.25) * exp(-3.0 * t)
			# lead: pulse with a gentle decay
			if lead_f > 0.0:
				v += 0.2 * _osc(0, fmod(ts * lead_f, 1.0), theme.lead + 0.25) * exp(-1.5 * t)
			if theme.drums:
				if beat == 0 or beat == 4:       # kick: falling sine
					var kf := 110.0 * exp(-12.0 * t) + 45.0
					v += 0.5 * sin(TAU * kf * t * 0.12) * exp(-6.0 * t)
				elif beat == 2 or beat == 6:     # snare
					v += 0.2 * (rng.randf() * 2.0 - 1.0) * exp(-14.0 * t)
				elif beat % 2 == 1:              # hat
					v += 0.06 * (rng.randf() * 2.0 - 1.0) * exp(-30.0 * t)
			buf[start + i] = v

	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buf.size()
	return wav
