extends MeleeUnit

@onready var helmet_mesh: MeshInstance3D = get_node_or_null("Visuals/Helmet")
@onready var crest_mesh: MeshInstance3D = get_node_or_null("Visuals/Helmet/Crest")
@onready var shield_mesh: MeshInstance3D = get_node_or_null("Visuals/Shield")


func _ready() -> void:
	super._ready()
	_apply_centurion_visuals()


func _apply_centurion_visuals() -> void:
	var team_color := get_team_color()

	# Cresta personalizada del centurión (cuelga del casco).
	if crest_mesh:
		var crest_material := StandardMaterial3D.new()
		crest_material.albedo_color = team_color
		crest_mesh.material_override = crest_material

	# Casco dorado metálico, igual que el resto de romanos.
	if helmet_mesh:
		var helmet_material := StandardMaterial3D.new()
		helmet_material.albedo_color = get_helmet_color()
		helmet_material.metallic = 0.5
		helmet_material.roughness = 0.35
		helmet_mesh.material_override = helmet_material

	# Escudo: cada cara del mesh se pinta con el color del equipo, EXCEPTO
	# aquellas que ya tienen un surface_material_override puesto a mano en la
	# escena (p. ej. el emblema de alas transparente). Así no destrozamos los
	# ajustes que ya vengan del .tscn.
	if shield_mesh and shield_mesh.mesh:
		for i in shield_mesh.mesh.get_surface_count():
			if shield_mesh.get_surface_override_material(i) == null:
				var shield_material := StandardMaterial3D.new()
				shield_material.albedo_color = team_color
				shield_mesh.set_surface_override_material(i, shield_material)


func get_helmet_color() -> Color:
	return Color(0.45, 0.35, 0.0, 1.0)


func get_weapon_color() -> Color:
	return Color(0.7, 0.7, 0.72)


func get_visual_rotation_degrees() -> float:
	return 90.0


func get_attack_animation_distance() -> float:
	return 0.28
