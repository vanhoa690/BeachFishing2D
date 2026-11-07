class_name FishData
extends Resource
## Custom Resource defining a catchable fish species in "Tide & Hook".

@export var id: String = ""
@export var display_name: String = ""
@export var texture: Texture2D = null
@export var base_value: int = 15
@export_range(0.01, 1.0, 0.01) var rarity_weight: float = 0.5
@export var min_weight: float = 0.3
@export var max_weight: float = 1.2
@export_multiline var description: String = ""


func roll_weight() -> float:
	return snappedf(randf_range(min_weight, max_weight), 0.01)


func calculate_value(weight: float) -> int:
	var weight_ratio: float = 1.0
	if max_weight > min_weight:
		weight_ratio = clampf((weight - min_weight) / (max_weight - min_weight), 0.0, 1.0)
	# Value bonus up to +50% for trophy-size catches
	return int(round(base_value * (1.0 + weight_ratio * 0.5)))

