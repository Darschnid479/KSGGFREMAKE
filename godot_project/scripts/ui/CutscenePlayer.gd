extends CanvasLayer
class_name CutscenePlayer
## Kinematisk 2.5D animert filmsekvens-spiller (oppskalerte animerte historie-sekvenser i Pixar/AAA-stil).
## Spilles automatisk ved hvert originale historie-kapittel fra start til slutt med norsk fortellertekst.

signal cutscene_finished(cutscene_id: String)

const FX_SHADER := preload("res://shaders/cutscene_fx.gdshader")

const CUTSCENES := {
	"intro_cave": {
		"chapter": "PROLOG – GRUSOMME GABRIELS GROTTE",
		"title": "Forbannelsen slippes løs",
		"image": "res://assets/cutscenes/01_cave_curse.jpg",
		"music": "cave",
		"mood": Color(0.28, 1.0, 0.68),
		"pan_from": Vector2(0.0, 0.0),
		"pan_to": Vector2(-28.0, -14.0),
		"zoom_from": 1.04,
		"zoom_to": 1.14,
		"lines": [
			"Dypt inne i Grusomme Gabriels grotte har Kaptein Sabeltann, Langemann, Pelle, Pysa og Pinky endelig funnet den sagnomsuste skattkisten.",
			"«Hiv o' hoi! Nå er Grusomme Gabriels gull vårt!» roper Kaptein Sabeltann idet lokket slås opp...",
			"Men i samme øyeblikk eksploderer kisten i grønn spøkelseståke! Tre forbannede ånder suser ut av grotten mot Gral, Fata Morgana og Maga Khans øy!",
			"Forbannelsen har rammet skatten – og bare Pinky og mannskapet på Den Sorte Dame kan bryte den!"
		],
	},
	"abra_miriam": {
		"chapter": "KAPITTEL 2 – ABRA HAVN",
		"title": "Miriams spådom i krystallkulen",
		"image": "res://assets/cutscenes/02_abra_miriam.jpg",
		"music": "abra",
		"mood": Color(1.0, 0.80, 0.36),
		"pan_from": Vector2(18.0, 0.0),
		"pan_to": Vector2(-22.0, -10.0),
		"zoom_from": 1.03,
		"zoom_to": 1.13,
		"lines": [
			"Tilbake i Abra Havn ser trollkvinnen Miriam av Gral ned i sin lysende krystallkule ved brygga.",
			"«Grusomme Gabriels forbannelse har splittet kraften i tre deler over De Syv Hav, Pinky,» hvisker Miriam.",
			"«Først må dere seile til Greven av Gral. Deretter venter ørkenbyen Fata Morgana – og til slutt Maga Khans fryktede øy!»",
			"Kaptein Sabeltann venter ved roret på Den Sorte Dame. Sett seil mot Gral!"
		],
	},
	"graal_boss": {
		"chapter": "KAPITTEL 4 – GRAL-BORGEN",
		"title": "Greven av Gral på dragen",
		"image": "res://assets/cutscenes/03_graal_dragon.jpg",
		"music": "boss",
		"mood": Color(1.0, 0.46, 0.14),
		"pan_from": Vector2(-18.0, 10.0),
		"pan_to": Vector2(20.0, -12.0),
		"zoom_from": 1.05,
		"zoom_to": 1.16,
		"lines": [
			"Etter klatreturen opp det forheksede Gral-fjellet når Pinky endelig toppen av den mørke borgen under fullmånen.",
			"Plutselig flerrer et mektig brøl gjennom stormskyene – Greven av Gral stiger opp på sin ildsprutende drage!",
			"«Ingen frekk liten sjørøver slipper levende fra borgen min!» tordner Greven av Gral over brystvernet.",
			"Bruk katapulten og våpnene dine oppe på borgen for å beseire Greven av Gral og åpne veien til Fata Morgana!"
		],
	},
	"fatamorgana_arrival": {
		"chapter": "KAPITTEL 5 – FATA MORGANA",
		"title": "Den gyldne ørkenbyen",
		"image": "res://assets/cutscenes/04_fatamorgana.jpg",
		"music": "fatamorgana",
		"mood": Color(1.0, 0.84, 0.42),
		"pan_from": Vector2(-24.0, 0.0),
		"pan_to": Vector2(24.0, -8.0),
		"zoom_from": 1.04,
		"zoom_to": 1.13,
		"lines": [
			"Med Greven av Gral beseiret seiler Den Sorte Dame inn mot de gyldne kuplene og turkise kanalene i ørkenbyen Fata Morgana.",
			"Her venter både slu basarvakter, kaketyveri, kappkjøring, det magiske flygende teppet – og sultanens voktede palass!",
			"Finn veien gjennom byen og palassets gåter for å knuse den andre delen av forbannelsen."
		],
	},
	"magakhan_dragon": {
		"chapter": "KAPITTEL 12 – MAGA KHANS FESTNING",
		"title": "Oppgjøret mot Maga Khans drage",
		"image": "res://assets/cutscenes/05_magakhan_dragon.jpg",
		"music": "boss",
		"mood": Color(1.0, 0.56, 0.16),
		"pan_from": Vector2(16.0, 8.0),
		"pan_to": Vector2(-20.0, -10.0),
		"zoom_from": 1.04,
		"zoom_to": 1.15,
		"lines": [
			"Gjennom jungelen, palasset og de brennende fangehullene har Pinky og mannskapet kjempet seg helt inn til Maga Khans indre kammer!",
			"Kaptein Sabeltann krysser klinge med selveste Maga Khan – mens en kolossal drage reiser seg i flammer bak dem!",
			"«Distraher dragen, Pinky! Så tar jeg meg av Maga Khan!» roper Kaptein Sabeltann.",
			"Beseire dragen for å åpne veien tilbake til Grusomme Gabriels grotte!"
		],
	},
	"gabriel_finale": {
		"chapter": "KAPITTEL 14 – FINALEN",
		"title": "Grusomme Gabriels spøkelse",
		"image": "res://assets/cutscenes/06_gabriel_ghost.jpg",
		"music": "boss",
		"mood": Color(0.24, 1.0, 0.62),
		"pan_from": Vector2(0.0, 14.0),
		"pan_to": Vector2(0.0, -14.0),
		"zoom_from": 1.04,
		"zoom_to": 1.16,
		"lines": [
			"Dypt nede i det innerste skattkammeret slår grønne lyn ut fra kisten – selveste Grusomme Gabriels spøkelse stiger opp!",
			"«Hvem våger å forstyrre min evige hvile og stjele mitt gull?!» gjalder det gjennom hulen idet vokterstatuene våkner.",
			"Alt står på spill! Beseire Grusomme Gabriels spøkelse og bryt forbannelsen én gang for alle!"
		],
	},
	"outro_victory": {
		"chapter": "EPILOG – FORBANNELSEN ER BRUTT!",
		"title": "Seier på De Syv Hav",
		"image": "res://assets/cutscenes/07_outro_victory.jpg",
		"music": "abra",
		"mood": Color(1.0, 0.84, 0.44),
		"pan_from": Vector2(-20.0, 6.0),
		"pan_to": Vector2(22.0, -8.0),
		"zoom_from": 1.03,
		"zoom_to": 1.13,
		"lines": [
			"Med et siste blendende lysglimt løses Grusomme Gabriels forbannelse opp for alltid!",
			"Den Sorte Dame setter alle seil og glir majestetisk ut fra spøkelsesøya i gyllent sollys mens hele mannskapet jubler på dekk.",
			"«Godt jobbet, Pinky! Du er en ekte sjørøver!» sier Kaptein Sabeltann med et stolt smil.",
			"Gratulerer – du har fullført Kaptein Sabeltann og Grusomme Gabriels forbannelse! Alle øyer og skattejakter er nå åpne for fritt spill."
		],
	},
}

