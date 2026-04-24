
extends Node3D
@onready var camera := $Camera3D

var look_smoothed := Vector2.ZERO
var vel_smoothed := 0.0
@export var angle_accel := 1.0   
@export var angle_decel := 1.0 
@export var pos_accel := 1.0   
@export var pos_decel := 1.0 

@export var sens =0.01
@export var pspeed =0.01
func _process(delta: float) -> void:
	#var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3.ZERO
	var vel_mag := 0.0
	var speed = pos_decel
	direction = camera.global_transform.basis*Vector3(0,0,1)
	if Input.is_action_pressed("move_up"):
		vel_mag=-1.0
		speed = pos_accel
		
	elif Input.is_action_pressed("move_down"):
		vel_mag=1.0
		speed = pos_accel
	
	
	var t = 1.0 - exp(-speed * delta)
	vel_smoothed = vel_smoothed +t*(vel_mag-vel_smoothed)
		
	position += direction*vel_smoothed*pspeed;
		
	
	joystick_movement(delta)


func _input(event: InputEvent) -> void:
	
	if Input.MOUSE_MODE_CAPTURED :
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x*0.005)
			camera.rotate_x(-event.relative.y*0.005)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-68), deg_to_rad(60))

func floorDeadzone(s : Vector2) -> Vector2:
	var deadzone = 0.1
	var look_x = s.x
	if abs(look_x) < deadzone:
		look_x = 0
	var look_y = s.y
	if abs(look_y) < deadzone:
		look_y = 0
	return Vector2(look_x,look_y)
		

func joystick_movement(delta : float) -> void:
	
		var joy_id = 0

		# --- Read both sticks ---
		var look_r = Vector2(Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy_id, JOY_AXIS_RIGHT_Y));
		

		look_r =floorDeadzone(look_r);
		
		var look_target:= Vector2.ZERO
		var speed = angle_decel
		
		if (look_r != Vector2.ZERO):
			look_target = look_r
			speed = angle_accel

		var t = 1.0 - exp(-speed * delta)
		look_smoothed = look_smoothed.lerp(look_target, t)

		rotate_y(-look_smoothed.x*sens)
		camera.rotate_x(-look_smoothed.y*sens)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-68),
			deg_to_rad(60)
		)


func stop(distance: float = 0.2) -> Dictionary:
	var result = {"blocked": false, "up": false, "down": false}
	var space_state = get_world_3d().direct_space_state
	var origin_pos = global_transform.origin

	# Raycast vers le bas
	var down_params = PhysicsRayQueryParameters3D.create(origin_pos, origin_pos + Vector3.DOWN * distance)
	down_params.exclude = [self]
	var down_result = space_state.intersect_ray(down_params)
	if down_result.size() > 0:
		result["blocked"] = true
		result["up"] = false
		result["down"] = true
		#print("bloqué en bas !")
		
	# Raycast vers le haut
	var up_params = PhysicsRayQueryParameters3D.create(origin_pos, origin_pos + Vector3.UP * distance)
	up_params.exclude = [self]
	var up_result = space_state.intersect_ray(up_params)
	if up_result.size() > 0:
		result["blocked"] = true
		result["up"] = true
		result["down"] = false
		#print("bloqué en haut !")

	return result
