extends StaticBody3D

@export_group("Configuración")
@export var gold_remaining: int = 1000
@export var is_infinite: bool = false

@onready var mining_spot = $MiningSpot
@onready var label = $Label3D # Si decidiste ponerlo

func _ready():
	add_to_group("minas")
	_update_label()

# Función que llamará el minero cuando termine su animación de picar
func extract_gold(amount: int) -> int:
	if is_infinite:
		return amount
		
	var actual_amount = min(amount, gold_remaining)
	gold_remaining -= actual_amount
	
	_update_label()
	
	if gold_remaining <= 0:
		_deplete()
		
	return actual_amount

func _update_label():
	if has_node("Label3D"):
		label.text = "Oro: " + str(gold_remaining) if not is_infinite else "Oro: Infinito"

func _deplete():
	# Aquí podrías cambiar el color de la malla o eliminar la mina
	print("Mina agotada")
	queue_free()
