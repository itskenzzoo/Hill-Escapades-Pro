extends RigidBody2D

signal jump_scored(score : int)
signal jump_landed()
signal backflip_performed(multi : int)

const PARTICLES_BANG := preload("res://particles/bang.tscn")

@export var TORQUE := 700.0
@export var AUTO_ADVANCE := false
@export var ENABLE_USER := true
@export var MUTE := false
## Maximum angular speed (rad/s) the wheels are allowed to spin.
## Torque is not applied once a wheel exceeds this, preventing endless
## spin-up on low-friction surfaces.
@export var max_wheel_angular_speed: float = 30.0

var _air_time := 0.0
var _air_score := 0
var _backflip := false
var _backflip_multi := 1

@onready var pin_rear: PinJoint2D = $PinJointRear
@onready var pin_front: PinJoint2D = $PinJointFront
@onready var mark_rear: Marker2D = $PinJointRear/Marker2D
@onready var mark_front: Marker2D = $PinJointFront/Marker2D
@onready var wheel_rear: RigidBody2D = $PinJointRear/WheelRear
@onready var wheel_front: RigidBody2D = $PinJointFront/WheelFront
@onready var head: RigidBody2D = $Head
@onready var audio_engine: AudioStreamPlayer = $AudioEngine
@onready var particle_nitrous: GPUParticles2D = $ParticleNitrous
@onready var body_head_limit: StaticBody2D = $BodyHeadLimit
@onready var dust_particles_rear: CPUParticles2D = %DustParticlesRear
@onready var dust_particles_front: CPUParticles2D = %DustParticlesFront
@onready var camera: Camera2D = $Camera2D

var shake_intensity := 0.0
var shake_decay := 15.0


func _ready() -> void:
	# 1. Engine torque upgrade (+15% torque per level)
	TORQUE = 700.0 * (1.0 + (Globals.upgrade_engine - 1) * 0.15)
	
	# 2. Suspension softness upgrade (lower softness = stiffer spring, -15% per level)
	pin_rear.softness = 8.0 * (1.0 - (Globals.upgrade_suspension - 1) * 0.15)
	pin_front.softness = 8.0 * (1.0 - (Globals.upgrade_suspension - 1) * 0.15)
	
	# 3. Tires grip upgrade (+15% friction per level)
	if wheel_rear.physics_material_override:
		wheel_rear.physics_material_override = wheel_rear.physics_material_override.duplicate()
		wheel_rear.physics_material_override.friction = 0.9 + (Globals.upgrade_tires - 1) * 0.15
	if wheel_front.physics_material_override:
		wheel_front.physics_material_override = wheel_front.physics_material_override.duplicate()
		wheel_front.physics_material_override.friction = 0.9 + (Globals.upgrade_tires - 1) * 0.15


