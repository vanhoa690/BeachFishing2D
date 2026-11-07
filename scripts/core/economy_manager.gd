extends Node
## Economy & Currency Manager for "Tide & Hook"
## Tracks player currency (Sea Coins) and handles transactions.

signal coins_changed(new_amount: int)

var sea_coins: int = 50:
	set(value):
		var clamped_val: int = maxi(0, value)
		if sea_coins != clamped_val:
			sea_coins = clamped_val
			coins_changed.emit(sea_coins)
			GameEvents.sea_coins_changed.emit(sea_coins)


func _ready() -> void:
	# Initial broadcast
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

