extends CharacterBody3D

var camera: Camera3D
var enabled := true
var sensitivity := 0.0025

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.84
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.56
	camera.near = 0.04
	camera.fov = 76
	add_child(camera)
	floor_snap_length = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.3, 1.3)

func _physics_process(delta: float) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var speed := 3.5 if Input.is_action_pressed("sprint") else 2.2
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0
	move_and_slide()
