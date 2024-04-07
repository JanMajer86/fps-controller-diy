extends CharacterBody3D

# Player Nodes

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var standing_collision = $StandingCollisionShape
@onready var crouching_collision = $CrouchingCollisionShape
@onready var ray_checker = $RayChecker

# Speed Variables

var current_speed = 5.0
const walking_speed = 5.0
const sprinting_speed = 8.0
const crouching_speed = 3.0

# Movement Variables

var crouching_depth = -0.5
const jump_velocity = 4.5
var lerp_speed = 10.0

# Input Variables

const mouse_sensitivity = 0.25
var direction = Vector3.ZERO

# Headbob Variables
const bob_freq = 2.0
const bob_amp = 0.08
var t_bob = 0.0

# FOV Variables
const base_fov = 75.0
const fov_change = 0.2

# Footstep Variables
var can_play : bool = true
signal step

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	head.position.y = 1.8

func _input(event):
	# MOUSE LOOK
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(- event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(- event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	# QUIT WITH ESC KEY
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _physics_process(delta):
	# Add the gravity.
	if !is_on_floor():
		velocity.y -= gravity * delta
	# Sprinting && Crouching
	if Input.is_action_pressed("crouch"):
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta * lerp_speed)
		standing_collision.disabled = true
		crouching_collision.disabled = false
	elif !ray_checker.is_colliding():
		standing_collision.disabled = false
		crouching_collision.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
		if Input.is_action_pressed("sprint"):
			current_speed = sprinting_speed
		else:
			current_speed = walking_speed
		
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	if is_on_floor():
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
	else:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 3.0)
		velocity.y = lerp(velocity.y, direction.y * current_speed, delta * 3.0)
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	move_and_slide()
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, sprinting_speed * 2)
	var target_fov = base_fov + fov_change * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 40.0)

func _headbob(time):
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq / 2) * bob_amp
	
	var low_pos = bob_amp - 0.05
	if pos.y > -low_pos:
		can_play = true
	if pos.y < - low_pos && can_play:
		can_play = false
		emit_signal("step")
		
	
	return pos
