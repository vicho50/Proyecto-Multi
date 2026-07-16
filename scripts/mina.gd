extends StaticBody3D

@export_group("Configuración")
@export var gold_remaining: int = 1000
@export var is_infinite: bool = false

# Punto donde el minero se coloca a picar (Marker3D en la escena) y etiqueta de oro.
# Se usan get_node_or_null para que la mina funcione aunque falten estos nodos.
@onready var mining_spot = get_node_or_null("Marker3D")
@onready var label = get_node_or_null("Label3D")

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
	if label:
		label.text = "Gold: " + str(gold_remaining) if not is_infinite else "Gold: Infinite"

func _deplete():
	print("Mina agotada")
	queue_free()
