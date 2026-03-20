extends MeleeUnit

@onready var helmet_mesh: MeshInstance3D = $Visuals/Helmet
@onready var crest_mesh: MeshInstance3D = $Visuals/Crest

func _ready() -> void:
	super._ready()
	apply_roman_visuals()

func apply_roman_visuals() -> void:
	var crest_material := StandardMaterial3D.new()
	crest_material.albedo_color = get_team_color()
	crest_mesh.material_override = crest_material

	var helmet_material := StandardMaterial3D.new()
	helmet_material.albedo_color = get_helmet_color()
	helmet_material.metallic = 0.5
	helmet_material.roughness = 0.35
	helmet_mesh.material_override = helmet_material

func get_helmet_color() -> Color:
	return Color(0.578, 0.481, 0.0, 1.0)

func get_weapon_color() -> Color:
	return Color(0.8, 0.8, 0.8)

func get_visual_rotation_degrees() -> float:
	return 90.0

func get_attack_animation_distance() -> float:
	return 0.22
