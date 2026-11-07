class_name MarketModal
extends CanvasLayer
## Coastal Fish Market & Tackle Shop Modal UI
## Allows player to sell caught fish for Sea Coins and buy upgraded gear & bait.

signal market_closed()

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = %Panel
@onready var balance_label: Label = %BalanceLabel
@onready var btn_tab_sell: Button = %BtnTabSell
@onready var btn_tab_buy: Button = %BtnTabBuy
@onready var sell_view: VBoxContainer = %SellView
@onready var buy_view: VBoxContainer = %BuyView
@onready var sell_summary_label: Label = %SellSummaryLabel
@onready var btn_sell_all: Button = %BtnSellAll
@onready var sell_list: VBoxContainer = %SellList
@onready var btn_close: Button = %BtnClose
@onready var btn_done: Button = %BtnDone

# Buy view buttons & labels
@onready var worm_owned_label: Label = %WormOwnedLabel
@onready var btn_buy_worm: Button = %BtnBuyWorm
@onready var master_bait_owned_label: Label = %MasterBaitOwnedLabel
@onready var btn_buy_master_bait: Button = %BtnBuyMasterBait
@onready var rod_owned_label: Label = %RodOwnedLabel
@onready var btn_buy_rod: Button = %BtnBuyRod

var current_tab: int = 0 # 0 = Sell, 1 = Buy
var is_closing: bool = false


func _ready() -> void:
	visible = true
	is_closing = false

	if is_instance_valid(btn_close):
		btn_close.pressed.connect(close)
	if is_instance_valid(btn_done):
		btn_done.pressed.connect(close)
	if is_instance_valid(btn_tab_sell):
		btn_tab_sell.pressed.connect(func(): _switch_tab(0))
	if is_instance_valid(btn_tab_buy):
		btn_tab_buy.pressed.connect(func(): _switch_tab(1))
	if is_instance_valid(btn_sell_all):
		btn_sell_all.pressed.connect(_on_sell_all)

	# Buy connections
	if is_instance_valid(btn_buy_worm):
		btn_buy_worm.pressed.connect(_on_buy_worm)
	if is_instance_valid(btn_buy_master_bait):
		btn_buy_master_bait.pressed.connect(_on_buy_master_bait)
	if is_instance_valid(btn_buy_rod):
		btn_buy_rod.pressed.connect(_on_buy_rod)

	# Event listeners
	GameEvents.fish_inventory_changed.connect(_on_inventory_changed)
	GameEvents.sea_coins_changed.connect(_on_coins_changed)
	GameEvents.worms_count_changed.connect(func(_c): _update_buy_view())

	_lock_player(true)
	_switch_tab(0)
	_update_balance_label()

	# Entrance animation
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


func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	if is_instance_valid(sell_view):
		sell_view.visible = (current_tab == 0)
	if is_instance_valid(buy_view):
		buy_view.visible = (current_tab == 1)

	# Visual tab highlight
	if is_instance_valid(btn_tab_sell) and is_instance_valid(btn_tab_buy):
		btn_tab_sell.modulate = Color(1.0, 1.0, 1.0, 1.0) if current_tab == 0 else Color(0.7, 0.7, 0.7, 0.75)
		btn_tab_buy.modulate = Color(1.0, 1.0, 1.0, 1.0) if current_tab == 1 else Color(0.7, 0.7, 0.7, 0.75)

	if current_tab == 0:
		_render_sell_list()
	else:
		_update_buy_view()


func _update_balance_label() -> void:
	if is_instance_valid(balance_label):
		var coins: int = EconomyManager.get_coins() if is_instance_valid(EconomyManager) else 0
		balance_label.text = "🪙 %d Sea Coins" % coins


func _on_coins_changed(_new_val: int) -> void:
	_update_balance_label()
	if current_tab == 1:
		_update_buy_view()


func _on_inventory_changed(_inv: Array) -> void:
	if current_tab == 0:
		_render_sell_list()


func _render_sell_list() -> void:
	if not is_instance_valid(sell_list):
		return

	for c in sell_list.get_children():
		c.queue_free()

	var inventory: Array[Dictionary] = GameState.fish_inventory
	var total_val: int = 0
	for item in inventory:
		total_val += item.get("value", 10)

	if is_instance_valid(sell_summary_label):
		sell_summary_label.text = "Basket Catches: %d | Total Sell Value: %d 🪙" % [inventory.size(), total_val]

	if is_instance_valid(btn_sell_all):
		btn_sell_all.disabled = inventory.is_empty()
		btn_sell_all.text = "Sell All (%d 🪙)" % total_val if not inventory.is_empty() else "Sell All"

	if inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Your fish basket is empty. Cast your line and bring back a haul!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.65, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		sell_list.add_child(empty_lbl)
		return

	for i in range(inventory.size()):
		var fish: Dictionary = inventory[i]
		var row := _create_sell_row(fish, i)
		sell_list.add_child(row)


