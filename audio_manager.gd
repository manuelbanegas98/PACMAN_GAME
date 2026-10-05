extends Node
class_name GameAudioManager

var player: AudioStreamPlayer
var sounds: Dictionary = {}


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -8.0
	add_child(player)
	sounds[&"collect"] = _make_tone(760.0, 0.075)
	sounds[&"power"] = _make_tone(440.0, 0.28)
	sounds[&"catch"] = _make_tone(300.0, 0.16)
	sounds[&"hit"] = _make_tone(115.0, 0.36)


func play_effect(effect: StringName) -> void:
	if not sounds.has(effect):
		return
	player.stream = sounds[effect]
	player.play()


func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for index in range(sample_count):
		var fade := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * frequency * float(index) / float(SAMPLE_RATE)) * fade * 10000.0)
		pcm.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	return stream