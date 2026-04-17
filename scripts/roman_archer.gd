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
	if global_position.distance_to(target.global_position) > stats.attack_range:
		return

	attack_timer.start()
	start_attack_animation()
	_spawn_arrow()

func _spawn_arrow() -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.damage = stats.damage
	arrow.target = target
	arrow.team_id = team_id
	arrow.global_position = weapon_mesh.global_position
	get_tree().current_scene.add_child(arrow, true)

func apply_roman_visuals() -> void:
	var helmet_material := StandardMaterial3D.new()
	helmet_material.albedo_color = get_helmet_color()
	helmet_material.metallic = 0.4
	helmet_material.roughness = 0.45
	helmet_mesh.material_override = helmet_material

	var quiver_material := StandardMaterial3D.new()
	quiver_material.albedo_color = Color(0.35, 0.22, 0.1)
	quiver_mesh.material_override = quiver_material

func get_helmet_color() -> Color:
	return Color(0.5, 0.4, 0.05, 1.0)

func get_weapon_color() -> Color:
	return Color(0.45, 0.3, 0.15)

func get_visual_rotation_degrees() -> float:
	return 90.0

func get_attack_animation_distance() -> float:
	return 0.15
