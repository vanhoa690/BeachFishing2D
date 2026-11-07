class_name EconomyManager
extends Node
## Global Economy & Currency Manager for "Tide & Hook"
## Tracks player currency (Sea Coins) and handles transactions.

signal coins_changed(new_amount: int)

var sea_coins: int = 50:
	set(value):
		var clamped: int = maxi(0, value)
		if sea_coins != clamped:
			sea_coins = clamped
			coins_changed.emit(sea_coins)
			if Engine.has_singleton("GameEvents") or is_instance_valid(GameEvents):
				GameEvents.sea_coins_changed.emit(sea_coins)


func _ready() -> void:
	coins_changed.emit(sea_coins)
	if Engine.has_singleton("GameEvents") or is_instance_valid(GameEvents):
		GameEvents.sea_coins_changed.emit(sea_coins)


func add_coins(amount: int) -> void:
	if amount > 0:
		sea_coins += amount


func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if sea_coins >= amount:
		sea_coins -= amount
		return true
	return false


func get_coins() -> int:
	return sea_coins


## Serializes currency state for saving
func serialize() -> Dictionary:
	return {
		"sea_coins": sea_coins
	}


## Deserializes currency state from saved dictionary
func deserialize(data: Dictionary) -> void:
	if data.has("sea_coins"):
		sea_coins = int(data["sea_coins"])

