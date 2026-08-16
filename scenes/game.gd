extends Node2D

const GUI_PAUSE := preload("res://gui/pause.tscn")
const GUI_GAME_OVER := preload("res://gui/game_over.tscn")

var checkpoint := 0
## High-watermark of the car's own X position (world units).
## Only advances when the car moves forward, so rolling back cannot score.
var _car_max_x := 0.0


func _ready() -> void:
	Globals.game_over.connect(_on_game_over)
	$Car.position.y = $Terrain.get_position_y($Car.position.x) - 150
	_car_max_x = $Car.global_position.x


func _process(_delta: float) -> void:
	var car_x     := $Car.global_position.x
	var car_speed := ($Car as RigidBody2D).linear_velocity.length()

	# One-way ratchet: only award distance when moving forward above 50 px/s.
	# This stops the camera lead-lag from inflating score and prevents
	# scoring while the car is airborne / rolling backward.
	if car_x > _car_max_x and car_speed > 50.0:
		var point      := floori(car_x / 100)
		var prev_point := floori(_car_max_x / 100)
		if point > prev_point:
			Globals.score_distance += (point - prev_point) * 10
		_car_max_x = car_x
	
	if Input.is_action_just_pressed(&"ui_cancel"):
		if not get_tree().paused:
			get_tree().paused = true
			var gui_pause = GUI_PAUSE.instantiate()
			get_tree().root.add_child(gui_pause)


func _on_game_over() -> void:
	if not get_tree().paused:
		get_tree().paused = true
		var gui_game_over = GUI_GAME_OVER.instantiate()
		get_tree().root.add_child.call_deferred(gui_game_over)