func _physics_process(delta: float) -> void:
	# Capture inputs once at the top so every sub-section can share them.
	var _fwd := Input.get_action_strength(&"speed_up")
	var _rev := Input.get_action_strength(&"speed_down")

	if not freeze:
		var throttle := _fwd
		var is_nitro := Input.is_action_pressed(&"nitro") and Globals.nitro > 0
		var depletion_rate := 1.8 + (throttle * 1.5) + (3.0 if is_nitro else 0.0)
		Globals.fuel -= depletion_rate * delta
		
		if Globals.fuel <= 0.0:
			set_deferred(&"freeze", true)
			wheel_front.set_deferred(&"freeze", true)
			wheel_rear.set_deferred(&"freeze", true)
			head.set_deferred(&"freeze", true)
			audio_engine.stop()
			Globals.game_over.emit()

	if MUTE:
		audio_engine.stop()
	else:
		if not audio_engine.playing:
			audio_engine.play()
		var speed_factor := absf(linear_velocity.x) / 1200.0
		# Reverse cue: engine sounds slightly laboured when backing up.
		var _reversing := _fwd < 0.01 and _rev > 0.1
		var target_pitch := 0.9 + (_fwd * 0.5) + (speed_factor * 0.8)
		if _reversing:
			target_pitch = 0.72 + _rev * 0.18
		audio_engine.pitch_scale = clampf(target_pitch, 0.7, 2.3)
	
	# Score por saltos
	if not freeze and not _is_grounded():
		_air_time += delta
		if _air_time >= 0.5:
			_air_score += 50
			_air_time -= 0.5
			jump_scored.emit(_air_score)
	elif not freeze and _air_time > 0:
		if _air_time > 0.8:
			shake_intensity = clampf(_air_time * 15.0, 5.0, 25.0)
		jump_landed.emit()
		Globals.score_jump += _air_score
		_air_score = 0
		_air_time = 0.0
		_backflip_multi = 1
	
	# Score por volteretas
	if rotation_degrees > 160 and rotation_degrees < 200:
		if not _backflip:
			_backflip = true
			Globals.score_backflip += 1000 * _backflip_multi
			backflip_performed.emit(_backflip_multi)
			_backflip_multi += 1
	else:
		_backflip = false
	
	if AUTO_ADVANCE:
		_drive_wheel(wheel_rear,  1.0)
		_drive_wheel(wheel_front, 1.0)
	
	if ENABLE_USER:
		_drive_wheel(wheel_rear,  _fwd - _rev)
		_drive_wheel(wheel_front, _fwd - _rev)
		
		# Air-control tilt: give extra body rotation while airborne
		if not _is_grounded():
			apply_torque_impulse(-1200.0 * Input.get_action_strength(&"turn_left"))
			apply_torque_impulse( 1200.0 * Input.get_action_strength(&"turn_right"))
		else:
			apply_torque_impulse(-1000.0 * Input.get_action_strength(&"turn_left"))
			apply_torque_impulse( 1000.0 * Input.get_action_strength(&"turn_right"))
		
		# Progressive brake: high angular damping feels far more natural than
		# a hard lock_rotation which stops the wheel instantly.
		var _braking := Input.is_action_pressed(&"brake")
		wheel_rear.lock_rotation  = false
		wheel_front.lock_rotation = false
		wheel_rear.angular_damp   = 50.0 if _braking else -1.0
		wheel_front.angular_damp  = 50.0 if _braking else -1.0
		
		if Input.is_action_pressed(&"nitro"):
			if Globals.nitro > 0:
				Globals.nitro -= delta
				particle_nitrous.emitting = true
				var dir := pin_rear.global_position - mark_rear.global_position
				wheel_rear.apply_central_force(dir * 150)
				dir = pin_front.global_position - mark_front.global_position
				wheel_front.apply_central_force(dir * 150)
			else:
				particle_nitrous.emitting = false
		else:
			particle_nitrous.emitting = false

	# Dust particle effects based on wheel contact and torque
	var is_accelerating := (ENABLE_USER and Input.get_action_strength(&"speed_up") > 0.1) or AUTO_ADVANCE
	if not freeze:
		dust_particles_rear.emitting = is_accelerating and wheel_rear.get_contact_count() > 0
		dust_particles_front.emitting = is_accelerating and wheel_front.get_contact_count() > 0
	else:
		dust_particles_rear.emitting = false
		dust_particles_front.emitting = false

	# Update camera screen shake decay
	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		camera.offset = Vector2(460.0, 0.0) + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		camera.offset = Vector2(460.0, 0.0)

	# Broadcast speed so HUD can display km/h without coupling directly to the car.
	Globals.speed_changed.emit(linear_velocity.length())


## Applies torque to [param wheel] only when it hasn't yet hit the speed cap.
## [param dir] is in the range [-1, 1]; positive = forward.
func _drive_wheel(wheel: RigidBody2D, dir: float) -> void:
	if dir == 0.0:
		return
	if abs(wheel.angular_velocity) < max_wheel_angular_speed:
		wheel.apply_torque_impulse(dir * TORQUE)


## Returns [code]true[/code] when at least one wheel is touching the ground.
func _is_grounded() -> bool:
	return wheel_rear.get_contact_count() > 0 or wheel_front.get_contact_count() > 0


func _on_head_body_entered(body: Node) -> void:
	if body == body_head_limit:
		return
	shake_intensity = 35.0
	set_deferred(&"freeze", true)
	wheel_front.set_deferred(&"freeze", true)
	wheel_rear.set_deferred(&"freeze", true)
	head.set_deferred(&"freeze", true)
	body.set_deferred(&"freeze", true)
	audio_engine.stop()
	Globals.game_over.emit()


func _on_head_collided(globalpos: Vector2) -> void:
	if has_meta(&"bang"):
		return
	set_meta(&"bang", true)
	var bang = PARTICLES_BANG.instantiate()
	add_child(bang)
	bang.global_position = globalpos


func _on_area_items_area_entered(area: Area2D) -> void:
	if not area.has_meta(&"type"):
		return
	if area.get_meta(&"type") == "nitro":
		Globals.nitro += 1.5
		area.get_parent().queue_free()
	if area.get_meta(&"type") == "fuel":
		Globals.fuel += 45.0
		area.get_parent().queue_free()
	if area.get_meta(&"type") == "coin":
		Globals.score_coins += 50
		area.get_parent().on_grab()
