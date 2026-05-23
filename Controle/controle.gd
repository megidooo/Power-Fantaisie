extends Node
@export var world_env: WorldEnvironment 
var effect
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

	effect = effects[1]
	

	
	if effect is not TangentFluid:
		push_error("mauvais effet !")
		return
	if !effect.enabled:
		push_error("active le idiot")
		return

		


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cross"):
		effect.maj_couleur = true
