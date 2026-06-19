extends MeleeUnit

const ARROW_SCENE = preload("res://Scenes/arrow.tscn")

@onready var helmet_mesh: MeshInstance3D = get_node_or_null("Visuals/Helmet")
@onready var quiver_mesh: MeshInstance3D = get_node_or_null("Visuals/Quiver")

func _ready() -> void:
	super._ready()
	apply_roman_visuals()

func try_attack() -> void:
	if target == null:
		return
	if not attack_timer.is_stopped():
		return
	if not is_instance_valid(target):
		return
	# Usa distancia al borde del objetivo (descuenta el radio de castillos)
	# para coincidir con el rango usado en update_logic.
	if effective_distance_to(target) > stats.attack_range:
		return

	attack_timer.start()
	start_attack_animation()
	_spawn_arrow()

func _spawn_arrow() -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.damage = stats.damage
	arrow.target = target
	arrow.team_id = team_id
	var units_node = get_tree().current_scene.get_node_or_null("Units")
	var spawn_parent = units_node if units_node else get_tree().current_scene
	spawn_parent.add_child(arrow, true)
	arrow.global_position = weapon_mesh.global_position

func apply_roman_visuals() -> void:
	if helmet_mesh:
		var helmet_material := StandardMaterial3D.new()
		helmet_material.albedo_color = get_helmet_color()
		helmet_material.metallic = 0.4
		helmet_material.roughness = 0.45
		helmet_mesh.material_override = helmet_material

	if quiver_mesh:
		var quiver_material := StandardMaterial3D.new()
		quiver_material.albedo_color = Color(0.35, 0.22, 0.1)
		quiver_mesh.material_override = quiver_material

	# Alas germanas: si la unidad las tiene, se tiñen del color del equipo.
	_paint_wings_team_color()


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
	return Color(0.5, 0.4, 0.05, 1.0)

func get_weapon_color() -> Color:
	return Color(0.45, 0.3, 0.15)

func get_visual_rotation_degrees() -> float:
	return 90.0

func get_attack_animation_distance() -> float:
	return 0.15
