extends VehicleBody3D

signal vehicle_freeze_state(frozen: bool)

@export var MAX_ENGINE_FORCE: float = 700.0
@export var MAX_BRAKE_FORCE: float = 30.0
@export var MAX_STEER_ANGLE: float = 0.45
@export var NITRO_FORCE: float = 1400.0

@onready var wheel_front_left: VehicleWheel3D = $WheelFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $WheelFrontRight
@onready var wheel_rear_left: VehicleWheel3D = $WheelRearLeft
@onready var wheel_rear_right: VehicleWheel3D = $WheelRearRight

var is_frozen: bool = false


func _ready() -> void:
	# Apply upgrade stats from Globals if present
	if Globals:
		MAX_ENGINE_FORCE = 700.0 * (1.0 + (Globals.upgrade_engine - 1) * 0.15)
		var tire_friction: float = 1.0 + (Globals.upgrade_tires - 1) * 0.15
		for wheel in [wheel_front_left, wheel_front_right, wheel_rear_left, wheel_rear_right]:
			if wheel:
				wheel.wheel_friction_slip = tire_friction
				wheel.suspension_stiffness = 25.0 + (Globals.upgrade_suspension - 1) * 5.0


func _physics_process(delta: float) -> void:
	if is_frozen:
		engine_force = 0.0
		brake = MAX_BRAKE_FORCE
		steering = 0.0
		return

	# Input processing
	var fwd := Input.get_action_strength(&"speed_up")
	var rev := Input.get_action_strength(&"speed_down")
	var steer_dir := Input.get_axis(&"turn_right", &"turn_left")
	var is_braking := Input.is_action_pressed(&"brake")
	var is_nitro := Input.is_action_pressed(&"nitro") and Globals.nitro > 0.0

	# Steering
	steering = move_toward(steering, steer_dir * MAX_STEER_ANGLE, delta * 4.0)

	# Engine force & Brake
	var target_force := (fwd - rev) * MAX_ENGINE_FORCE
	if is_nitro:
		target_force += MAX_ENGINE_FORCE * 0.8
		Globals.nitro -= delta * 1.5

	if is_braking:
		engine_force = 0.0
		brake = MAX_BRAKE_FORCE
	else:
		brake = 0.0
		engine_force = target_force

	# Fuel depletion
	if not is_frozen and Globals:
		var depletion_rate := 1.2 + (fwd * 1.2) + (2.5 if is_nitro else 0.0)
		Globals.fuel -= depletion_rate * delta
		if Globals.fuel <= 0.0:
			_set_frozen(true)
			Globals.game_over.emit()

	# Emit speed signal for HUD (converting m/s to km/h equivalent approximation)
	var speed_kmh := linear_velocity.length() * 3.6
	Globals.speed_changed.emit(speed_kmh)


func _set_frozen(state: bool) -> void:
	is_frozen = state
	vehicle_freeze_state.emit(state)
