class_name StorageChestModal
extends CanvasLayer
## Split Inventory Modal UI for Safe Storage Chest in "Tide & Hook"
## Coordinates 2-way transfers between Player Fish Basket (InventoryManager) and Safe Chest Storage.

signal chest_closed()

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = %Panel
@onready var basket_list: VBoxContainer = %BasketList
@onready var chest_list: VBoxContainer = %ChestList
@onready var basket_count_label: Label = %BasketCountLabel
@onready var chest_count_label: Label = %ChestCountLabel
@onready var btn_deposit_all: Button = %BtnDepositAll
@onready var btn_take_all: Button = %BtnTakeAll
@onready var btn_close: Button = %BtnClose
@onready var btn_done: Button = %BtnDone

var is_closing: bool = false


func _ready() -> void:
	visible = true
	is_closing = false

	if is_instance_valid(btn_close):
		btn_close.pressed.connect(close)
	if is_instance_valid(btn_done):
		btn_done.pressed.connect(close)
	if is_instance_valid(btn_deposit_all):
		btn_deposit_all.pressed.connect(_on_deposit_all)
	if is_instance_valid(btn_take_all):
		btn_take_all.pressed.connect(_on_take_all)

	GameEvents.fish_inventory_changed.connect(_on_inventory_changed)
	GameEvents.chest_storage_changed.connect(_on_chest_changed)

	_lock_player(true)
	refresh_both_lists()

	# Pop entrance animation
	if is_instance_valid(dimmer):
		dimmer.modulate.a = 0.0
		var dt := create_tween()
		dt.tween_property(dimmer, "modulate:a", 1.0, 0.2)

	if is_instance_valid(panel):
		panel.scale = Vector2(0.85, 0.85)
		panel.modulate.a = 0.0
		var pt := create_tween().set_parallel(true)
		pt.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pt.tween_property(panel, "modulate:a", 1.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if is_closing or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close()
			get_viewport().set_input_as_handled()


func refresh_both_lists() -> void:
	_render_basket_list()
	_render_chest_list()


func _on_inventory_changed(_items: Array) -> void:
	_render_basket_list()


func _on_chest_changed(_items: Array) -> void:
	_render_chest_list()


func _render_basket_list() -> void:
	if not is_instance_valid(basket_list):
		return

	for c in basket_list.get_children():
		c.queue_free()

	var inventory: Array[Dictionary] = InventoryManager.get_basket() if is_instance_valid(InventoryManager) else GameState.fish_inventory
	if is_instance_valid(basket_count_label):
		basket_count_label.text = "🧺 Fish Basket (%d)" % inventory.size()

	if inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Basket is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		basket_list.add_child(empty_lbl)
		return

	for i in range(inventory.size()):
		var fish: Dictionary = inventory[i]
		var row := _create_fish_row(fish, i, true)
		basket_list.add_child(row)


func _render_chest_list() -> void:
	if not is_instance_valid(chest_list):
		return

	for c in chest_list.get_children():
		c.queue_free()

	var storage: Array[Dictionary] = InventoryManager.get_chest() if is_instance_valid(InventoryManager) else GameState.chest_storage
	var max_slots: int = InventoryManager.MAX_CHEST_SLOTS if is_instance_valid(InventoryManager) else 12
	if is_instance_valid(chest_count_label):
		chest_count_label.text = "🔒 Safe Storage Chest (%d/%d)" % [storage.size(), max_slots]

	if storage.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Safe chest is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		chest_list.add_child(empty_lbl)
		return

	for i in range(storage.size()):
		var fish: Dictionary = storage[i]
		var row := _create_fish_row(fish, i, false)
		chest_list.add_child(row)


func _create_fish_row(fish: Dictionary, index: int, is_basket: bool) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.14, 0.75)
	style.border_color = Color(0.35, 0.32, 0.28, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = fish.get("texture_path", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	hbox.add_child(icon)

	# Name & Weight info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = fish.get("display_name", "Unknown Fish")
	name_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(name_lbl)

	var weight_lbl := Label.new()
	var w: float = fish.get("weight", 0.0)
	weight_lbl.text = "%.2f kg" % w
	weight_lbl.add_theme_font_size_override("font_size", 10)
	weight_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	info_vbox.add_child(weight_lbl)
	hbox.add_child(info_vbox)

	# Action button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(68, 24)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 11)

	if is_basket:
		btn.text = "Deposit ➔"
		btn.pressed.connect(func():
			if is_instance_valid(InventoryManager):
				InventoryManager.deposit_to_chest(index)
			else:
				var item = GameState.remove_fish_by_index(index)
				if not item.is_empty():
					GameState.add_fish_to_chest(item)
		)
	else:
		btn.text = "⬅ Take"
		btn.pressed.connect(func():
			if is_instance_valid(InventoryManager):
				InventoryManager.take_from_chest(index)
			else:
				var item = GameState.remove_fish_from_chest(index)
				if not item.is_empty():
					GameState.add_fish_dict_to_inventory(item)
		)
	hbox.add_child(btn)

	return row_panel


func _on_deposit_all() -> void:
	if is_instance_valid(InventoryManager):
		InventoryManager.deposit_all_to_chest()
	else:
		var moved: int = 0
		while GameState.fish_inventory.size() > 0:
			var item = GameState.pop_first_fish()
			GameState.add_fish_to_chest(item)
			moved += 1
		if moved > 0:
			GameEvents.emit_notification("Deposited %d fish into Safe Chest!" % moved)


func _on_take_all() -> void:
	if is_instance_valid(InventoryManager):
		InventoryManager.take_all_from_chest()
	else:
		var moved: int = 0
		while GameState.chest_storage.size() > 0:
			var item = GameState.remove_fish_from_chest(0)
			GameState.add_fish_dict_to_inventory(item)
			moved += 1
		if moved > 0:
			GameEvents.emit_notification("Retrieved %d fish from Safe Chest!" % moved)


func close() -> void:
	if is_closing:
		return
	is_closing = true
	_lock_player(false)

	var tween := create_tween().set_parallel(true)
	if is_instance_valid(panel):
		tween.tween_property(panel, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	if is_instance_valid(dimmer):
		tween.tween_property(dimmer, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func():
		chest_closed.emit()
		queue_free()
	)


func _lock_player(locked: bool) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if "is_locked_action" in p:
			p.is_locked_action = locked