var _cutscene_id: String = ""
var _cfg: Dictionary = {}
var _art_rect: TextureRect
var _fx_rect: ColorRect
var _chapter_lbl: Label
var _title_lbl: Label
var _sub_lbl: Label
var _hint_lbl: Label
var _lines: Array = []
var _line_idx: int = 0
var _elapsed: float = 0.0
var _line_timer: float = 0.0
var _active: bool = false


func play_cutscene(cutscene_id: String) -> bool:
	if not CUTSCENES.has(cutscene_id):
		return false
	_cutscene_id = cutscene_id
	_cfg = CUTSCENES[cutscene_id]
	_lines = _cfg.get("lines", [])
	_line_idx = 0
	_elapsed = 0.0
	_line_timer = 0.0
	_active = true
	layer = 40

	_build_ui()
	var music_key: String = str(_cfg.get("music", "abra"))
	AudioManager.play_music(music_key)
	_show_line(0)
	return true


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.01, 0.02, 1.0)
	root.add_child(bg)

	# Animert 2.5D filmplate (Ken Burns kamera-bevegelse)
	_art_rect = TextureRect.new()
	_art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.pivot_offset = Vector2(800.0, 450.0)
	var img_path: String = str(_cfg.get("image", ""))
	if ResourceLoader.exists(img_path):
		_art_rect.texture = load(img_path) as Texture2D
	root.add_child(_art_rect)

	# Sanntids animerte lyspartikler, glød & film-vignette
	_fx_rect = ColorRect.new()
	_fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := ShaderMaterial.new()
	sh.shader = FX_SHADER
	sh.set_shader_parameter("mood_color", _cfg.get("mood", Color(1.0, 0.82, 0.42)))
	sh.set_shader_parameter("vignette_strength", 0.44)
	sh.set_shader_parameter("shimmer_strength", 0.24)
	_fx_rect.material = sh
	root.add_child(_fx_rect)

	# Kinematiske 2.39:1 sorte filmstriper oppe og nede
	var top_bar := ColorRect.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 86
	top_bar.color = Color(0.02, 0.02, 0.03, 0.94)
	root.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = -148
	bot_bar.color = Color(0.02, 0.02, 0.03, 0.95)
	root.add_child(bot_bar)

	# Kapittel-overskrift i toppstripen
	var top_vb := VBoxContainer.new()
	top_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_vb)

	_chapter_lbl = Label.new()
	_chapter_lbl.text = str(_cfg.get("chapter", ""))
	_chapter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_lbl.add_theme_font_size_override("font_size", 14)
	_chapter_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.34))
	top_vb.add_child(_chapter_lbl)

	_title_lbl = Label.new()
	_title_lbl.text = str(_cfg.get("title", ""))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 26)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	top_vb.add_child(_title_lbl)

	# Fortellertekst og hopp-over-knapp i bunnstripen
	var bot_margin := MarginContainer.new()
	bot_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	bot_margin.add_theme_constant_override("margin_left", 90)
	bot_margin.add_theme_constant_override("margin_right", 90)
	bot_margin.add_theme_constant_override("margin_top", 18)
	bot_margin.add_theme_constant_override("margin_bottom", 14)
	bot_bar.add_child(bot_margin)

	var bvb := VBoxContainer.new()
	bvb.alignment = BoxContainer.ALIGNMENT_CENTER
	bvb.add_theme_constant_override("separation", 10)
	bot_margin.add_child(bvb)

	_sub_lbl = Label.new()
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.add_theme_font_size_override("font_size", 21)
	_sub_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	bvb.add_child(_sub_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.text = "[Mellomrom / Klikk] Neste   •   [ESC] Hopp over filmsekvens"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 13)
	_hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.54, 0.85))
	bvb.add_child(_hint_lbl)


