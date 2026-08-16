extends CanvasLayer

const HUD_MESSAGE_SCENE := preload("res://gui/misc/hud_message.tscn")

var _msg_jump_score = null
var _msg_backflip_score = null

## Smoothed target values — bars lerp toward these each frame.
var _fuel_target  := 100.0
var _nitro_target := 5.0
## Dynamically created speed readout label.
var _speed_label: Label = null

@onready var hud_main: MarginContainer = %HudMain
@onready var progress_bar: TextureProgressBar = %ProgressBar
@onready var fuel_progress_bar: TextureProgressBar = %FuelProgressBar
@onready var score_label: Label = %ScoreLabel


func _ready() -> void:
	Globals.game_over.connect(_on_game_over)
	Globals.score_changed.connect(_on_score_changed)
	Globals.nitro_changed.connect(_on_nitro_changed)
	Globals.fuel_changed.connect(_on_fuel_changed)
	Globals.speed_changed.connect(_on_speed_changed)
	progress_bar.max_value = 5.0 + (Globals.upgrade_nitro - 1) * 1.5

	# Seed smooth targets with current values so bars don't animate from 0 on spawn.
	_fuel_target  = Globals.fuel
	_nitro_target = Globals.nitro

	# Create speed label programmatically — keeps the .tscn untouched.
	_speed_label = Label.new()
	_speed_label.name            = "SpeedLabel"
	_speed_label.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	_speed_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud_main.add_child(_speed_label)


func _on_game_over():
	hud_main.visible = false


## Frame-rate-independent exponential smoothing (tau ≈ 0.125 s).
func _process(delta: float) -> void:
	var smooth := 1.0 - exp(-delta * 8.0)
	progress_bar.value      = lerpf(progress_bar.value,      _nitro_target, smooth)
	fuel_progress_bar.value = lerpf(fuel_progress_bar.value, _fuel_target,  smooth)


func _on_score_changed():
	var score := Globals.score_distance
	score += Globals.score_coins
	score += ceili(Globals.score_jump)
	score += ceili(Globals.score_backflip)
	score += Globals.score_medals * Globals.MEDAL_VALUE
	score_label.text = tr("SCORE") + ": " + str(score)


func _on_nitro_changed():
	_nitro_target = Globals.nitro


func _on_fuel_changed():
	_fuel_target = Globals.fuel


func _on_speed_changed(speed: float) -> void:
	if _speed_label:
		# Rough in-game scale: ~1200 px/s ≈ top speed. Display as a friendly integer.
		_speed_label.text = "%d" % int(speed / 10.0)

func _on_car_jump_scored(score: int) -> void:
	if not is_instance_valid(_msg_jump_score) or not _msg_jump_score.is_running():
		_msg_jump_score = HUD_MESSAGE_SCENE.instantiate()
		hud_main.add_child(_msg_jump_score)
		_msg_jump_score.position = Vector2(300, 170)
		_msg_jump_score.set_title("JUMP")
	_msg_jump_score.set_message("+" + str(score))


func _on_car_jump_landed() -> void:
	_msg_jump_score = null


func _on_car_backflip_performed(multi: int) -> void:
	if not is_instance_valid(_msg_backflip_score) or not _msg_backflip_score.is_running():
		_msg_backflip_score = HUD_MESSAGE_SCENE.instantiate()
		hud_main.add_child(_msg_backflip_score)
		_msg_backflip_score.position = Vector2(450, 230)
		_msg_backflip_score.set_title("BACKFLIP")
	if multi == 1:
		_msg_backflip_score.set_title("BACKFLIP")
		_msg_backflip_score.set_message("+1000")
	else:
		_msg_backflip_score.set_title(tr("BACKFLIP") + " x" + str(multi))
		_msg_backflip_score.set_message("+" + str(1000 * multi))
