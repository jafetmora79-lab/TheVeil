extends Node
## THE VEIL - game state (autoload "Game"): story flags, objectives, inventory, interaction states,
## save / load and settings. Data lives in game/data/*.json so gameplay code stays generic.

signal objective_changed(goal: String, step: String)
signal inventory_changed
signal flag_set(flag: String)
signal settings_changed

const SAVE_PATH := "user://veil_save.json"
const SETTINGS_PATH := "user://veil_settings.cfg"
const SAVE_VERSION := 1

var flags := {}
var inventory: Array = []
## per-interactable state, keyed by a stable id (node path inside the world): {"open": bool, "taken": bool}
var world_state := {}
## {"in_vehicle": bool, "pos": [x,y,z], "yaw": float}
var player_state := {}
## {"pos": [x,y,z], "yaw": float}
var vehicle_state := {}
var items := {}
var objectives: Array = []
var goals := {}
var settings := {"mouse_sensitivity": 0.22, "master_volume": 0.8, "fullscreen": false, "head_bob": true}
## set by the menu: the world reads it on start (true = restore the save instead of a new game)
var load_requested := false
var play_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_data()
	load_settings()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------------ input map (defined in code: WASD by physical key)
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "interact": [KEY_E],
		"inventory": [KEY_TAB, KEY_I], "pause": [KEY_ESCAPE, KEY_P], "handbrake": [KEY_SPACE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ data
func _load_data() -> void:
	items = _read_json("res://game/data/items.json")
	var od: Dictionary = _read_json("res://game/data/objectives.json")
	objectives = od.get("steps", [])
	goals = od.get("goals", {})


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing data file " + path)
		return {}
	return JSON.parse_string(f.get_as_text())


# ------------------------------------------------------------------ new game
func new_game() -> void:
	flags = {}
	inventory = []
	world_state = {}
	player_state = {}
	vehicle_state = {}
	play_time = 0.0
	load_requested = false


# ------------------------------------------------------------------ flags + objectives
func has_flag(f: String) -> bool:
	return flags.get(f, false)


func set_flag(f: String) -> void:
	if has_flag(f):
		return
	flags[f] = true
	print("[Game] flag ", f)
	flag_set.emit(f)
	_emit_objective()


func current_step() -> Dictionary:
	for o in objectives:
		if not has_flag(o["flag"]):
			return o
	return {}


func current_goal() -> String:
	var step := current_step()
	if step.is_empty():
		return goals.get("done", "")
	return goals.get(step.get("goal", ""), "")


func _emit_objective() -> void:
	var s := current_step()
	objective_changed.emit(current_goal(), s.get("text", ""))


func refresh_objective() -> void:
	_emit_objective()


# ------------------------------------------------------------------ inventory
func add_item(id: String) -> void:
	if id in inventory and (shelter_resource(id).is_empty() or id == "batteries"):
		return
	inventory.append(id)
	inventory_changed.emit()


func remove_item(id: String) -> void:
	if id in inventory:
		inventory.erase(id)
		inventory_changed.emit()


func has_item(id: String) -> bool:
	return id in inventory


func item_info(id: String) -> Dictionary:
	return items.get("items", {}).get(id, {"name": id, "category": "misc", "description": ""})


# ------------------------------------------------------------------ communal shelter supplies
const SUPPLY_TYPES := ["food", "water", "medical", "batteries"]

func shelter_resource(id: String) -> String:
	var resource: String = item_info(id).get("shelter_resource", "")
	return resource if resource in SUPPLY_TYPES else ""

func shelter_stock() -> Dictionary:
	return world_state.get("shelter_stock", {"food": 0, "water": 0, "medical": 0, "batteries": 0})

func record_shelter_night(transition: String, roster: Array, rates: Dictionary) -> Dictionary:
	var history: Dictionary = world_state.get("shelter_nights", {})
	if history.has(transition):
		return {}
	var stock := shelter_stock()
	var report := {"roster": roster.duplicate()}
	for resource in ["food", "water"]:
		var demand := maxi(0, int(rates.get(resource, 1))) * roster.size()
		var used := mini(demand, int(stock[resource]))
		stock[resource] = int(stock[resource]) - used
		report[resource + "_used"] = used
		report[resource + "_left"] = stock[resource]
		report[resource + "_needed"] = demand
	history[transition] = report
	world_state["shelter_stock"] = stock
	world_state["shelter_nights"] = history
	world_state["shelter_latest_report"] = report
	return report


# ------------------------------------------------------------------ save / load
func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d: Variant = _read_save()
	return d is Dictionary and d.get("version", 0) == SAVE_VERSION


func _read_save() -> Variant:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


## The world fills player_state / vehicle_state before calling this.
func save_game() -> bool:
	var d := {"version": SAVE_VERSION, "flags": flags, "inventory": inventory, "world_state": world_state,
		"player": player_state, "vehicle": vehicle_state, "play_time": play_time,
		"saved_at": Time.get_datetime_string_from_system()}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


func load_game() -> bool:
	var d: Variant = _read_save()
	if not (d is Dictionary) or d.get("version", 0) != SAVE_VERSION:
		return false
	flags = d.get("flags", {})
	inventory = d.get("inventory", [])
	world_state = d.get("world_state", {})
	player_state = d.get("player", {})
	vehicle_state = d.get("vehicle", {})
	play_time = d.get("play_time", 0.0)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	var v: float = clampf(settings["master_volume"], 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)
	if OS.get_name() != "Web":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(want)
	settings_changed.emit()


func set_fullscreen(on: bool) -> void:
	settings["fullscreen"] = on
	if OS.get_name() == "Web":
		# browsers only allow fullscreen from a user gesture; the button press is one
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()
