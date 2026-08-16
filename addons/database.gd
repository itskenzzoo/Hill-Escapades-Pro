extends Node

var db: SQLite = null

const _NAME_MAX_LEN := 20
## Regex that matches any character outside printable ASCII (0x20–0x7E).
## Used to strip control characters, unicode mojibake, and injection attempts.
var _name_regex := RegEx.new()


func _ready() -> void:
	# Compile once; pattern matches anything that is NOT a printable ASCII char
	_name_regex.compile("[^ -~]")
	if open_db("user://scores.db"):
		create_table()


func _exit_tree() -> void:
	close_db()


## Open the database connection.
func open_db(db_path: String) -> bool:
	db = SQLite.new()
	if db.open(db_path) != OK:
		push_error("Db: failed to open database at '%s'" % db_path)
		return false
	return true


## Create the scores table if it doesn't exist.
## The CHECK constraint enforces non-negative scores at the DB level.
func create_table() -> void:
	if db == null:
		return
	var query := """
		CREATE TABLE IF NOT EXISTS high_scores (
			id    INTEGER PRIMARY KEY AUTOINCREMENT,
			name  TEXT    NOT NULL,
			score INTEGER NOT NULL CHECK(score >= 0)
		);
	"""
	if not db.query(query):
		push_error("Db: failed to create high_scores table")


## Insert a score with a sanitised player name.
## Name is stripped of non-printable chars, trimmed, and clamped to 20 chars.
## Score is clamped to >= 0 before insertion.
func insert_score(name: String, score: int) -> void:
	if db == null:
		return

	# ── Name sanitisation ────────────────────────────────────────────────────
	# 1. Strip every character outside printable ASCII range (space to tilde)
	var safe_name := _name_regex.sub(name, "", true).strip_edges()
	# 2. Fall back to a default if nothing printable remains
	if safe_name.is_empty():
		safe_name = "Player"
	# 3. Hard length cap
	if safe_name.length() > _NAME_MAX_LEN:
		safe_name = safe_name.left(_NAME_MAX_LEN)
	# 4. Escape any remaining single-quotes for SQL string safety
	safe_name = safe_name.replace("'", "''")

	# ── Score validation ─────────────────────────────────────────────────────
	var safe_score := maxi(score, 0)

	var query := "INSERT INTO high_scores (name, score) VALUES ('%s', %d);" \
		% [safe_name, safe_score]
	if not db.query(query):
		push_error("Db: failed to insert score for '%s'" % safe_name)


## Return the top-10 scores, highest first.
func get_high_scores() -> Array:
	if db == null:
		return []
	var query := "SELECT * FROM high_scores ORDER BY score DESC LIMIT 10;"
	var result = db.query(query)
	var high_scores := []
	if result:
		for row in result:
			high_scores.append({"id": row[0], "name": row[1], "score": row[2]})
	return high_scores


## Close the database connection.
func close_db() -> void:
	if db != null:
		db.close()
		db = null
