extends Node
## THE VEIL - no mirrored text anywhere. A Label3D seen from behind reads backwards (it renders both sides). Every
## fixed (non-billboard) text label the game creates is checked once it is placed: if it faces the wall it is
## mounted on (a wall right in front of it, open space behind), it is turned round to face the room; and its back
## side is switched off, so text can never be read mirrored again.

var fixed := 0                          ## tests: labels turned round
var seen := 0                           ## tests: labels made single-sided


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	for l in get_tree().root.find_children("*", "Label3D", true, false):
		_on_added(l)


func _on_added(n: Node) -> void:
	if n is Label3D:
		_fix.call_deferred(n)


func _fix(l: Label3D) -> void:
	for i in 2:
		await get_tree().physics_frame                  # placed by its creator by now
	if not is_instance_valid(l) or not l.is_inside_tree() or l.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
		return
	var space := l.get_world_3d().direct_space_state
	var n := l.global_basis.z.normalized()               # the readable side
	var at := l.global_position
	var front := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + n * 0.8, 1))
	var back := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at - n * 0.8, 1))
	var fd: float = (front["position"] as Vector3).distance_to(at) if front else INF
	var bd: float = (back["position"] as Vector3).distance_to(at) if back else INF
	if fd < 0.6 and fd < bd:
		l.global_basis = Basis(Vector3.UP, PI) * l.global_basis
		fixed += 1
	l.double_sided = false
	seen += 1
