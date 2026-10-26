extends Node

var bank: Dictionary = {}
var voices: Array = []
var voice_index = 0

func _ready():
	for i in range(8):
		var player = AudioStreamPlayer.new(); player.volume_db = -12; add_child(player); voices.append(player)
	for kind in ["shot","melee","hurt","reload","alarm"]:
		bank[kind] = synth(kind)

func synth(kind: String) -> AudioStreamWAV:
	var length = 0.13 if kind != "alarm" else 0.45
	var rate = 22050
	var bytes = PackedByteArray(); bytes.resize(int(length * rate) * 2)
	var rng = RandomNumberGenerator.new(); rng.seed = 712
	for i in range(bytes.size() / 2):
		var t = float(i) / rate; var fade = pow(1.0 - t / length,3)
		var value = 0.0
		match kind:
			"shot": value = (rng.randf_range(-1,1) * 0.7 + sin(t * TAU * (130 - 70 * t / length)) * 0.3) * fade
			"melee": value = rng.randf_range(-1,1) * fade * 0.4
			"hurt": value = sin(t * TAU * (190 - 120 * t / length)) * fade * 0.6
			"reload": value = (1.0 if sin(t * TAU * 1400) > 0 else -1.0) * fade * 0.16
			"alarm": value = sin(t * TAU * (550 if t < 0.22 else 750)) * fade * 0.25
		bytes.encode_s16(i * 2,int(clampf(value,-1,1) * 26000))
	var stream = AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = rate; stream.data = bytes
	return stream

func play(kind: String):
	if not bank.has(kind): return
	var voice = voices[voice_index]; voice_index = (voice_index + 1) % voices.size()
	voice.stream = bank[kind]; voice.play()

func _exit_tree():
	for voice in voices:
		voice.stop(); voice.stream = null
	bank.clear(); voices.clear()
