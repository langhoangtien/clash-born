class_name MatchAudioRouter
extends Node
## Presentation-only sound router. It consumes resolved combat events and never
## feeds a decision back into the deterministic simulation.

const VOICE_COUNT := 8
const SOUND_LIBRARY := "res://sound_library/"

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var streams := {}
var last_tick := {}
var variation := {}

var sounds := {
	"melee": PackedStringArray(["sword-1.ogg", "axe.ogg"]),
	"ranged": PackedStringArray(["bow.ogg", "crossbow.ogg"]),
	"siege": PackedStringArray(["sling.ogg", "sling-big.ogg"]),
	"magic": PackedStringArray(["magic-missile-1.ogg", "lightning.ogg"]),
	"impact": PackedStringArray(["human-hit-1.ogg", "human-hit-2.ogg", "human-hit-3.ogg"]),
	"death": PackedStringArray(["human-die-1.ogg", "human-die-2.ogg", "orc-die-1.ogg"]),
	"wave": PackedStringArray(["horn-signals/horn-1.ogg"]),
	"heal": PackedStringArray(["potion.ogg"]),
}

const COOLDOWN_TICKS := {"melee": 3, "ranged": 3, "siege": 5, "magic": 5, "impact": 2, "death": 8, "wave": 90, "heal": 30}

func _ready() -> void:
	for _index in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12.0
		add_child(voice)
		voices.append(voice)

func consume(events: Array[Dictionary], entities: Dictionary, tick: int) -> void:
	if not enabled: return
	for event in events:
		match event.get("kind", ""):
			"attack": _play(_attack_sound(event.get("source_unit_id", ""), entities), tick)
			"damage":
				if event.get("applied_damage", 0.0) > 0: _play("magic" if event.get("damage_type", 0) == DamageCalculator.DamageType.MAGICAL else "impact", tick)
			"death": _play("death", tick)
			"heal": _play("heal", tick)

func play_wave(tick: int) -> void:
	_play("wave", tick)

func _attack_sound(source_id: String, entities: Dictionary) -> String:
	var info: Dictionary = entities.get(source_id, {})
	if info.get("siege", false): return "siege"
	var actor: MapUnit = info.get("actor")
	if actor == null: return "melee"
	if actor.runtime.stats.get("magic_damage", 0.0) > 0.0: return "magic"
	return "ranged" if actor.runtime.stats.get("ranged_attacks", false) else "melee"

func _play(key: String, tick: int) -> void:
	if tick - int(last_tick.get(key, -1000000)) < int(COOLDOWN_TICKS.get(key, 1)): return
	var choices: PackedStringArray = sounds.get(key, PackedStringArray())
	if choices.is_empty(): return
	last_tick[key] = tick
	var index: int = int(variation.get(key, 0)) % choices.size()
	variation[key] = index + 1
	var path := SOUND_LIBRARY + choices[index]
	var stream: AudioStream = streams.get(path)
	if stream == null:
		var file_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(file_path): return
		# Direct OGG decoding avoids importing or duplicating the whole sound library.
		stream = AudioStreamOggVorbis.load_from_file(file_path)
		if stream == null: return
		streams[path] = stream
	var voice := _available_voice()
	voice.stream = stream
	voice.play()

func _available_voice() -> AudioStreamPlayer:
	for voice in voices:
		if not voice.playing: return voice
	var voice := voices[0]
	voice.stop()
	return voice
