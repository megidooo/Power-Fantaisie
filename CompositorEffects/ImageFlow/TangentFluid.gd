@tool
extends CompositorEffect
class_name TangentFluid
@export var Debug = Vector4(0.,0.,0.,0.)

var rd : RenderingDevice
var tangent_fluid_compute : ACompute

var tangent_field : RID

var sampler_rid : RID
#On crée deux buffers dans le format compatible avec RenderingDevice
var texture_a: RID  
var texture_b: RID
#On cree deux RDUniforms qu'on pourra swapper dans le sampler
var u_a : RDUniform
var u_b : RDUniform

var flipflop = false

var x_groups
var y_groups
var prev_size := Vector2i(0,0)

var maj_couleur := false

func _init():
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

	# To make use of an existing ACompute shader we use its filename to access it, in this case, the example compute shader file is 'exposure_example.acompute'
	tangent_fluid_compute = ACompute.new('tangent_fluid')
	
	_initialisation_sampler()
	

		
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# ACompute will handle the freeing of any resources attached to it
		tangent_fluid_compute.free()
		if texture_a.is_valid(): rd.free_rid(texture_a)
		if texture_b.is_valid(): rd.free_rid(texture_b)
		if tangent_field.is_valid(): rd.free_rid(tangent_field)
		if sampler_rid.is_valid(): rd.free_rid(sampler_rid)
		
		
func _render_callback(p_effect_callback_type, p_render_data):
	
	if not enabled: return
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	
	if not rd:
		push_error("No rendering device")
		return
	
	var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()

	if not render_scene_buffers:
		push_error("No buffer to render to")
		return

	
	var size = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		push_error("Rendering to 0x0 buffer")
		return
	
		
	for view in range(render_scene_buffers.get_view_count()):
		
		var input_image = render_scene_buffers.get_color_layer(view)
		tangent_fluid_compute.set_texture(0, input_image)
		if(size!=prev_size):
			x_groups = (size.x - 1) / 8 + 1
			y_groups = (size.y - 1) / 8 + 1
			texture_a = _resize_tex(size,texture_a)
			texture_b = _resize_tex(size,texture_b)
			tangent_field = _resize_tex(size,tangent_field)
			maj_sampler_uniforms()
			_remplissage_initial(size,input_image)
			prev_size = size
		
		
		tangent_fluid_compute.dispatch(0,x_groups,y_groups,1)
		tangent_fluid_compute.dispatch(1,x_groups,y_groups,1)
		_swap_buffers()
		if(maj_couleur):
			_rafraichir_couleur() 
			maj_couleur = false
		
		tangent_fluid_compute.dispatch(3,x_groups,y_groups,1)

func _creer_tex(size):
	
	var fmt = RDTextureFormat.new()
	fmt.width = size.x;
	fmt.height = size.y;
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	) 
	return rd.texture_create(fmt, RDTextureView.new())

func _resize_tex(size,old_rid):
	if old_rid.is_valid():
		rd.free_rid(old_rid);
	return _creer_tex(size);

func _remplissage_initial(size,input_image):
	#premier swap pour initialiser
	_swap_buffers()
	var push_constant : PackedFloat32Array = PackedFloat32Array([Debug.x, Debug.y, Debug.z,Debug.w,size.x,size.y,0.,0.])
	tangent_fluid_compute.set_push_constant(push_constant.to_byte_array())
	tangent_fluid_compute.set_texture(0, input_image)
	tangent_fluid_compute.set_texture(1, tangent_field)
	tangent_fluid_compute.dispatch(2,x_groups,y_groups,1)
	_swap_buffers()
	

func _rafraichir_couleur():
	_swap_buffers()
	tangent_fluid_compute.dispatch(2,x_groups,y_groups,1)
	_swap_buffers()

func _swap_buffers():
	if flipflop:
		tangent_fluid_compute.cache_uniform(u_a)
		tangent_fluid_compute.set_texture(3, texture_b)
	else:
		tangent_fluid_compute.cache_uniform(u_b)
		tangent_fluid_compute.set_texture(3, texture_a)
	flipflop= !flipflop

func _initialisation_sampler():
	
	var sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	
	sampler_rid = tangent_fluid_compute.rd.sampler_create(sampler_state)
	
	#On prépare deux uniforms à swap pour changer la texture du sampler
	u_a = RDUniform.new()
	u_a.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_a.binding = 2
	u_a.add_id(sampler_rid)
	u_a.add_id(texture_a)
	
	u_b = RDUniform.new()
	u_b.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_b.binding = 2
	u_b.add_id(sampler_rid)
	u_b.add_id(texture_b)
	
	tangent_fluid_compute.cache_uniform(u_a)
	tangent_fluid_compute.set_texture(3, texture_b)
	
func maj_sampler_uniforms():
	u_a = RDUniform.new()
	u_a.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_a.binding = 2
	u_a.add_id(sampler_rid)
	u_a.add_id(texture_a)
	
	u_b = RDUniform.new()
	u_b.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_b.binding = 2
	u_b.add_id(sampler_rid)
	u_b.add_id(texture_b)
	
	
	
