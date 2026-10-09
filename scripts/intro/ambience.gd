extends Node
## Intro soundscape built from real CC0 field recordings (see assets/SOURCES.md,
## "Звуки вступления"). Three stereo beds crossfade per location; the street also
## gets positional emitters (traffic, cafe, bus stop, intersection, plaza) and calm
## distant one-shots. Nothing plays until the first set_location call, which the
## parent makes only after a user gesture (browser autoplay rule).

const DIR := "res://assets/audio/intro/"
const LOCATIONS: Array[String] = ["street", "lobby", "office"]
const BEDS := {
	"street": preload(DIR + "street_bed.ogg"),
	"lobby": preload(DIR + "lobby_bed.ogg"),
	"office": preload(DIR + "office_bed.ogg"),
}
const BED_LEVELS := {"street": -6.0, "lobby": -7.0, "office": -9.0}
const FADE_SECONDS := 1.4

const STEPS := {
	"street": [
		preload(DIR + "step_street_1.wav"), preload(DIR + "step_street_2.wav"),
		preload(DIR + "step_street_3.wav"), preload(DIR + "step_street_4.wav"),
		preload(DIR + "step_street_5.wav"), preload(DIR + "step_street_6.wav"),
		preload(DIR + "step_street_7.wav"), preload(DIR + "step_street_8.wav"),
	],
	"lobby": [
		preload(DIR + "step_lobby_1.wav"), preload(DIR + "step_lobby_2.wav"),
		preload(DIR + "step_lobby_3.wav"), preload(DIR + "step_lobby_4.wav"),
		preload(DIR + "step_lobby_5.wav"), preload(DIR + "step_lobby_6.wav"),
		preload(DIR + "step_lobby_7.wav"), preload(DIR + "step_lobby_8.wav"),
	],
	"office": [
		preload(DIR + "step_office_1.wav"), preload(DIR + "step_office_2.wav"),
		preload(DIR + "step_office_3.wav"), preload(DIR + "step_office_4.wav"),
		preload(DIR + "step_office_5.wav"), preload(DIR + "step_office_6.wav"),
		preload(DIR + "step_office_7.wav"), preload(DIR + "step_office_8.wav"),
	],
}
const STEP_LEVELS := {"street": -11.0, "lobby": -12.0, "office": -14.0}

## name -> [stream, volume_db]
const EVENTS := {
	"entrance_door": [preload(DIR + "entrance_door.wav"), -8.0],
	"lift_doors": [preload(DIR + "lift_doors.wav"), -9.0],
	"lift_ding": [preload(DIR + "lift_ding.wav"), -11.0],
	"lift_travel": [preload(DIR + "lift_travel.ogg"), -8.0],
	"office_door_open": [preload(DIR + "office_door_open.wav"), -8.0],
	"office_door_close": [preload(DIR + "office_door_close.wav"), -8.0],
	"ui_click": [preload(DIR + "ui_click.wav"), -12.0],
	"ui_wrong": [preload(DIR + "ui_wrong.wav"), -11.0],
	"computer_start": [preload(DIR + "computer_start.wav"), -9.0],
}

const CAR_LOOP: AudioStream = preload(DIR + "car_loop.ogg")
## [stream, position, volume_db, unit_size, max_distance]
const CITY_EMITTERS := [
	[preload(DIR + "cafe_loop.ogg"), Vector3(22, 1, 75), -4.0, 6.0, 38.0],
	[preload(DIR + "bus_idle.ogg"), Vector3(18, 1, 108), -9.0, 5.0, 40.0],
	[preload(DIR + "intersection_loop.ogg"), Vector3(0, 1, -80), -5.0, 12.0, 90.0],
	[preload(DIR + "plaza_loop.ogg"), Vector3(148, 1, -80), -5.0, 14.0, 60.0],
]
const DISTANT_ONESHOTS := [
	preload(DIR + "street_bell_1.wav"), preload(DIR + "street_bell_2.wav"),
	preload(DIR + "street_laugh.wav"), preload(DIR + "street_door.wav"),
]

# Optional parent trim; all players also obey the Master bus.
var volume_db := 0.0

var _beds: Array[AudioStreamPlayer] = []
var _bed_levels := PackedFloat32Array([0.0, 0.0, 0.0])
var _effects: Array[AudioStreamPlayer] = []
var _emitters: Array[AudioStreamPlayer3D] = []
var _distant: AudioStreamPlayer3D
var _location_index := 0
var _started := false
var _muted := false
var _effect_index := 0
var _last_step := -1
var _last_oneshot := -1
var _oneshot_timer := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_muted = not GameSettings.sound_enabled
	for location in LOCATIONS:
		var stream: AudioStreamOggVorbis = BEDS[location]
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		_beds.append(player)
	for i in 6:
		var effect := AudioStreamPlayer.new()
		add_child(effect)
		_effects.append(effect)
	set_process(false)

