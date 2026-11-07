extends CanvasLayer
## In-Game HUD for "Tide & Hook"
## Displays tool hotbar with active highlights, bait counter, interaction prompts, and window controls.

@onready var slot_hands: PanelContainer = %SlotHands
@onready var slot_shovel: PanelContainer = %SlotShovel
@onready var slot_rod: PanelContainer = %SlotRod
@onready var slot_rack: PanelContainer = %SlotRack
@onready var tool_info_label: Label = %ToolInfoLabel

@onready var worms_label: Label = %WormCount
@onready var worm_panel: PanelContainer = %WormPanel
@onready var fish_label: Label = %FishCount
@onready var fish_panel: PanelContainer = %FishPanel
@onready var fish_basket: FishBasket = %FishBasket

@onready var btn_fullscreen: Button = %BtnFullscreen
@onready var btn_quit: Button = %BtnQuit

@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel

@onready var notification_banner: PanelContainer = %BannerPanel
@onready var notification_label: Label = %NotificationLabel

var slots: Array[PanelContainer] = []
var notif_tween: Tween = null
var prompt_tween: Tween = null


func _ready() -> void:
	# Fallback resolution in case of hierarchy discrepancies
	if not slot_hands:
		slot_hands = get_node_or_null("Root/HotbarMargin/HotbarContainer/Hotbar/SlotHands")
	if not slot_shovel:
		slot_shovel = get_node_or_null("Root/HotbarMargin/HotbarContainer/Hotbar/SlotShovel")
	if not slot_rod:
		slot_rod = get_node_or_null("Root/HotbarMargin/HotbarContainer/Hotbar/SlotRod")
	if not slot_rack:
		slot_rack = get_node_or_null("Root/HotbarMargin/HotbarContainer/Hotbar/SlotRack")
	if not btn_fullscreen:
		btn_fullscreen = get_node_or_null("Root/TopMargin/TopRightControls/WindowControls/BtnFullscreen")
	if not btn_quit:
		btn_quit = get_node_or_null("Root/TopMargin/TopRightControls/WindowControls/BtnQuit")

	slots.clear()
	if slot_hands:
		slots.append(slot_hands)
	if slot_shovel:
		slots.append(slot_shovel)
	if slot_rod:
		slots.append(slot_rod)
	if slot_rack:
		slots.append(slot_rack)
	
	# Connect button signals
	if is_instance_valid(btn_fullscreen):
		btn_fullscreen.pressed.connect(toggle_fullscreen)
	if is_instance_valid(btn_quit):
		btn_quit.pressed.connect(quit_game)

	# Connect to event bus
	GameEvents.tool_changed.connect(_on_tool_changed)
	GameEvents.worms_count_changed.connect(_on_worms_count_changed)
	GameEvents.fish_inventory_changed.connect(_on_fish_inventory_changed)
	GameEvents.interaction_prompt_requested.connect(_on_interaction_prompt_requested)
	GameEvents.notification_banner.connect(show_notification)

	# Initial state setup
	_on_tool_changed(GameState.current_tool)
	_on_worms_count_changed(GameState.worms_count)
	_on_fish_inventory_changed(GameState.fish_inventory)

	# Click fish panel to open basket
	if is_instance_valid(fish_panel):
		fish_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if is_instance_valid(fish_basket):
					fish_basket.toggle()
		)
	
	if is_instance_valid(prompt_panel):
		prompt_panel.modulate.a = 0.0
	if is_instance_valid(notification_banner):
		notification_banner.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			quit_game()


func toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func quit_game() -> void:
	get_tree().quit()


func _on_tool_changed(tool_index: int) -> void:
	if slots.is_empty():
		return

	for i in range(slots.size()):
		var slot := slots[i]
		if not is_instance_valid(slot):
			continue
		
		var is_active := (i == tool_index)
		
		# Visual highlight on active slot
		var style: StyleBoxFlat
		if slot.has_theme_stylebox_override("panel"):
			style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		elif slot.has_theme_stylebox("panel"):
			style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		else:
			style = StyleBoxFlat.new()
			style.corner_radius_bottom_left = 8
			style.corner_radius_bottom_right = 8
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 8

		if is_active:
			style.border_color = Color(1.0, 0.82, 0.28, 1.0) # Bright golden amber
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.bg_color = Color(0.24, 0.22, 0.18, 0.95)
			slot.scale = Vector2(1.06, 1.06)
		else:
			style.border_color = Color(0.45, 0.40, 0.35, 0.6)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.bg_color = Color(0.14, 0.13, 0.12, 0.85)
			slot.scale = Vector2(1.0, 1.0)
		
		slot.add_theme_stylebox_override("panel", style)

	# Update description text
	if is_instance_valid(tool_info_label):
		var tool_type: GameState.ToolType = tool_index as GameState.ToolType
		var t_name: String = GameState.get_tool_name(tool_type)
		var t_desc: String = GameState.TOOL_DESCRIPTIONS.get(tool_type, "")
		tool_info_label.text = "%s — %s" % [t_name, t_desc]


func _on_worms_count_changed(new_count: int) -> void:
	if is_instance_valid(worms_label):
		worms_label.text = "x %d" % new_count
	
	# Little squash & stretch animation on bait counter
	if is_instance_valid(worm_panel) and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(worm_panel, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK)
		tween.tween_property(worm_panel, "scale", Vector2(1.0, 1.0), 0.15)


func _on_fish_inventory_changed(inventory: Array) -> void:
	if is_instance_valid(fish_label):
		fish_label.text = "x %d" % inventory.size()
	
	if is_instance_valid(fish_panel) and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(fish_panel, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK)
		tween.tween_property(fish_panel, "scale", Vector2.ONE, 0.15)


func _on_interaction_prompt_requested(prompt_text: String, _world_pos: Vector2, should_show: bool) -> void:
	if not is_instance_valid(prompt_panel) or not is_instance_valid(prompt_label):
		return

	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()

	prompt_tween = create_tween()
	if should_show and not prompt_text.is_empty():
		prompt_label.text = prompt_text
		prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.15)
	else:
		prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.15)


func show_notification(message: String) -> void:
	if not is_instance_valid(notification_banner) or not is_instance_valid(notification_label):
		return

	notification_label.text = message
	if notif_tween and notif_tween.is_valid():
		notif_tween.kill()

	notif_tween = create_tween()
	notif_tween.tween_property(notification_banner, "modulate:a", 1.0, 0.2)
	notif_tween.tween_interval(2.2)
	notif_tween.tween_property(notification_banner, "modulate:a", 0.0, 0.4)
