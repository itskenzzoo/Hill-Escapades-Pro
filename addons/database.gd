extends Node

var db = null
var _use_fallback := false
var _json_scores: Array = []

const _NAME_MAX_LEN := 20
const _JSON_PATH := "user://scores.json"
var _name_regex := RegEx.new()


func _ready() -> void:
	_name_regex.compile("[^ -~]")

	# Check if native GDExtension SQLite class is registered
	if ClassDB.class_exists("SQLite"):
		if open_db("user://scores.db"):
			create_table()
			return

	# Fallback mode: FileAccess JSON persistence
	_use_fallback = true
	_load_fallback_scores()


func _exit_tree() -> void:
	if not _use_fallback:
		close_db()


## Open native SQLite database connection.
func open_db(db_path: String) -> bool:
	if not ClassDB.class_exists("SQLite"):
		return false
	db = ClassDB.instantiate("SQLite")
	if db == null or db.open(db_path) != OK:
		push_warning("Db: SQLite native library unavailable, switching to local storage.")
		return false
	return true


## Create table structure in native SQLite.
func create_table() -> void:
	if _use_fallback or db == null:
		return
	var query := """
		CREATE TABLE IF NOT EXISTS high_scores (
			id    INTEGER PRIMARY KEY AUTOINCREMENT,
			name  TEXT    NOT NULL,
			score INTEGER NOT NULL CHECK(score >= 0)
		);
	"""
	if not db.query(query):
		push_warning("Db: failed to create high_scores table.")


## Insert a score into SQLite or JSON fallback.
func insert_score(name: String, score: int) -> void:
	# ── Name sanitisation ────────────────────────────────────────────────────
	var safe_name := _name_regex.sub(name, "", true).strip_edges()
	if safe_name.is_empty():
		safe_name = "Player"
	if safe_name.length() > _NAME_MAX_LEN:
		safe_name = safe_name.left(_NAME_MAX_LEN)

	var safe_score := maxi(score, 0)

	if _use_fallback or db == null:
		_insert_fallback_score(safe_name, safe_score)
		return

	safe_name = safe_name.replace("'", "''")
	var query := "INSERT INTO high_scores (name, score) VALUES ('%s', %d);" \
		% [safe_name, safe_score]
	if not db.query(query):
		push_warning("Db: SQLite insert failed, using fallback.")
		_insert_fallback_score(safe_name, safe_score)


## Get high scores (top 10 descending).
func get_high_scores() -> Array:
	if _use_fallback or db == null:
		return _json_scores.slice(0, 10)

	var query := "SELECT * FROM high_scores ORDER BY score DESC LIMIT 10;"
	var result = db.query(query)
	var high_scores := []
	if result and typeof(result) == TYPE_ARRAY:
		for row in result:
			if typeof(row) == TYPE_ARRAY and row.size() >= 3:
				high_scores.append({"id": row[0], "name": row[1], "score": row[2]})
			elif typeof(row) == TYPE_DICTIONARY:
				high_scores.append({"id": row.get("id", 0), "name": row.get("name", "Player"), "score": row.get("score", 0)})
	return high_scores


## Close SQLite connection.
func close_db() -> void:
	if db != null and db.has_method("close"):
		db.close()
		db = null


# ── JSON Fallback System ─────────────────────────────────────────────────────

func _load_fallback_scores() -> void:
	var file := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if file == null:
		_json_scores = []
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed and typeof(parsed) == TYPE_ARRAY:
		_json_scores = parsed
		_sort_fallback_scores()
	else:
		_json_scores = []


func _save_fallback_scores() -> void:
	var file := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json_scores))


func _insert_fallback_score(name: String, score: int) -> void:
	var entry := {
		"id": _json_scores.size() + 1,
		"name": name,
		"score": score
	}
	_json_scores.append(entry)
	_sort_fallback_scores()
	_save_fallback_scores()


func _sort_fallback_scores() -> void:
	_json_scores.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
