extends Control

signal score_changed()
signal nitro_changed()
signal fuel_changed()
signal speed_changed(speed: float)
@warning_ignore("unused_signal")
signal game_over()

const MEDAL_VALUE: int = 10000
## Matches the MAX_UPGRADE_LEVEL in main.gd; defined here so load_config
## can clamp values without depending on the menu scene.
const MAX_UPGRADE_LEVEL: int = 5

var score_distance := 0 : set = _on_set_score_distance
var score_coins := 0 : set = _on_set_score_coins
var score_jump := 0 : set = _on_set_score_jump
var score_backflip := 0 : set = _on_set_score_backflip
var score_medals := 0 : set = _on_set_score_medals
var nitro := 5.0 : set = _on_set_nitro
var fuel := 100.0 : set = _on_set_fuel

# Persistent game progression data
var coins := 0
var upgrade_engine := 1
var upgrade_suspension := 1
var upgrade_tires := 1
var upgrade_nitro := 1


func _ready() -> void:
	load_config()


## Compute a simple hash over progression values to detect manual tampering.
func _compute_checksum() -> int:
	return hash("%d|%d|%d|%d|%d|hr43_2026" % [
		coins, upgrade_engine, upgrade_suspension, upgrade_tires, upgrade_nitro
	])


func save_config() -> void:
	var file := FileAccess.open("user://config.cfg", FileAccess.WRITE)
	if file == null:
		return
	var config := {
		"volume_music": AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")),
		"volume_fx": AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"FX")),
		"fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		"hdr": get_viewport().use_hdr_2d,
		"coins": coins,
		"upgrade_engine": upgrade_engine,
		"upgrade_suspension": upgrade_suspension,
		"upgrade_tires": upgrade_tires,
		"upgrade_nitro": upgrade_nitro,
		"ck": _compute_checksum(),
	}
	file.store_string(JSON.stringify(config))


func load_config() -> void:
	var file := FileAccess.open("user://config.cfg", FileAccess.READ)
	if file == null:
		# Defaults on first launch
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(0.5))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"FX"), linear_to_db(0.5))
		get_viewport().use_hdr_2d = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	var config = JSON.parse_string(file.get_as_text())
	if config == null or typeof(config) != TYPE_DICTIONARY:
		push_warning("Globals: config file corrupt or unreadable, using defaults.")
		return

	# ── Audio / display settings (guarded — a partial file must not crash) ──
	if config.has("volume_music"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), config["volume_music"])
	if config.has("volume_fx"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"FX"), config["volume_fx"])
	if config.has("fullscreen") and config["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if config.has("hdr"):
		get_viewport().use_hdr_2d = config["hdr"]

	# ── Progression data (clamp + checksum guard) ───────────────────────────
	var saved_coins       := clampi(int(config.get("coins",            0)), 0, 9_999_999)
	var saved_engine      := clampi(int(config.get("upgrade_engine",     1)), 1, MAX_UPGRADE_LEVEL)
	var saved_suspension  := clampi(int(config.get("upgrade_suspension", 1)), 1, MAX_UPGRADE_LEVEL)
	var saved_tires       := clampi(int(config.get("upgrade_tires",      1)), 1, MAX_UPGRADE_LEVEL)
	var saved_nitro       := clampi(int(config.get("upgrade_nitro",      1)), 1, MAX_UPGRADE_LEVEL)

	# Verify checksum when present; reset progression silently if it fails.
	if config.has("ck"):
		var expected_ck := hash("%d|%d|%d|%d|%d|hr43_2026" % [
			saved_coins, saved_engine, saved_suspension, saved_tires, saved_nitro
		])
		if int(config["ck"]) != expected_ck:
			push_warning("Globals: config integrity check failed — progression reset.")
			return  # Keep all progression vars at their initialised defaults

	coins             = saved_coins
	upgrade_engine    = saved_engine
	upgrade_suspension = saved_suspension
	upgrade_tires     = saved_tires
	upgrade_nitro     = saved_nitro


func new_game() -> void:
	score_distance = 0
	score_coins = 0
	score_jump = 0
	score_backflip = 0
	score_medals = 0
	nitro = 5.0
	fuel = 100.0
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_set_score_distance(value : int) -> void:
	score_distance = value
	score_changed.emit()


func _on_set_score_coins(value : int) -> void:
	score_coins = value
	score_changed.emit()


func _on_set_score_jump(value : int) -> void:
	score_jump = value
	score_changed.emit()


func _on_set_score_backflip(value : int) -> void:
	score_backflip = value
	score_changed.emit()


func _on_set_score_medals(value : int) -> void:
	score_medals = value
	score_changed.emit()


func _on_set_nitro(value : float) -> void:
	var max_val := 5.0 + (upgrade_nitro - 1) * 1.5
	nitro = clampf(value, 0.0, max_val)
	nitro_changed.emit()


func _on_set_fuel(value : float) -> void:
	fuel = clampf(value, 0.0, 100.0)
	fuel_changed.emit()
