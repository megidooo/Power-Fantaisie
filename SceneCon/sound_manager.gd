extends Node

# Attach two AudioStreamPlayer nodes in the scene tree named:
# "IntroPlayer" and "LoopPlayer"

@onready var intro_player: AudioStreamPlayer = $IntroPlayer
@onready var loop_player: AudioStreamPlayer = $LoopPlayer

@export var intro_stream: AudioStream   # Assign your intro audio file here
@export var loop_stream: AudioStream    # Assign your loop audio file here

func _ready() -> void:
	# Configure the loop player to loop
	var playback_settings = loop_stream as AudioStreamOggVorbis
	if playback_settings:
		playback_settings.loop = true

	intro_player.stream = intro_stream
	loop_player.stream = loop_stream

	# Connect the signal so the loop starts exactly when the intro ends
	intro_player.finished.connect(_on_intro_finished)

	play_music()

func play_music() -> void:
	intro_player.play()

func _on_intro_finished() -> void:
	loop_player.play()

func stop_music() -> void:
	intro_player.stop()
	loop_player.stop()
