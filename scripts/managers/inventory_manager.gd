class_name InventoryManager
extends Node
## Central Inventory Manager for "Tide & Hook"
## Coordinates the player's fish basket, safe chest storage, and bait supplies.
## Synchronizes with GameState and GameEvents for global reactivity.

signal basket_updated(items: Array)
signal chest_updated(items: Array)

const MAX_CHEST_SLOTS: int = 12

var player_basket: Array[Dictionary] = []
var safe_chest_storage: Array[Dictionary] = []


func _ready() -> void:
	# Synchronize with GameState on boot
	if is_instance_valid(GameState):
		player_basket = GameState.fish_inventory
		safe_chest_storage = GameState.chest_storage

	GameEvents.fish_inventory_changed.connect(_on_game_state_inventory_changed)
	GameEvents.chest_storage_changed.connect(_on_game_state_chest_changed)


func _on_game_state_inventory_changed(items: Array) -> void:
	player_basket = items
	basket_updated.emit(player_basket)


func _on_game_state_chest_changed(items: Array) -> void:
	safe_chest_storage = items
	chest_updated.emit(safe_chest_storage)


func get_basket() -> Array[Dictionary]:
	return player_basket


func get_chest() -> Array[Dictionary]:
	return safe_chest_storage


## Transfers a fish from the player basket to the safe chest storage.
func deposit_to_chest(basket_index: int) -> bool:
	if basket_index < 0 or basket_index >= player_basket.size():
		return false
	if safe_chest_storage.size() >= MAX_CHEST_SLOTS:
		GameEvents.emit_notification("Safe Chest is full! (Max %d slots)" % MAX_CHEST_SLOTS)
		return false

	var item: Dictionary = GameState.remove_fish_by_index(basket_index)
	if item.is_empty():
		return false

	GameState.add_fish_to_chest(item)
	return true


## Transfers a fish from the safe chest storage to the player basket.
func take_from_chest(chest_index: int) -> bool:
	if chest_index < 0 or chest_index >= safe_chest_storage.size():
		return false

	var item: Dictionary = GameState.remove_fish_from_chest(chest_index)
	if item.is_empty():
		return false

	GameState.fish_inventory.append(item)
	GameEvents.fish_inventory_changed.emit(GameState.fish_inventory)
	return true


## Deposits all catches from player basket into the chest up to max slots.
func deposit_all_to_chest() -> int:
	var moved: int = 0
	while not player_basket.is_empty() and safe_chest_storage.size() < MAX_CHEST_SLOTS:
		var item: Dictionary = GameState.pop_first_fish()
		if not item.is_empty():
			GameState.add_fish_to_chest(item)
			moved += 1
		else:
			break
	if moved > 0:
		GameEvents.emit_notification("Stored %d fish in Safe Storage Chest!" % moved)
	elif player_basket.is_empty():
		GameEvents.emit_notification("Fish basket is empty.")
	elif safe_chest_storage.size() >= MAX_CHEST_SLOTS:
		GameEvents.emit_notification("Safe Chest is already full!")
	return moved


## Retrieves all fish from the safe chest back into player basket.
func take_all_from_chest() -> int:
	var moved: int = 0
	while not safe_chest_storage.is_empty():
		var item: Dictionary = GameState.remove_fish_from_chest(0)
		if not item.is_empty():
			GameState.fish_inventory.append(item)
			moved += 1
		else:
			break

	if moved > 0:
		GameEvents.fish_inventory_changed.emit(GameState.fish_inventory)
		GameEvents.emit_notification("Retrieved %d fish from Safe Storage Chest!" % moved)
	else:
		GameEvents.emit_notification("Safe Chest is empty.")
	return moved


## Serializes inventory state for saving.
func serialize() -> Dictionary:
	return {
		"player_basket": player_basket.duplicate(true),
		"safe_chest_storage": safe_chest_storage.duplicate(true),
		"worms_count": GameState.worms_count if is_instance_valid(GameState) else 0,
		"master_bait_count": GameState.master_bait_count if is_instance_valid(GameState) else 0,
		"has_pro_rod": GameState.has_pro_rod if is_instance_valid(GameState) else false
	}


## Deserializes inventory state from a saved dictionary.
func deserialize(data: Dictionary) -> void:
	if data.has("player_basket"):
		player_basket.clear()
		for item in data["player_basket"]:
			player_basket.append(item)
		if is_instance_valid(GameState):
			GameState.fish_inventory = player_basket
		GameEvents.fish_inventory_changed.emit(player_basket)

	if data.has("safe_chest_storage"):
		safe_chest_storage.clear()
		for item in data["safe_chest_storage"]:
			safe_chest_storage.append(item)
		if is_instance_valid(GameState):
			GameState.chest_storage = safe_chest_storage
		GameEvents.chest_storage_changed.emit(safe_chest_storage)

	if is_instance_valid(GameState):
		if data.has("worms_count"):
			GameState.worms_count = int(data["worms_count"])
		if data.has("master_bait_count"):
			GameState.master_bait_count = int(data["master_bait_count"])
		if data.has("has_pro_rod"):
			GameState.has_pro_rod = bool(data["has_pro_rod"])

