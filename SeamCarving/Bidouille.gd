extends Node3D

# Reference to the WorldEnvironment node
@export var world_env: WorldEnvironment 
@export var particules: MultiMeshInstance3D
@export var character: Node3D
var mat
var base_iterations
var effect
var step =0.001;
var sineSpeed =0.001;


func _ready() -> void:
	
	print (world_env, "allo")
	var env: Environment = world_env.environment

	if env == null:
		push_error("pas d'enviro")
		return

	var compositor: Compositor = world_env.compositor

	if compositor == null:
		push_error("pas de compositor")
		return

	# Get the first compositing effect from the compositor
	var effects: Array = compositor.compositor_effects

	if effects.is_empty():
		push_error("pas d'effets")
		return

	effect = effects[0]
	

	
	if effect is not Crounche:
		push_error("mauvais effet !")
		return
	if !effect.enabled:
		push_error("active le idiot")
		return
	base_iterations = effect.iterations_verticales;
	mat = particules.multimesh.mesh.surface_get_material(0)
		

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("faster_rot"):
		particules.parametres.x = clampf(particules.parametres.x + 0.1,0.,3.)
	elif event.is_action_pressed("slower_rot"):
		particules.parametres.x = clampf(particules.parametres.x - 0.1,0.,3.)
	
	if event.is_action_pressed("faster_flow"):
		particules.parametres.y = clampf(particules.parametres.y+0.5,0.1,10.)
	elif event.is_action_pressed("slower_flow"):
		particules.parametres.y = clampf(particules.parametres.y-0.5,0.1,10.)
	
	
	if event.is_action_pressed("faster_player"):
		character.pspeed =clampf(character.pspeed + 0.005,0.,100.)
		
		
	elif event.is_action_pressed("slower_player"):
		character.pspeed =clampf(character.pspeed - 0.005,0.,100.)
		
	if event.is_action_pressed("contours"):
		
		var cur = mat.get_shader_parameter("alpha")
		mat.set_shader_parameter("alpha", !cur)
		
	if event.is_action_pressed("invertt"):
		
		var cur = effect.get("invertt");
		var n
		if (cur <1.):
			n =2.
		else:
			n=0.
		effect.set("invertt",n)
		
	
func _process(delta: float):
	print()
	#effect.set("iterations_verticales",int(10+(sin(Time.get_ticks_msec()*sineSpeed)/2.+1.)*base_iterations)) 
