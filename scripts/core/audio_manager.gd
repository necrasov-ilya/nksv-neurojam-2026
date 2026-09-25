class_name JamAudioManager
extends Node

const TEST_CLICK: AudioStream = preload("res://assets/audio/test_click.wav")

var music_player: AudioStreamPlayer
var effects_players: Array[AudioStreamPlayer] = []
var muted := false
var next_effect_index := 0


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = -8.0
	for index in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		effects_players.append(player)


func play_test_click() -> void:
	play_effect(TEST_CLICK)


func play_effect(sound: AudioStream) -> void:
	if muted:
		return
	var player := effects_players[next_effect_index]
	for candidate in effects_players:
		if not candidate.playing:
			player = candidate
			break
	next_effect_index = (next_effect_index + 1) % effects_players.size()
	player.stream = sound
	player.play()


func set_music(track: AudioStream) -> void:
	music_player.stop()
	music_player.stream = track
	if track != null and not muted:
		music_player.play()


func set_muted(value: bool) -> void:
	muted = value
	music_player.stream_paused = value
	for player in effects_players:
		player.stream_paused = value
	if not value and music_player.stream != null and not music_player.playing:
		music_player.play()
