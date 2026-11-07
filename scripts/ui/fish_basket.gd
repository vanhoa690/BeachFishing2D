class_name FishBasket
extends CanvasLayer
## Fish Basket / Inventory overlay for "Tide & Hook"
## Displays list of currently stored fish with weight, species, and value. Toggled via [B] or [Tab].

@onready var root_control: Control = $Root
@onready var panel_container: PanelContainer = %PanelContainer
@onready var count_label: Label = %CountLabel
@onready var list_container: VBoxContainer = %ListContainer
@onready var empty_label: Label = %EmptyLabel
@onready var btn_close: Button = %BtnClose

var is_open: bool = false


func _ready() -> void:
	visible = false
	if is_instance_valid(btn_close):
		btn_close.pressed.connect(close)

	GameEvents.fish_inventory_changed.connect(_on_inventory_changed)
	refresh_list()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
		elif is_open and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	visible = true
	refresh_list()

	if is_instance_valid(panel_container):
		panel_container.scale = Vector2(0.85, 0.85)
		panel_container.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel_container, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not is_open:
		return
	is_open = false

	if is_instance_valid(panel_container):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(panel_container, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(func():
			visible = false
		)
	else:
		visible = false


func _on_inventory_changed(_inventory: Array) -> void:
	if is_open:
		refresh_list()


func refresh_list() -> void:
	if not is_instance_valid(list_container):
		return

	# Clear previous rows
	for child in list_container.get_children():
		child.queue_free()

	var inventory: Array[Dictionary] = GameState.fish_inventory
	var count: int = inventory.size()

	if is_instance_valid(count_label):
		count_label.text = "%d fish in basket" % count

	if count == 0:
		if is_instance_valid(empty_label):
			empty_label.visible = true
		return

	if is_instance_valid(empty_label):
		empty_label.visible = false

	for i in range(count):
		var fish_data: Dictionary = inventory[i]
		var row := _create_fish_row(fish_data)
		list_container.add_child(row)


func _create_fish_row(data: Dictionary) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.18, 0.22, 0.85)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.35, 0.42, 0.5, 0.5)
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_right = 6
	row_style.corner_radius_bottom_left = 6
	row_style.content_margin_left = 8
	row_style.content_margin_top = 6
	row_style.content_margin_right = 8
	row_style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = data.get("texture_path", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	hbox.add_child(icon)

	# Details VBox
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = data.get("display_name", "Unknown Fish")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	info_vbox.add_child(name_lbl)

	var meta_lbl := Label.new()
	var weight: float = data.get("weight", 0.5)
	var val: int = data.get("value", 20)
	meta_lbl.text = "⚖ %.2f kg  •  🪙 %d Coins" % [weight, val]
	meta_lbl.add_theme_font_size_override("font_size", 11)
	meta_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	info_vbox.add_child(meta_lbl)

	return row_panel

