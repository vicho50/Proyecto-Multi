class_name PlayerDataResource
extends Resource

@export var name: String
@export var role: Statics.Role

class PlayerData:
	var id: int
	var name: String
	var gold: int = 100:
		set(value):
			gold = max(0, value) # Evitamos oro negativo
			gold_changed.emit(gold) # Avisamos a la UI

	signal gold_changed(new_amount)
