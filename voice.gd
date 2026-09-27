extends Node

# Push-to-talk voice over ENet. Low quality (8kHz 16-bit PCM) but works.
# Upgrade path: swap to LiveKit native extension when laptop available.

const SAMPLE_RATE := 8000
const CHUNK_SEC := 0.25
const BUS_NAME := "VoiceCapture"

var _capture: AudioEffectCapture = null
var _bus_idx: int = -1
var _mic_player: AudioStreamPlayer = null
var _transmitting: bool = false
var _send_timer: float = 0.0
var _mic_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_bus()

func _setup_audio_bus() -> void:
	# Create/reuse dedicated mic bus (muted to speaker, feeds capture effect)
	_bus_idx = AudioServer.get_bus_index(BUS_NAME)
	if _bus_idx == -1:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, BUS_NAME)
	AudioServer.set_bus_mute(_bus_idx, true)
	# Capture effect
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(_bus_idx, _capture)
	# Mic player routed into that bus
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = BUS_NAME
	_mic_player.volume_db = 0.0
	add_child(_mic_player)
	_mic_player.play()
	print("[voice] mic bus ready (muted local monitoring)")

func set_transmitting(on: bool) -> void:
	_transmitting = on
	if not on and _capture != null:
		_capture.clear_buffer()

func _process(delta: float) -> void:
	if not _transmitting or _capture == null:
		return
	_send_timer += delta
	if _send_timer < CHUNK_SEC:
		return
	_send_timer = 0.0
	var avail := _capture.get_frames_available()
	if avail <= 0:
		return
	var frames: PackedVector2Array = _capture.get_buffer(avail)
	_capture.clear_buffer()
	var pkt := _encode(frames)
	if pkt.size() == 0:
		return
	var pid: int = NetworkManager.my_peer_id if NetworkManager != null else 0
	_rpc_voice_data.rpc(pid, pkt)

func _encode(samples: PackedVector2Array) -> PackedByteArray:
	if samples.size() == 0:
		return PackedByteArray()
	var src_rate: float = AudioServer.get_mix_rate()
	var ratio: float = src_rate / float(SAMPLE_RATE)
	var expected: int = int(samples.size() / ratio)
	if expected <= 0:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(expected * 2)
	var i: float = 0.0
	var idx: int = 0
	var n: int = samples.size()
	while int(i) < n and idx < expected:
		var s: float = (samples[int(i)].x + samples[int(i)].y) * 0.5
		var v: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		if v < 0:
			v += 65536
		out[idx * 2] = v & 0xFF
		out[idx * 2 + 1] = (v >> 8) & 0xFF
		idx += 1
		i += ratio
	out.resize(idx * 2)
	return out

@rpc("any_peer", "unreliable")
func _rpc_voice_data(peer_id: int, pkt: PackedByteArray) -> void:
	if peer_id == NetworkManager.my_peer_id:
		return
	_play_packet(pkt)

func _play_packet(pkt: PackedByteArray) -> void:
	if pkt.size() < 4:
		return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pkt
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.bus = "Master"
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
