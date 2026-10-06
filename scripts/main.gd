extends Node3D

@onready var session: SessionState = $SessionState
@onready var input_manager: JamInputManager = $InputManager
@onready var camera_rig: JamCameraManager = $CameraRig
@onready var world: WorldManager = $World
@onready var audio_manager: JamAudioManager = $AudioManager
@onready var effect_pool: ObjectPool = $EffectPool
@onready var hud: DebugHud = $DebugHud
@onready var orientation_guard: OrientationGuard = $OrientationGuard

var _paused_by_orientation := false
var _pending_start := false


func _ready() -> void:
	hud.start_requested.connect(_on_start)
	hud.pause_requested.connect(_on_pause)
	hud.seed_requested.connect(_on_new_seed)
	hud.pulse_requested.connect(_spawn_pulse)
	hud.mute_requested.connect(_on_mute)
	session.phase_changed.connect(hud.set_phase)
	hud.set_phase(session.phase)
	hud.set_seed(world.seed_value)
	audio_manager.set_muted(not GameSettings.sound_enabled)
	orientation_guard.landscape_changed.connect(_on_landscape_changed)
	if orientation_guard.is_landscape():
		session.start()
	else:
		_pending_start = true


func _process(_delta: float) -> void:
	if input_manager.pause_pressed():
		_on_pause()
	if session.phase == SessionState.Phase.RUNNING and input_manager.debug_pressed():
		_spawn_pulse()


func _on_start() -> void:
	session.start()
	audio_manager.play_test_click()


func _on_pause() -> void:
	if session.phase == SessionState.Phase.RUNNING:
		session.pause()
	else:
		session.start()


func _on_new_seed() -> void:
	world.regenerate(world.seed_value + 1)
	hud.set_seed(world.seed_value)


func _spawn_pulse() -> void:
	if session.phase != SessionState.Phase.RUNNING:
		return
	var pulse := effect_pool.acquire() as DebugPulse
	pulse.activate(camera_rig.global_position + Vector3(0, 0.7, 0))
	audio_manager.play_test_click()


func _on_mute(value: bool) -> void:
	audio_manager.set_muted(value)


func _on_landscape_changed(is_landscape: bool) -> void:
	if not is_landscape:
		if session.phase == SessionState.Phase.RUNNING:
			session.pause()
			_paused_by_orientation = true
		return
	if _paused_by_orientation:
		_paused_by_orientation = false
		session.start()
	elif _pending_start:
		_pending_start = false
		session.start()