func _show_line(idx: int) -> void:
	if idx >= _lines.size():
		_finish()
		return
	_line_idx = idx
	_line_timer = 0.0
	if is_instance_valid(_sub_lbl):
		_sub_lbl.text = str(_lines[idx])


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_line_timer += delta

	# Myk 60 FPS Ken Burns kamera-panorering og zoom
	if is_instance_valid(_art_rect):
		var vp_size := get_viewport().get_visible_rect().size
		_art_rect.pivot_offset = vp_size * 0.5
		var total_dur := maxf(float(_lines.size()) * 5.8, 12.0)
		var t := clampf(_elapsed / total_dur, 0.0, 1.0)
		var ease_t := t * t * (3.0 - 2.0 * t)
		var z0: float = float(_cfg.get("zoom_from", 1.04))
		var z1: float = float(_cfg.get("zoom_to", 1.14))
		var sc := lerpf(z0, z1, ease_t)
		_art_rect.scale = Vector2(sc, sc)
		var p0: Vector2 = _cfg.get("pan_from", Vector2.ZERO)
		var p1: Vector2 = _cfg.get("pan_to", Vector2.ZERO)
		_art_rect.position = p0.lerp(p1, ease_t)

	# Auto-avansering etter 6.5 sekunder per replikk
	if _line_timer >= 6.5:
		_show_line(_line_idx + 1)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_finish()
		elif kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_E:
			get_viewport().set_input_as_handled()
			_show_line(_line_idx + 1)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_show_line(_line_idx + 1)


func _finish() -> void:
	if not _active:
		return
	_active = false
	var done_id := _cutscene_id
	emit_signal("cutscene_finished", done_id)
	queue_free()
