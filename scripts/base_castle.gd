extends StaticBody3D

# Señales para la UI y lógica de partida
signal health_changed(current_health, max_health)
signal castle_destroyed(player_id)

@export_group("Estadísticas")
@export var max_health: int = 500 # Cambiado a int para ser igual a la unidad
var current_health: int

@export_group("Configuración de Equipo")
@export var team_id: int = 0 # 0 para azul, 1 para rojo (igual que tus unidades)
@export var player_id: int = 1 # ID único del jugador si fuera necesario
var is_dead: bool = false # Requerido por el find_closest_enemy() de la unidad

@export_group("Configuración Visual")
@export var custom_mesh: Mesh
@onready var mesh_instance = $MeshInstance3D

var material_propio: StandardMaterial3D
var original_color: Color

func get_attack_radius() -> float:
	# Radio del cilindro de colisión del castillo, usado por las unidades melee
	# para calcular su distancia efectiva al borde del castillo (no al centro).
	return 1.1


func _ready():
	current_health = max_health
	
	# Configurar Mesh y Material
	if custom_mesh:
		mesh_instance.mesh = custom_mesh
	
	# Extraer el material para poder hacer el flash de daño
	var mat = mesh_instance.get_active_material(0)
	if mat:
		material_propio = mat.duplicate()
		mesh_instance.set_surface_override_material(0, material_propio)
		original_color = material_propio.albedo_color
	
	# REGISTRO CRÍTICO: Para que las unidades lo vean como objetivo
	add_to_group("units")
	# Grupo extra para que las unidades sepan que este es el castillo enemigo
	add_to_group("castillo_jugador_" + str(team_id))
	
	health_changed.emit(current_health, max_health)

# Cambiado a int para coincidir con stats.damage de la unidad
func take_damage(amount: int) -> void:
	if is_dead or not multiplayer.is_server(): 
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	health_changed.emit(current_health, max_health)
	flash_damage()
	
	if current_health <= 0:
		die()

func flash_damage():
	if not material_propio: return
	
	var tween = create_tween()
	tween.tween_property(material_propio, "albedo_color", Color.RED, 0.1)
	tween.tween_property(material_propio, "albedo_color", original_color, 0.1)

func die():
	if is_dead: return
	is_dead = true
	
	print("Castillo ", team_id, " destruido.")
	castle_destroyed.emit(player_id)
	
	# Dejar de ser un objetivo para las unidades
	remove_from_group("units")
	
	# Desactivar colisión para que no estorbe si se queda el modelo ahí
	$CollisionShape3D.set_deferred("disabled", true)
	
	# Aquí podrías añadir una animación de derrumbe o partículas
