class_name ReelMinigame
extends CanvasLayer
## Interactive Reeling Minigame for "Tide & Hook"
## Player taps [Space] or [Left Click] to keep the hook indicator inside the moving green target zone for 3 seconds.

signal minigame_finished(success: bool)

@export var required_catch_time: float = 3.0
@export var gravity: float = 460.0
@export var tap_impulse: float = 190.0
@export var hold_thrust: float = 520.0
@export var max_velocity: float = 280.0

@onready var panel_container: PanelContainer = %PanelContainer
@onready var track_control: Control = %Track
@onready var target_zone: Panel = %TargetZone
@onready var hook_indicator: Panel = %HookIndicator
@onready var progress_bar: ProgressBar = %TensionProgress
@onready var timer_label: Label = %TimerLabel
@onready var status_label: Label = %StatusLabel

const TRACK_HEIGHT: float = 190.0
const ZONE_HEIGHT: float = 52.0
const INDICATOR_HEIGHT: float = 22.0

var indicator_y: float = 90.0
var indicator_vel: float = 0.0

var target_y: float = 70.0
var desired_target_y: float = 70.0
var target_move_timer: float = 0.0

var current_progress: float = 0.8 # Initial cushion so player has time to react
var is_active: bool = false
var is_resolved: bool = false


func _ready() -> void:
	visible = false
	if is_instance_valid(target_zone):
		target_zone.custom_minimum_size = Vector2(0, ZONE_HEIGHT)
	if is_instance_valid(hook_indicator):
		hook_indicator.custom_minimum_size = Vector2(0, INDICATOR_HEIGHT)


func start_game() -> void:
	is_active = true
	is_resolved = false
	visible = true

	# Reset positions & physics
	indicator_y = TRACK_HEIGHT - INDICATOR_HEIGHT - 10.0
	indicator_vel = 0.0
	target_y = 60.0
	desired_target_y = 60.0
	target_move_timer = 0.0
	current_progress = 0.75

	_update_visual_positions()
	_update_progress_display()

	# Entrance Pop animation
	if is_instance_valid(panel_container):
		panel_container.scale = Vector2(0.7, 0.7)
		panel_container.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel_container, "modulate:a", 1.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_resolved:
		return

	var is_interact_tap: bool = false
	if event.is_action_pressed("interact"):
		is_interact_tap = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_E:
			is_interact_tap = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_interact_tap = true

	if is_interact_tap:
		# Upward kick on tap
		indicator_vel = -tap_impulse
		_pulse_indicator()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_active or is_resolved:
		return

	# Continuous hold thrust
	var is_holding: bool = false
	if Input.is_action_pressed("interact") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_holding = true

	if is_holding:
		indicator_vel -= hold_thrust * delta
	else:
		indicator_vel += gravity * delta

	indicator_vel = clampf(indicator_vel, -max_velocity, max_velocity)
	indicator_y += indicator_vel * delta

	# Clamp indicator inside track bounds
	var max_y: float = TRACK_HEIGHT - INDICATOR_HEIGHT
	if indicator_y < 0.0:
		indicator_y = 0.0
		indicator_vel = 0.0
	elif indicator_y > max_y:
		indicator_y = max_y
		indicator_vel = -indicator_vel * 0.2 # Small gentle bounce

	# Move target green zone smoothly
	target_move_timer -= delta
	if target_move_timer <= 0.0:
		target_move_timer = randf_range(0.6, 1.1)
		desired_target_y = randf_range(0.0, TRACK_HEIGHT - ZONE_HEIGHT)

	var move_speed: float = 140.0
	target_y = move_toward(target_y, desired_target_y, move_speed * delta)

	# Overlap calculation
	var in_zone: bool = _is_indicator_in_zone()

	if in_zone:
		current_progress += delta
		if status_label:
			status_label.text = "REELING! KEEP IT UP!"
			status_label.modulate = Color(0.4, 1.0, 0.5)
	else:
		current_progress -= delta * 0.55
		if status_label:
			status_label.text = "DANGER! LOST TENSION!"
			status_label.modulate = Color(1.0, 0.4, 0.3)

	_update_visual_positions()
	_update_progress_display()

	# Win / Loss Condition
	if current_progress >= required_catch_time:
		_finish_game(true)
	elif current_progress <= 0.0:
		_finish_game(false)


func _is_indicator_in_zone() -> bool:
	var ind_top: float = indicator_y
	var ind_bot: float = indicator_y + INDICATOR_HEIGHT
	var zone_top: float = target_y
	var zone_bot: float = target_y + ZONE_HEIGHT

	return (ind_bot >= zone_top) and (ind_top <= zone_bot)


func _update_visual_positions() -> void:
	if is_instance_valid(target_zone):
		target_zone.position.y = target_y
	if is_instance_valid(hook_indicator):
		hook_indicator.position.y = indicator_y


func _update_progress_display() -> void:
	var ratio: float = clampf(current_progress / required_catch_time, 0.0, 1.0)
	if is_instance_valid(progress_bar):
		progress_bar.value = ratio * 100.0

	if is_instance_valid(timer_label):
		var time_left: float = maxf(0.0, required_catch_time - current_progress)
		timer_label.text = "%.1fs" % time_left


func _pulse_indicator() -> void:
	if not is_instance_valid(hook_indicator):
		return
	var tween := create_tween()
	tween.tween_property(hook_indicator, "scale", Vector2(1.12, 1.12), 0.06)
	tween.tween_property(hook_indicator, "scale", Vector2.ONE, 0.08)


func _finish_game(success: bool) -> void:
	if is_resolved:
		return
	is_resolved = true
	is_active = false

	if status_label:
		if success:
			status_label.text = "FISH CAUGHT!"
			status_label.modulate = Color(1.0, 0.9, 0.2)
		else:
			status_label.text = "LINE SNAPPED!"
			status_label.modulate = Color(1.0, 0.2, 0.2)

	var tween := create_tween()
	tween.tween_interval(0.4)
	if is_instance_valid(panel_container):
		tween.tween_property(panel_container, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(panel_container, "modulate:a", 0.0, 0.15)
	
	tween.finished.connect(func():
		visible = false
		minigame_finished.emit(success)
		queue_free()
	)