## Called once after city.build(); emitters stay silent until street is active.
func attach_city(city_root: Node3D) -> void:
	for i in 2:
		var car := city_root.get_node_or_null("GentleTraffic%d" % i) as Node3D
		if car == null:
			continue
		_emitters.append(_make_emitter(car, CAR_LOOP, Vector3(0, 0.7, 0), -3.0, 7.0, 55.0, 0.93 + 0.1 * i))
	for spec: Array in CITY_EMITTERS:
		_emitters.append(_make_emitter(city_root, spec[0], spec[1], spec[2], spec[3], spec[4], 1.0))
	_distant = AudioStreamPlayer3D.new()
	_distant.name = "DistantOneShot"
	_distant.unit_size = 10.0
	_distant.max_distance = 80.0
	_distant.attenuation_filter_cutoff_hz = 9000.0
	city_root.add_child(_distant)
	if _started and not _muted:
		_sync_emitters()

func _make_emitter(parent: Node3D, stream: AudioStream, offset: Vector3, level: float, unit: float, max_dist: float, pitch: float) -> AudioStreamPlayer3D:
	var ogg := stream as AudioStreamOggVorbis
	if ogg:
		ogg.loop = true
	var emitter := AudioStreamPlayer3D.new()
	emitter.stream = stream
	emitter.position = offset
	emitter.volume_db = level + volume_db
	emitter.unit_size = unit
	emitter.max_distance = max_dist
	emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	emitter.attenuation_filter_cutoff_hz = 6000.0
	emitter.attenuation_filter_db = -18.0
	emitter.pitch_scale = pitch
	parent.add_child(emitter)
	return emitter

func set_location(location: String) -> void:
	var index := LOCATIONS.find(location)
	if index < 0:
		return
	_location_index = index
	_started = true
	_oneshot_timer = _rng.randf_range(6.0, 12.0)
	if not _muted:
		var bed := _beds[index]
		if not bed.playing:
			bed.play(_rng.randf_range(0.0, maxf(bed.stream.get_length() - 1.0, 0.0)))
		_sync_emitters()
	set_process(true)

func set_muted(value: bool) -> void:
	_muted = value
	if value:
		for bed in _beds:
			bed.stop()
		for i in _bed_levels.size():
			_bed_levels[i] = 0.0
		for effect in _effects:
			effect.stop()
		for emitter in _emitters:
			emitter.stop()
		if _distant:
			_distant.stop()
		set_process(false)
	elif _started:
		set_location(LOCATIONS[_location_index])

func footstep() -> void:
	if _muted or not _started:
		return
	var location: String = LOCATIONS[_location_index]
	var variants: Array = STEPS[location]
	var index := _rng.randi_range(0, variants.size() - 2)
	if index >= _last_step:
		index += 1
	_last_step = index
	_play_effect(variants[index], float(STEP_LEVELS[location]) + _rng.randf_range(-2.0, 2.0), _rng.randf_range(0.96, 1.04))

func play_event(event_name: String) -> void:
	if _muted or not _started or not EVENTS.has(event_name):
		return
	var spec: Array = EVENTS[event_name]
	_play_effect(spec[0], spec[1], 1.0)

func _play_effect(stream: AudioStream, level: float, pitch: float) -> void:
	var player := _effects[_effect_index]
	for candidate in _effects:
		if not candidate.playing:
			player = candidate
			break
	_effect_index = (_effect_index + 1) % _effects.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = level + volume_db
	player.play()

func _sync_emitters() -> void:
	var on_street := _location_index == 0
	for emitter in _emitters:
		if on_street and not emitter.playing:
			emitter.play(_rng.randf_range(0.0, maxf(emitter.stream.get_length() - 1.0, 0.0)))
		elif not on_street and emitter.playing:
			emitter.stop()
	if not on_street and _distant:
		_distant.stop()

func _play_distant() -> void:
	var camera := get_viewport().get_camera_3d()
	if _distant == null or camera == null:
		return
	var index := _rng.randi_range(0, DISTANT_ONESHOTS.size() - 2)
	if index >= _last_oneshot:
		index += 1
	_last_oneshot = index
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(14.0, 28.0)
	_distant.global_position = camera.global_position + Vector3(cos(angle) * distance, 0.5, sin(angle) * distance)
	_distant.stream = DISTANT_ONESHOTS[index]
	_distant.volume_db = _rng.randf_range(-6.0, -2.0) + volume_db
	_distant.pitch_scale = _rng.randf_range(0.97, 1.03)
	_distant.play()

func _process(delta: float) -> void:
	for i in _beds.size():
		var bed := _beds[i]
		var target := 1.0 if i == _location_index else 0.0
		var level := move_toward(_bed_levels[i], target, delta / FADE_SECONDS)
		_bed_levels[i] = level
		bed.volume_db = linear_to_db(maxf(level, 0.0001)) + float(BED_LEVELS[LOCATIONS[i]]) + volume_db
		if target == 0.0 and level <= 0.0 and bed.playing:
			bed.stop()
	if _location_index == 0:
		_oneshot_timer -= delta
		if _oneshot_timer <= 0.0:
			_oneshot_timer = _rng.randf_range(6.0, 20.0)
			_play_distant()
