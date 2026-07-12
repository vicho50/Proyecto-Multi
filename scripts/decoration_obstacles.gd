extends Node3D

@export var collision_layer: int = 1
@export var collision_mask: int = 0
@export var collision_margin: float = 0.15
@export var minimum_size: Vector3 = Vector3(0.35, 0.35, 0.35)

var _built := false

func _ready() -> void:
	call_deferred("_build_obstacles")

func _build_obstacles() -> void:
	if _built:
		return
	_built = true

	for child in get_children():
		if not (child is MeshInstance3D):
			continue

		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var aabb := mesh_instance.mesh.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue

		var obstacle := StaticBody3D.new()
		obstacle.name = "%s_Obstacle" % mesh_instance.name
		obstacle.collision_layer = collision_layer
		obstacle.collision_mask = collision_mask
		obstacle.add_to_group("map_obstacle")
		obstacle.transform = mesh_instance.transform
		add_child(obstacle)

		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(
			max(aabb.size.x + collision_margin * 2.0, minimum_size.x),
			max(aabb.size.y + collision_margin * 2.0, minimum_size.y),
			max(aabb.size.z + collision_margin * 2.0, minimum_size.z)
		)
		shape_node.shape = box
		shape_node.position = aabb.position + aabb.size * 0.5
		obstacle.add_child(shape_node)
