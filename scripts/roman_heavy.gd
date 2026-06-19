extends MeleeUnit

@onready var helmet_mesh: MeshInstance3D = get_node_or_null("Visuals/Helmet")
@onready var crest_mesh: MeshInstance3D = get_node_or_null("Visuals/Crest")

func _ready() -> void:
	super._ready()
	apply_roman_visuals()

func apply_roman_visuals() -> void:
	# Cresta romana (si existe) o alas germanas: ambas se tiñen del color del equipo.
	if crest_mesh:
		var crest_material := StandardMaterial3D.new()
		crest_material.albedo_color = get_team_color()
		crest_mesh.material_override = crest_material
	_paint_wings_team_color()

	if helmet_mesh:
		var helmet_material := StandardMaterial3D.new()
		helmet_material.albedo_color = get_helmet_color()
		helmet_material.metallic = 0.55
		helmet_material.roughness = 0.4
		helmet_mesh.material_override = helmet_material


# Tiñe del color del equipo las decoraciones germanas si existen: alas del casco y falda.
func _paint_wings_team_color() -> void:
	var team_color := get_team_color()
	var helmet := get_node_or_null("Visuals/Helmet")
	if helmet:
		for wing_name in ["Wing1", "Wing2"]:
			var wing = helmet.get_node_or_null(wing_name)
			if wing:
				_apply_team_color_to_children(wing, team_color)
	var skirt := get_node_or_null("Visuals/Skirt")
	if skirt:
		_apply_team_color_to_children(skirt, team_color)


func _apply_team_color_to_children(parent: Node, color: Color) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			child.material_override = mat

func get_helmet_color() -> Color:
	return Color(0.45, 0.35, 0.0, 1.0)

func get_weapon_color() -> Color:
	return Color(0.7, 0.7, 0.72)

func get_visual_rotation_degrees() -> float:
	return 90.0

func get_attack_animation_distance() -> float:
	return 0.28
