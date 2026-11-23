extends Node
## Lyd-, musikk-, miljølyd- og 1:1 stemmesystem (Norske karakterstemmer + valgfri original CD-tale).

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _dialogues: Dictionary = {}
var _current_track: String = ""
var _current_ambience: String = ""
var _current_voice_key: String = ""
var _voice_done_cb: Callable
var _voice_fallback_timer: float = 0.0
var _base_music_db: float = -10.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = _base_music_db
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = -14.0
	add_child(_ambience_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.volume_db = 0.0
	_voice_player.finished.connect(_on_voice_finished)
	add_child(_voice_player)

	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)

	_scan_extracted_audio()
	_load_dialogues()


func _process(delta: float) -> void:
	var target_db := _base_music_db - 8.0 if is_voice_playing() else _base_music_db
	_music_player.volume_db = lerpf(_music_player.volume_db, target_db, clampf(delta * 6.0, 0.0, 1.0))
	if _voice_fallback_timer > 0.0:
		_voice_fallback_timer -= delta
		if _voice_fallback_timer <= 0.0:
			_finish_current_voice()


func _scan_extracted_audio() -> void:
	var audio_dir := "res://assets/audio"
	var entries: PackedStringArray = []
	if ResourceLoader.has_method("list_directory"):
		entries = ResourceLoader.list_directory(audio_dir)
	if entries.is_empty():
		var dir := DirAccess.open(audio_dir)
		if dir:
			dir.list_dir_begin()
			var f := dir.get_next()
			while f != "":
				if not dir.current_is_dir():
					entries.append(f)
				f = dir.get_next()
			dir.list_dir_end()
	for fname in entries:
		if fname.ends_with("/") or fname.ends_with(".uid"):
			continue
		var clean := fname.replace(".import", "").replace(".remap", "")
		if clean.ends_with(".wav") or clean.ends_with(".ogg") or clean.ends_with(".mp3"):
			var key := clean.get_basename().to_lower()
			_sfx_cache[key] = audio_dir + "/" + clean


func _load_dialogues() -> void:
	var path := "res://data/dialogues.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_dialogues = parsed


func is_voice_playing() -> bool:
	return _voice_player.playing or _voice_fallback_timer > 0.0


func get_dialogue_info(clip_key: String) -> Dictionary:
	return _dialogues.get(clip_key.to_lower(), {})


## Replikerer originalspillets conversation.ls: finner alle nummererte replikker "<conv>_1_<taler>", "<conv>_2_<taler>" osv.!
func get_conversation_clips(conv_name: String) -> Array[String]:
	var low := conv_name.to_lower().strip_edges()
	var out: Array[String] = []
	for i in range(1, 22):
		var prefix := "%s_%d_" % [low, i]
		var found := ""
		for k in _dialogues.keys():
			if str(k).begins_with(prefix):
				found = str(k)
				break
		if found != "":
			out.append(found)
		elif i > 3 and out.is_empty():
			break
		elif not out.is_empty() and found == "":
			break
	if out.is_empty() and _dialogues.has(low):
		out.append(low)
	return out


func play_voice(clip_key: String, on_done: Callable = Callable()) -> Dictionary:
	stop_voice(false)
	var key := clip_key.to_lower().strip_edges()
	var info: Dictionary = _dialogues.get(key, {})
	var sp_name := str(info.get("speaker_name", "Kaptein Sabeltann"))
	var text := str(info.get("text", ""))
	_current_voice_key = key
	_voice_done_cb = on_done

	var primary_dir := "res://assets/voices_no" if GameState.voice_language == "no" else "res://assets/voices_orig"
	var fallback_dir := "res://assets/voices_orig" if GameState.voice_language == "no" else "res://assets/voices_no"
	var vpath := "%s/%s.ogg" % [primary_dir, key]
	if not ResourceLoader.exists(vpath):
		vpath = "%s/%s.ogg" % [fallback_dir, key]

	if text != "":
		GameState.emit_signal("voice_line_started", sp_name, text, key)

	if ResourceLoader.exists(vpath):
		var stream := load(vpath) as AudioStream
		if stream:
			if stream is AudioStreamOggVorbis:
				stream.loop = false
			_voice_player.stream = stream
			_voice_player.play()
			return info

	# Fallback hvis ingen lydfil finnes (viser undertekst i passelig lesetid)
	_voice_fallback_timer = clampf(float(text.length()) * 0.055, 2.0, 5.5) if text != "" else 0.1
	return info


func skip_current_voice() -> void:
	if is_voice_playing():
		_finish_current_voice()


func stop_voice(trigger_cb: bool = false) -> void:
	_voice_fallback_timer = 0.0
	if _voice_player.playing:
		_voice_player.stop()
	var prev_key := _current_voice_key
	var cb := _voice_done_cb
	_current_voice_key = ""
	_voice_done_cb = Callable()
	if prev_key != "":
		GameState.emit_signal("voice_line_finished", prev_key)
	if trigger_cb and cb.is_valid():
		cb.call()


func _on_voice_finished() -> void:
	_finish_current_voice()


func _finish_current_voice() -> void:
	_voice_fallback_timer = 0.0
	if _voice_player.playing:
		_voice_player.stop()
	var done_key := _current_voice_key
	var cb := _voice_done_cb
	_current_voice_key = ""
	_voice_done_cb = Callable()
	if done_key != "":
		GameState.emit_signal("voice_line_finished", done_key)
	if cb.is_valid():
		cb.call()


func play_music(biome_key: String) -> void:
	if _current_track == biome_key and _music_player.playing:
		return
	_current_track = biome_key
	var b := biome_key.to_lower()
	var best_path := ""
	for k in _sfx_cache.keys():
		if b in k and "music" in k:
			best_path = _sfx_cache[k]
			break
	if best_path == "":
		for k in _sfx_cache.keys():
			if b in k and ("theme" in k or "loop" in k):
				best_path = _sfx_cache[k]
				break
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


func play_ambience(amb_key: String) -> void:
	var b := amb_key.to_lower()
	if _current_ambience == b and _ambience_player.playing:
		return
	_current_ambience = b
	var best_path := ""
	for k in _sfx_cache.keys():
		if b in k:
			best_path = _sfx_cache[k]
			break
	if best_path != "":
		var stream := load(best_path)
		if stream:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			_ambience_player.stream = stream
			_ambience_player.play()


func play_sfx(sfx_name: String, pitch_jitter: float = 0.08) -> void:
	var low := sfx_name.to_lower()
	var stream: AudioStream = null

	if _sfx_cache.has(low):
		stream = load(_sfx_cache[low])
	else:
		for k in _sfx_cache.keys():
			if low in k:
				stream = load(_sfx_cache[k])
				break

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
		"slingshot":
			dur = 0.14; freq = 520.0; sweep = -260.0; noise_mix = 0.25
		"cannon":
			dur = 0.36; freq = 95.0; sweep = -65.0; noise_mix = 0.85
		"barrel", "break":
			dur = 0.24; freq = 160.0; sweep = -95.0; noise_mix = 0.75
		"step":
			dur = 0.07; freq = 110.0; sweep = -40.0; noise_mix = 0.80
		"portal":
			dur = 0.35; freq = 360.0; sweep = 440.0
		_:
			dur = 0.12; freq = 660.0; sweep = 180.0

	var samples := int(sr * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := (1.0 - t) * (1.0 - t)
		var f := maxf(40.0, freq + sweep * t)
		phase += TAU * f / float(sr)
		var s := sin(phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		var v := clampi(int(s * env * 22000.0), -32767, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = data
	return wav
