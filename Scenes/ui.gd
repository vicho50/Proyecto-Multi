extends CanvasLayer

@onready var resource_label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/ResourceLabel
@onready var health_bar = $HUD/MarginContainer/VBoxContainer/HealthBar

var health = 100.0
var gold = 0

#Actualizar oro
func update_gold():
	resource_label.text = "Oro: " + str(gold)
#Actualizar vida
func update_health():
	health_bar.value = health

func _ready():
	# Inicializa la vida y el oro
	update_gold()
	update_health()

func _input(_event):	
	# Tecla + para subir vida (Usa la tecla Plus o el teclado numerico)
	if Input.is_key_pressed(KEY_KP_ADD) or Input.is_key_pressed(KEY_PERIOD):
		health = clamp(health + 10, 0, 100)
		gold += 50
		update_gold()
		update_health()
	
	# Tecla - para bajar vida
	if Input.is_key_pressed(KEY_KP_SUBTRACT) or Input.is_key_pressed(KEY_MINUS):
		health = clamp(health - 10, 0, 100)
		gold = max(0, gold - 25)
		update_gold()
		update_health()
