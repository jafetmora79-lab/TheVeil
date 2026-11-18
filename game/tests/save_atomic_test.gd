extends SceneTree
## THE VEIL - audit: the save file is written atomically and survives a corrupt main file.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/save_atomic_test.gd
## Checks: a save leaves a valid main file and no .tmp; the previous good save is kept as .bak; a truncated or missing
## main file still loads (from .bak) and Continue (has_save) stays enabled; a stale half-written .tmp never blocks the
## next save. The player's own save and its .bak are backed up first and put back after.

var fails := 0
var game: Node
var _backup := {}


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _paths() -> Array:
	return [game.SAVE_PATH, game.SAVE_PATH + ".bak", game.SAVE_PATH + ".tmp"]


func _read(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


func _write(p: String, s: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	game = root.get_node("Game")
	for p in _paths():
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		_rm(p)
	game.new_game()
	game.no_save = false
	game.flags["audit_a"] = true
	ok("save_1", game.save_game())
	var d1: Variant = _read(game.SAVE_PATH)
	ok("main_valid", d1 is Dictionary and d1.get("flags", {}).has("audit_a"))
	ok("no_tmp_left", not FileAccess.file_exists(game.SAVE_PATH + ".tmp"))
	game.flags["audit_b"] = true
	ok("save_2", game.save_game())
	var bak: Variant = _read(game.SAVE_PATH + ".bak")
	ok("previous_save_kept_as_bak", bak is Dictionary and bak["flags"].has("audit_a") and not bak["flags"].has("audit_b"))
	ok("main_is_latest", (_read(game.SAVE_PATH) as Dictionary)["flags"].has("audit_b"))
	# a crash in the middle of an old-style in-place write: the main file is cut short
	_write(game.SAVE_PATH, '{"version": 1, "flags": {"audit_')
	ok("truncated_main_still_has_save", game.has_save())
	game.flags.clear()
	ok("truncated_main_loads_bak", game.load_game() and game.has_flag("audit_a") and not game.has_flag("audit_b"))
	# the main file is gone altogether
	_rm(game.SAVE_PATH)
	game.flags.clear()
	ok("missing_main_loads_bak", game.has_save() and game.load_game() and game.has_flag("audit_a"))
	# a stale half-written temp file from an earlier crash never blocks the next save
	_write(game.SAVE_PATH + ".tmp", "{ half")
	game.flags["audit_c"] = true
	ok("save_over_stale_tmp", game.save_game() and not FileAccess.file_exists(game.SAVE_PATH + ".tmp"))
	ok("latest_after_stale_tmp", (_read(game.SAVE_PATH) as Dictionary)["flags"].has("audit_c"))
	# no_save mode (the trailer) still writes nothing
	var before := FileAccess.get_file_as_string(game.SAVE_PATH)
	game.no_save = true
	game.flags["audit_d"] = true
	ok("no_save_writes_nothing", not game.save_game() and FileAccess.get_file_as_string(game.SAVE_PATH) == before)
	game.no_save = false
	for p in _paths():
		_rm(p)
		if _backup[p] != null:
			_write(p, _backup[p])
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
