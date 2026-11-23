extends Node
## Lyd- og musikksystem (spiller både ekstraherte original-lyder og prosedyregenererte SFX-fallback).

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _current_track: String = ""
var master_volume_db: float = -4.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -10.0
	add_child(_music_player)

	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)

	_scan_extracted_audio()


func _scan_extracted_audio() -> void:
	var audio_dir := "res://assets/audio"
	var dir := DirAccess.open(audio_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean := fname.replace(".import", "")
			if clean.ends_with(".wav") or clean.ends_with(".ogg") or clean.ends_with(".mp3"):
				var key := clean.get_basename().to_lower()
				_sfx_cache[key] = audio_dir + "/" + clean
		fname = dir.get_next()
	dir.list_dir_end()


func play_music(biome_key: String) -> void:
	if _current_track == biome_key and _music_player.playing:
		return
	_current_track = biome_key
	var b := biome_key.to_lower()
	var best_path := ""
	# 1. Eksakt biome + music
	for k in _sfx_cache.keys():
		if b in k and "music" in k:
			best_path = _sfx_cache[k]
			break
	# 2. Biome + ambience / loop
	if best_path == "":
		for k in _sfx_cache.keys():
			if b in k and ("amb" in k or "theme" in k or "loop" in k):
				best_path = _sfx_cache[k]
				break
	# 3. Fallback til hovedtema (Abra Havn eller dungeon for boss)
	if best_path == "":
		var fallback := "dungeon" if b == "boss" else "abra"
		for k in _sfx_cache.keys():
			if fallback in k and "music" in k:
				best_path = _sfx_cache[k]
				break
	if best_path != "":
		var stream := load(best_path)
		if stream:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			_music_player.stream = stream
			_music_player.play()


func play_sfx(sfx_name: String, pitch_jitter: float = 0.08) -> void:
	var low := sfx_name.to_lower()
	var stream: AudioStream = null

	# 1. Prøv eksakt eller delvis match fra originale ekstraherte lyder
	if _sfx_cache.has(low):
		stream = load(_sfx_cache[low])
	else:
		for k in _sfx_cache.keys():
			if low in k:
				stream = load(_sfx_cache[k])
				break

	# 2. Fallback: generer ren syntetisk pirat-lyd i minnet slik at spillet aldri er lydløst
	if stream == null:
		stream = _make_procedural_sfx(low)

	if stream == null:
		return

	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
			p.play()
			return
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func _make_procedural_sfx(kind: String) -> AudioStreamWAV:
	var sr := 22050
	var dur := 0.14
	var freq := 440.0
	var sweep := 0.0
	var noise_mix := 0.0

	match kind:
		"coin":
			dur = 0.18; freq = 980.0; sweep = 420.0
		"sword", "swoosh":
			dur = 0.16; freq = 260.0; sweep = -180.0; noise_mix = 0.65
		"hit":
			dur = 0.15; freq = 140.0; sweep = -90.0; noise_mix = 0.55
		"jump":
			dur = 0.16; freq = 220.0; sweep = 260.0
		"cannon":
			dur = 0.42; freq = 85.0; sweep = -55.0; noise_mix = 0.85
		"slingshot":
			dur = 0.12; freq = 520.0; sweep = -280.0; noise_mix = 0.25
		"portal":
			dur = 0.45; freq = 340.0; sweep = 520.0
		"pickup":
			dur = 0.22; freq = 520.0; sweep = 360.0
		_:
			dur = 0.10; freq = 360.0; sweep = 60.0

	var samples := int(sr * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 1.8) * minf(1.0, t * 25.0)
		var cur_f: float = maxf(30.0, freq + sweep * t)
		phase += TAU * cur_f / float(sr)
		var tone: float = sin(phase)
		var n: float = randf_range(-1.0, 1.0)
		var val: float = clampf((tone * (1.0 - noise_mix) + n * noise_mix) * env * 0.45, -1.0, 1.0)
		var s16 := int(val * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = data
	return wav
