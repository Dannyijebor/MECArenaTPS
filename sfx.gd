extends RefCounted

const _PATHS := {
	"shoot":           "res://sounds/shoot.wav",
	"enemy_shoot":     "res://sounds/enemy_shoot.wav",
	"hit":             "res://sounds/hit.wav",
	"hurt":            "res://sounds/hurt.wav",
	"reload":          "res://sounds/reload.wav",
	"wave_start":      "res://sounds/wave_start.wav",
	"empty":           "res://sounds/empty.wav",
	"footstep":        "res://sounds/footstep.wav",
	"ambient_hum":     "res://sounds/ambient_hum.wav",
	"ambient_music":   "res://sounds/ambient_music.ogg",
	"distant_gunfire": "res://sounds/distant_gunfire.wav",
	"wave_clear":      "res://sounds/wave_clear.wav",
}

static var _music_player: AudioStreamPlayer = null

static func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var path: String = _PATHS.get(sound_name, "")
	if path == "":
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	tree.root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

static func play_music(volume_db: float = -12.0) -> void:
	if _music_player != null and _music_player.playing:
		return
	var stream: AudioStream = load(_PATHS["ambient_music"])
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.bus = "Master"
	tree.root.add_child(_music_player)
	_music_player.play()

static func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.queue_free()
		_music_player = null

static func play_footstep() -> void:
	play("footstep", -6.0, randf_range(0.92, 1.08))
