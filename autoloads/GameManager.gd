extends Node

var players = []

const STARTING_GOLD := 10
const PASSIVE_INCOME := 5

var _income_timer: Timer


func _ready():
	setup_player(0, "Jugador Azul")
	setup_player(1, "Jugador Rojo")

	# El ingreso pasivo no arranca hasta que empieza el combate (start_match).
	_income_timer = Timer.new()
	_income_timer.wait_time = 1.0
	_income_timer.timeout.connect(_on_passive_income)
	add_child(_income_timer)


func setup_player(id: int, p_name: String):
	var p = PlayerData.new()
	p.id = id
	p.player_name = p_name
	p.gold = STARTING_GOLD
	players.append(p)


func get_player(id: int):
	for p in players:
		if p.id == id: return p
	return null


# Llamar al iniciar la partida. Solo el servidor reinicia el oro y arranca el ingreso;
# el valor se replica a los clientes.
func start_match():
	if not multiplayer.is_server():
		return
	for p in players:
		_set_gold(p.id, STARTING_GOLD)
	_income_timer.start()


func _on_passive_income():
	if not multiplayer.is_server():
		return
	for p in players:
		_set_gold(p.id, p.gold + PASSIVE_INCOME)


func add_gold(id: int, amount: int):
	if not multiplayer.is_server():
		return
	var p = get_player(id)
	if p:
		_set_gold(id, p.gold + amount)


func sub_gold(id: int, amount: int):
	if not multiplayer.is_server():
		return
	var p = get_player(id)
	if p:
		_set_gold(id, p.gold - amount)


func read_gold(id: int) -> int:
	var p = get_player(id)
	return p.gold if p else 0


# Solo servidor: fija el oro localmente y lo replica a los clientes.
func _set_gold(id: int, value: int):
	var p = get_player(id)
	if not p:
		return
	p.gold = value
	if _is_networked():
		_receive_gold.rpc(id, p.gold)


@rpc("authority", "reliable")
func _receive_gold(id: int, value: int):
	var p = get_player(id)
	if p:
		p.gold = value


func _is_networked() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


# Clase de datos del jugador
class PlayerData:
	signal gold_changed(new_amount)
	var id: int
	var player_name: String
	var gold: int = 0:
		set(v):
			gold = max(0, v)
			gold_changed.emit(gold)
