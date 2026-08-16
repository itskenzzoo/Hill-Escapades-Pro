extends Node3D

const GUI_PAUSE := preload("res://gui/pause.tscn")
const GUI_GAME_OVER := preload("res://gui/game_over.tscn")
const CAR_3D_SCENE := preload("res://scenes/car_3d.tscn")
const TEST_TRACK_SCENE := preload("res://scenes/test_track.tscn")

var _car_instance: VehicleBody3D = null
var _track_instance: Node3D = null
var _start_z: float = 0.0
var _max_distance_z: float = 0.0


func _ready() -> void:
	Globals.game_over.connect(_on_game_over)

	# Spawn test track
	_track_instance = TEST_TRACK_SCENE.instantiate()
	add_child(_track_instance)

	# Spawn car at track SpawnPoint
	_car_instance = CAR_3D_SCENE.instantiate()
	add_child(_car_instance)

	var spawn_marker = _track_instance.get_node_or_null("SpawnPoint")
	if spawn_marker:
		_car_instance.global_position = spawn_marker.global_position
		_car_instance.global_rotation = spawn_marker.global_rotation

	_start_z = _car_instance.global_position.z
	_max_distance_z = _start_z


func _process(_delta: float) -> void:
	if is_instance_valid(_car_instance):
		var current_z := _car_instance.global_position.z
		var speed_ms := _car_instance.linear_velocity.length()

		# Distance ratchet along Z axis (driving forward = negative Z)
		var dist_traveled := _start_z - current_z
		if dist_traveled > _max_distance_z and speed_ms > 1.5:
			var meters := floori(dist_traveled)
			var prev_meters := floori(_max_distance_z)
			if meters > prev_meters:
				Globals.score_distance += (meters - prev_meters) * 2
			_max_distance_z = dist_traveled

	# Pause menu handler
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
