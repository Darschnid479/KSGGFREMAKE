extends StaticBody3D
class_name NpcActor
## Interaktiv NPC (Kaptein Sabeltann, Langemann, Sunniva, Pelle, Skalken, Miriam osv.) med norsk dialog.

@export var npc_id: String = "sabeltann"
@export var display_name: String = "Kaptein Sabeltann"
@export var model_resource: String = "sabeltann"
@export var dialogue_lines: Array[String] = []
@export var reward_coins: int = 0

var _visual: Node3D
var _bob_t: float = 0.0
var _talked: bool = false

const DEFAULT_DIALOGUES := {
	"sabeltann": [
		"Hiv o' hoi, Pinky! Grusomme Gabriels forbannelse hviler over skatten vår!",
		"Bruk sverdet (venstreklikk) og spretterten (tast 5) mot fiendene, og hold øye med gullmyntene!",
		"Når du er klar, gå til portalen ved Den Sorte Dame for å seile ut på De Syv Hav!"
	],
	"langemann": [
		"Hei Pinky! Jeg holder utkikk fra brygga i Abra Havn.",
		"Knus tønner og kister for å finne skjulte gullmynter og friske epler!"
	],
	"sunniva": [
		"Pinky! Pass deg for skjelettene og fellen i grotta!",
		"Husk at du kan bytte våpen med tastene 1 til 6, og skru på lykten med tast L."
	],
	"pelle": [
		"Pysa og jeg har lett etter gull i hele dag, men vi fant bare tomme tønner!",
		"Lykke til mot Grusomme Gabriel, Pinky!"
	],
	"pysa": [
		"Hørte du den lyden?! Var det Grusomme Gabriels spøkelse?!",
		"Du får gå først du, Pinky!"
	],
	"skalken": [
		"Mat må sjørøvere ha! Ta deg en bit om du mister helse.",
		"Bare ikke rot til byssa mi!"
	],
	"miriam": [
		"Jeg ser mørke skyer over Gral og Fata Morgana i krystallkulen min...",
		"Bare en sann sjørøver med mot i brystet kan bryte Grusomme Gabriels forbannelse!"
	],
	"sultan": [
		"Velkommen til Fata Morganas palass, unge sjørøver!",
		"Vær på vakt – vaktene mine slipper ingen ubudne gjester forbi."
	],
	"shopkeeper": [
		"Velkommen til sjørøverbutikken i Abra Havn!",
		"Du har allerede utstyrt deg godt med sverd, gullsverd, kårde og sprettert!"
	],
}


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)

	var glb_path := "res://assets/models/%s.glb" % model_resource
	if ResourceLoader.exists(glb_path):
		var sc := load(glb_path) as PackedScene
		if sc:
			var inst := sc.instantiate()
			_visual.add_child(inst)
			_align_model(inst)
			VisualEnhancer.enhance_character_node(_visual, true, 0.72)
	else:
		_build_fallback()

	# Diskret navneskilt som kun toner inn når Pinky går helt bort til karakteren
	var lbl := Label3D.new()
	lbl.name = "NameLabel"
	lbl.text = display_name
	lbl.position.y = 2.25
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 26
	lbl.outline_size = 7
	lbl.modulate = Color(1.0, 0.94, 0.76, 0.0)
	lbl.visible = false
	add_child(lbl)


func _align_model(inst: Node3D) -> void:
	var min_y := 99999.0
	var max_y := -99999.0
	var found := false
	for m in _find_meshes(inst):
		var aabb: AABB = m.get_aabb()
		min_y = min(min_y, aabb.position.y)
		max_y = max(max_y, aabb.position.y + aabb.size.y)
		found = true
	if found and max_y > min_y:
		var s: float = 1.85 / maxf(max_y - min_y, 0.01)
		inst.scale = Vector3.ONE * s
		inst.position.y = -min_y * s


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func _build_fallback() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.65
	mi.mesh = cap
	mi.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.42)
	mi.material_override = mat
	_visual.add_child(mi)


func _process(delta: float) -> void:
	_bob_t += delta * 2.0
	if is_instance_valid(_visual):
		_visual.position.y = sin(_bob_t) * 0.04
	var lbl := get_node_or_null("NameLabel") as Label3D
	if lbl:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var d := global_position.distance_to((players[0] as Node3D).global_position)
			var a := clampf(1.0 - (d - 4.2) / 3.0, 0.0, 1.0)
			lbl.visible = a > 0.03
			lbl.modulate.a = a


func interact(actor: Node) -> void:
	if actor is Node3D:
		var look_pos: Vector3 = (actor as Node3D).global_position
		look_pos.y = global_position.y
		if look_pos.distance_to(global_position) > 0.2:
			look_at(look_pos, Vector3.UP)

	var lines: Array = dialogue_lines
	if lines.is_empty():
		lines = DEFAULT_DIALOGUES.get(npc_id, [
			"Hei Pinky! Hold motet oppe på jakten etter Grusomme Gabriels skatt!"
		])
	GameState.emit_signal("dialogue_requested", display_name, lines)
	if not _talked and reward_coins > 0:
		_talked = true
		GameState.add_coins(reward_coins)