func _create_sell_row(fish: Dictionary, index: int) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.14, 0.75)
	style.border_color = Color(0.4, 0.35, 0.3, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = fish.get("texture_path", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	hbox.add_child(icon)

	# Name & details
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = fish.get("display_name", "Fish")
	name_lbl.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(name_lbl)

	var weight_lbl := Label.new()
	var w: float = fish.get("weight", 0.0)
	weight_lbl.text = "Weight: %.2f kg" % w
	weight_lbl.add_theme_font_size_override("font_size", 10)
	weight_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	info_vbox.add_child(weight_lbl)
	hbox.add_child(info_vbox)

	# Value Label
	var val: int = fish.get("value", 10)
	var val_lbl := Label.new()
	val_lbl.text = "%d 🪙" % val
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	hbox.add_child(val_lbl)

	# Sell button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 28)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.text = "Sell"
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func():
		_sell_single_fish(index, fish)
	)
	hbox.add_child(btn)

	return row_panel


func _sell_single_fish(index: int, fish: Dictionary) -> void:
	var item: Dictionary = GameState.remove_fish_by_index(index)
	if not item.is_empty():
		var val: int = item.get("value", 10)
		EconomyManager.add_coins(val)
		var name_str: String = item.get("display_name", "Fish")
		GameEvents.emit_notification("Sold %s for %d Sea Coins!" % [name_str, val])


func _on_sell_all() -> void:
	var count: int = GameState.fish_inventory.size()
	if count == 0:
		return

	var total_earned: int = 0
	while GameState.fish_inventory.size() > 0:
		var item: Dictionary = GameState.pop_first_fish()
		total_earned += item.get("value", 10)

	EconomyManager.add_coins(total_earned)
	GameEvents.emit_notification("Sold %d fish for a total of %d Sea Coins!" % [count, total_earned])


func _update_buy_view() -> void:
	if is_instance_valid(worm_owned_label):
		worm_owned_label.text = "Owned: %d in bait pouch" % GameState.worms_count
	if is_instance_valid(master_bait_owned_label):
		master_bait_owned_label.text = "Owned: %d in bait pouch" % GameState.master_bait_count
	if is_instance_valid(rod_owned_label):
		if GameState.has_pro_rod:
			rod_owned_label.text = "Status: Equipped (+60px Cast Range)"
			if is_instance_valid(btn_buy_rod):
				btn_buy_rod.text = "Owned"
				btn_buy_rod.disabled = true
		else:
			rod_owned_label.text = "Status: Bamboo Rod"
			if is_instance_valid(btn_buy_rod):
				btn_buy_rod.text = "Buy (150 🪙)"
				btn_buy_rod.disabled = false


func _on_buy_worm() -> void:
	const COST: int = 5
	if EconomyManager.spend_coins(COST):
		GameState.add_worms(1)
		GameEvents.emit_notification("Purchased 1 Sand Worm for %d 🪙!" % COST)
		_update_buy_view()
	else:
		GameEvents.emit_notification("Not enough Sea Coins! (Need %d 🪙)" % COST)


func _on_buy_master_bait() -> void:
	const COST: int = 25
	if EconomyManager.spend_coins(COST):
		GameState.master_bait_count += 1
		GameEvents.emit_notification("Purchased 1 Master Bait for %d 🪙!" % COST)
		_update_buy_view()
	else:
		GameEvents.emit_notification("Not enough Sea Coins! (Need %d 🪙)" % COST)


func _on_buy_rod() -> void:
	const COST: int = 150
	if GameState.has_pro_rod:
		GameEvents.emit_notification("You already own the Pro Fiber Rod!")
		return

	if EconomyManager.spend_coins(COST):
		GameState.has_pro_rod = true
		GameEvents.emit_notification("Purchased Pro Fiber Rod! Casting distance extended!")
		_update_buy_view()
	else:
		GameEvents.emit_notification("Not enough Sea Coins! (Need %d 🪙)" % COST)


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
		market_closed.emit()
		queue_free()
	)


func _lock_player(locked: bool) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if "is_locked_action" in p:
			p.is_locked_action = locked

