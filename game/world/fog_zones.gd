extends Node
## THE VEIL - local fog: Greyhaven's outdoor mist stays as the chapters set it, but
##   * below the town (any underground area: the camera under y -1) the height fog - which thickens with depth
##     below its 3 m line and swallowed the tunnels whole - is off and the distance fog is lighter, so nearby walls
##     read clearly, mid-distance passages are navigable and only the far ones fade;
##   * by the maintenance station the fog is lighter so its entrance and equipment read.
## Chapters keep setting fog_density at their story moments: whatever they last set is the base this scales.
## Settings follow the camera every 0.1 s, so leaving, entering and loading all restore the right values.

const UNDER_Y := -1.0
const UNDER_MULT := 0.45
const STATION := Vector3(-80.0, 0.0, -28.0)
const STATION_R := 30.0
const STATION_MULT := 0.5

var world: Node
var _t := 0.0
var _base_d := -1.0
var _base_h := -1.0
var _wrote_d := -1.0
var _wrote_h := -1.0
var mode := ""                          ## tests: "", "under", "station"


func setup(w: Node) -> void:
	world = w


func _env() -> Environment:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.environment:
		return cam.environment
	return world.get_world_3d().environment if world.is_inside_tree() else null     # the active one (there are two nodes)


func _process(delta: float) -> void:
	_t -= delta
	if world == null or _t > 0.0:
		return
	_t = 0.1
	var env := _env()
	var cam := get_viewport().get_camera_3d()
	if env == null or cam == null:
		return
	# adopt what the chapters (or the night preset) set since our last write
	if not is_equal_approx(env.fog_density, _wrote_d):
		_base_d = env.fog_density
	if not is_equal_approx(env.fog_height_density, _wrote_h):
		_base_h = env.fog_height_density
	var p := cam.global_position
	mode = "under" if p.y < UNDER_Y else ("station" if Vector2(p.x - STATION.x, p.z - STATION.z).length() < STATION_R else "")
	var d := _base_d * (UNDER_MULT if mode == "under" else (STATION_MULT if mode == "station" else 1.0))
	var h := 0.0 if mode == "under" else _base_h
	env.fog_density = d
	env.fog_height_density = h
	_wrote_d = env.fog_density
	_wrote_h = env.fog_height_density


## The fog density as the story set it (before the local scaling): what chapters treat as "normal".
func base_density(env: Environment) -> float:
	return _base_d if _base_d >= 0.0 else env.fog_density
