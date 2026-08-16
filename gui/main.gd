extends Node2D

@onready var camera_2d: Camera2D = %Camera2D
@onready var terrain: Node2D = %Terrain
@onready var car: RigidBody2D = %Car
@onready var tab_container: TabContainer = %TabContainer
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton

# New Shop/Leaderboard controls
@onready var shop_button: Button = %ShopButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var score_list: VBoxContainer = %ScoreList
@onready var coins_label: Label = %CoinsLabel
@onready var engine_label: Label = %EngineLabel
@onready var engine_buy: Button = %EngineBuy
@onready var suspension_label: Label = %SuspensionLabel
@onready var suspension_buy: Button = %SuspensionBuy
@onready var tires_label: Label = %TiresLabel
@onready var tires_buy: Button = %TiresBuy
@onready var nitro_label: Label = %NitroLabel
@onready var nitro_buy: Button = %NitroBuy

const MAX_UPGRADE_LEVEL := 5
const UPGRADE_BASE_COST := 100
const UPGRADE_COST_MULTIPLIER := 1.5


func _ready() -> void:
	car.position.y = terrain.get_position_y(car.position.x) - 150
	play_button.grab_focus()


func _process(_delta: float) -> void:
	if car.position.x >= -600:
		camera_2d.position.x = car.position.x + 600
	if tab_container.current_tab == 0:
		if Input.is_action_just_pressed(&"ui_cancel"):
			if exit_button.has_focus():
				_on_exit_button_pressed()
			else:
				exit_button.grab_focus()


func _on_play_button_pressed() -> void:
	Globals.new_game()


func _on_settings_button_pressed() -> void:
	tab_container.current_tab = 1


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_back_pressed() -> void:
	tab_container.current_tab = 0
	settings_button.call_deferred(&"grab_focus")


# Leaderboard methods
func _on_leaderboard_button_pressed() -> void:
	tab_container.current_tab = 2
	%LeaderboardBack.call_deferred(&"grab_focus")
	_populate_leaderboard()


func _on_leaderboard_back_pressed() -> void:
	tab_container.current_tab = 0
	leaderboard_button.call_deferred(&"grab_focus")


func _populate_leaderboard() -> void:
	# Clear previous list
	for child in score_list.get_children():
		child.queue_free()
	
	# Fetch from DB
	var scores = Db.get_high_scores()
	if scores.is_empty():
		var no_scores_label := Label.new()
		no_scores_label.text = "NO HIGH SCORES YET!"
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_list.add_child(no_scores_label)
		return
	
	var index := 1
	for score_data in scores:
		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var pos_label := Label.new()
		pos_label.text = "%d." % index
		pos_label.custom_minimum_size = Vector2(50, 0)
		row_hbox.add_child(pos_label)
		
		var name_label := Label.new()
		name_label.text = score_data["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(name_label)
		
		var val_label := Label.new()
		val_label.text = str(score_data["score"])
		row_hbox.add_child(val_label)
		
		score_list.add_child(row_hbox)
		index += 1


# Shop/Garage methods
func _on_shop_button_pressed() -> void:
	tab_container.current_tab = 3
	%ShopBack.call_deferred(&"grab_focus")
	_update_shop_ui()


func _on_shop_back_pressed() -> void:
	tab_container.current_tab = 0
	shop_button.call_deferred(&"grab_focus")


func _get_upgrade_cost(level: int) -> int:
	return int(UPGRADE_BASE_COST * pow(UPGRADE_COST_MULTIPLIER, level - 1))


func _update_shop_ui() -> void:
	coins_label.text = "COINS: " + str(Globals.coins)
	
	# Engine
	_update_upgrade_item(
		"ENGINE", 
		Globals.upgrade_engine, 
		engine_label, 
		engine_buy
	)
	# Suspension
	_update_upgrade_item(
		"SUSPENSION", 
		Globals.upgrade_suspension, 
		suspension_label, 
		suspension_buy
	)
	# Tires
	_update_upgrade_item(
		"TIRES", 
		Globals.upgrade_tires, 
		tires_label, 
		tires_buy
	)
	# Nitro
	_update_upgrade_item(
		"NITRO CAPACITY", 
		Globals.upgrade_nitro, 
		nitro_label, 
		nitro_buy
	)


func _update_upgrade_item(title: String, level: int, label: Label, button: Button) -> void:
	if level >= MAX_UPGRADE_LEVEL:
		label.text = title + " (MAX LEVEL)"
		button.text = "MAXED OUT"
		button.disabled = true
	else:
		var cost = _get_upgrade_cost(level)
		label.text = title + " (LVL " + str(level) + ")"
		button.text = "UPGRADE: " + str(cost)
		button.disabled = Globals.coins < cost


func _on_engine_buy_pressed() -> void:
	var cost = _get_upgrade_cost(Globals.upgrade_engine)
	if Globals.coins >= cost:
		Globals.coins -= cost
		Globals.upgrade_engine += 1
		Globals.save_config()
		_update_shop_ui()


func _on_suspension_buy_pressed() -> void:
	var cost = _get_upgrade_cost(Globals.upgrade_suspension)
	if Globals.coins >= cost:
		Globals.coins -= cost
		Globals.upgrade_suspension += 1
		Globals.save_config()
		_update_shop_ui()


func _on_tires_buy_pressed() -> void:
	var cost = _get_upgrade_cost(Globals.upgrade_tires)
	if Globals.coins >= cost:
		Globals.coins -= cost
		Globals.upgrade_tires += 1
		Globals.save_config()
		_update_shop_ui()


func _on_nitro_buy_pressed() -> void:
	var cost = _get_upgrade_cost(Globals.upgrade_nitro)
	if Globals.coins >= cost:
		Globals.coins -= cost
		Globals.upgrade_nitro += 1
		Globals.save_config()
		_update_shop_ui()
