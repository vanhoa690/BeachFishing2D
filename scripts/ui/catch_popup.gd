class_name CatchPopup
extends CanvasLayer
## Modal celebration popup displayed when the player lands a fish in "Tide & Hook".

signal closed(fish_data: FishData, weight: float)

@onready var dimmer: ColorRect = $Root/Dimmer
@onready var card_panel: PanelContainer = %CardPanel
@onready var fish_sprite: TextureRect = %FishSprite
@onready var catch_title: Label = %CatchTitle
@onready var weight_label: Label = %WeightLabel
@onready var value_label: Label = %ValueLabel
@onready var description_label: Label = %DescriptionLabel
@onready var pocket_button: Button = %PocketButton
@onready var auto_close_timer: Timer = $AutoCloseTimer

var current_fish: FishData = null
var current_weight: float = 0.0
var is_closing: bool = false
var idle_time: float = 0.0
var sprite_base_y: float = 0.0


func _ready() -> void:
	if is_instance_valid(pocket_button):
		pocket_button.pressed.connect(_on_pocket_pressed)
	if is_instance_valid(auto_close_timer):
		auto_close_timer.timeout.connect(_on_pocket_pressed)
	if is_instance_valid(fish_sprite):
		sprite_base_y = fish_sprite.position.y


func _process(delta: float) -> void:
	if not is_closing and is_instance_valid(fish_sprite):
		idle_time += delta * 3.0
		fish_sprite.position.y = sprite_base_y + sin(idle_time) * 4.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			_on_pocket_pressed()
			get_viewport().set_input_as_handled()


func display_catch(fish: FishData, weight: float = -1.0) -> void:
	current_fish = fish
	if not current_fish:
		return

	if weight <= 0.0:
		current_weight = current_fish.roll_weight()
	else:
		current_weight = weight

	# Record catch in global state
	GameState.record_fish_catch(current_fish, current_weight)

	# Update UI elements
	if is_instance_valid(fish_sprite) and current_fish.texture:
		fish_sprite.texture = current_fish.texture

	if is_instance_valid(catch_title):
		catch_title.text = "You caught a %s!" % current_fish.display_name

	if is_instance_valid(weight_label):
		weight_label.text = "⚖ Weight: %.2f kg" % current_weight

	if is_instance_valid(value_label):
		var val: int = current_fish.calculate_value(current_weight)
		value_label.text = "🪙 Est. Value: %d Sea Coins" % val

	if is_instance_valid(description_label):
		description_label.text = current_fish.description

	# Pop entrance animation
	visible = true
	is_closing = false
	idle_time = 0.0
	
	if is_instance_valid(dimmer):
		dimmer.modulate.a = 0.0
		var dim_tween := create_tween()
		dim_tween.tween_property(dimmer, "modulate:a", 1.0, 0.2)

	if is_instance_valid(card_panel):
		card_panel.scale = Vector2(0.65, 0.65)
		card_panel.modulate.a = 0.0
		var card_tween := create_tween().set_parallel(true)
		card_tween.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(card_panel, "modulate:a", 1.0, 0.25)

	if is_instance_valid(auto_close_timer):
		auto_close_timer.start(7.0)


func _on_pocket_pressed() -> void:
	if is_closing:
		return
	is_closing = true

	if is_instance_valid(auto_close_timer):
		auto_close_timer.stop()

	# Exit animation
	var tween := create_tween().set_parallel(true)
	if is_instance_valid(card_panel):
		tween.tween_property(card_panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(card_panel, "modulate:a", 0.0, 0.18)
	if is_instance_valid(dimmer):
		tween.tween_property(dimmer, "modulate:a", 0.0, 0.2)

	tween.chain().tween_callback(func():
		closed.emit(current_fish, current_weight)
		queue_free()
	)

