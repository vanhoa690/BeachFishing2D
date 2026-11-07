extends CanvasLayer
## In-Game HUD for "Tide & Hook"
## Displays tool hotbar with active highlights, bait counter, and interaction prompts.

@onready var slot_hands: PanelContainer = $Root/HotbarMargin/Hotbar/SlotHands
@onready var slot_shovel: PanelContainer = $Root/HotbarMargin/Hotbar/SlotShovel
@onready var slot_rod: PanelContainer = $Root/HotbarMargin/Hotbar/SlotRod
@onready var tool_info_label: Label = $Root/HotbarMargin/HotbarContainer/ToolInfoLabel

@onready var worms_label: Label = $Root/TopMargin/StatsBox/WormPanel/HBox/WormCount
@onready var worm_panel: PanelContainer = $Root/TopMargin/StatsBox/WormPanel

@onready var prompt_panel: PanelContainer = $Root/PromptContainer/PromptPanel
@onready var prompt_label: Label = $Root/PromptContainer/PromptPanel/PromptLabel

@onready var notification_banner: PanelContainer = $Root/NotificationContainer/BannerPanel
@onready var notification_label: Label = $Root/NotificationContainer/BannerPanel/NotificationLabel

var slots: Array[PanelContainer] = []
var notif_tween: Tween = null
var prompt_tween: Tween = null


func _ready() -> void:
	slots = [slot_hands, slot_shovel, slot_rod]
	
	# Connect to event bus
	GameEvents.tool_changed.connect(_on_tool_changed)
	GameEvents.worms_count_changed.connect(_on_worms_count_changed)
	GameEvents.interaction_prompt_requested.connect(_on_interaction_prompt_requested)
	GameEvents.notification_banner.connect(show_notification)

	# Initial state setup
	_on_tool_changed(GameState.current_tool)
	_on_worms_count_changed(GameState.worms_count)
	
	prompt_panel.modulate.a = 0.0
	notification_banner.modulate.a = 0.0


func _on_tool_changed(tool_index: int) -> void:
	for i in range(slots.size()):
		var slot := slots[i]
		var is_active := (i == tool_index)
		
		# Visual highlight on active slot
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
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
	var tool_type: GameState.ToolType = tool_index as GameState.ToolType
	var t_name: String = GameState.get_tool_name(tool_type)
	var t_desc: String = GameState.TOOL_DESCRIPTIONS.get(tool_type, "")
	tool_info_label.text = "%s — %s" % [t_name, t_desc]


func _on_worms_count_changed(new_count: int) -> void:
	worms_label.text = "x %d" % new_count
	
	# Little squash & stretch animation on bait counter
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(worm_panel, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK)
		tween.tween_property(worm_panel, "scale", Vector2(1.0, 1.0), 0.15)


func _on_interaction_prompt_requested(prompt_text: String, _world_pos: Vector2, should_show: bool) -> void:
	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()

	prompt_tween = create_tween()
	if should_show and not prompt_text.is_empty():
		prompt_label.text = prompt_text
		prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.15)
	else:
		prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.15)


func show_notification(message: String) -> void:
	notification_label.text = message
	if notif_tween and notif_tween.is_valid():
		notif_tween.kill()

	notif_tween = create_tween()
	notif_tween.tween_property(notification_banner, "modulate:a", 1.0, 0.2)
	notif_tween.tween_interval(2.2)
	notif_tween.tween_property(notification_banner, "modulate:a", 0.0, 0.4)

