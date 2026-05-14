extends Node

var players = []

func _ready():
	setup_player(0, "Jugador Azul")
	setup_player(1, "Jugador Rojo")
	
	# Configuración del temporizador de ingreso pasivo
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0 # Oro cada 1 segundo
	timer.timeout.connect(_on_passive_income)
	timer.start()

func setup_player(id: int, p_name: String):
	var p = PlayerData.new()
	p.id = id
	p.player_name = p_name
	players.append(p)

func get_player(id: int):
	for p in players:
		if p.id == id: return p
	return null

func _on_passive_income():
	for p in players:
		p.gold += 5 # Cantidad de oro por segundo

func add_gold(id: int, amount: int):
	var p = get_player(id)
	if p: p.gold += amount

# Clase de datos del jugador
class PlayerData:
	signal gold_changed(new_amount)
	var id: int
	var player_name: String
	# Oro inicializado en 0
	var gold: int = 0:
		set(v):
			gold = max(0, v)
			gold_changed.emit(gold)
