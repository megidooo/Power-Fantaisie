@tool
extends CompositorEffect
class_name TangentFluid
@export var Debug = Vector4(0.,0.,0.,0.)

var rd : RenderingDevice
var tangent_fluid_compute : ACompute

var tangent_field : RID

#On crée deux buffers dans le format compatible avec RenderingDevice
var texture_a: RID  
var texture_b: RID
#On cree deux RDUniforms qu'on pourra swapper dans le sampler
var u_a : RDUniform
var u_b : RDUniform
var sampler_rid
var flipflop = false

var x_groups
var y_groups

func _init():
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

	# To make use of an existing ACompute shader we use its filename to access it, in this case, the example compute shader file is 'exposure_example.acompute'
	tangent_fluid_compute = ACompute.new('tangent_fluid')
	
	

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# ACompute will handle the freeing of any resources attached to it
		tangent_fluid_compute.free()


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
	x_groups = (size.x - 1) / 8 + 1
	y_groups = (size.y - 1) / 8 + 1
	for view in range(render_scene_buffers.get_view_count()):
		
		var input_image = render_scene_buffers.get_color_layer(view)
		tangent_fluid_compute.set_texture(0, input_image)
		tangent_fluid_compute.set_texture(1, tangent_field)
		var push_constant : PackedFloat32Array = PackedFloat32Array([Debug.x, Debug.y, Debug.z,Debug.w,size.x,size.y,0.,0.])
		tangent_fluid_compute.set_push_constant(push_constant.to_byte_array())
	
		
		tangent_fluid_compute.dispatch(0,x_groups,y_groups,1)
		# ACompute handles uniform caching under the hood, as long as the exposure value doesn't change or the render target doesn't change, these functions will only do work once

func _create_tex(size,rid):
	
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


func _AddHole(size):
	_SwapBuffers()
	#On envoie nos floats dans la push constante
	var push_constant : PackedFloat32Array = PackedFloat32Array([Debug.x, Debug.y, Debug.z,Debug.w,size.x,size.y,0.,0.])
	tangent_fluid_compute.set_push_constant(push_constant.to_byte_array())
	
	tangent_fluid_compute.dispatch(3, x_groups, y_groups, 1)

func _SwapBuffers():
	if flipflop:
		tangent_fluid_compute.cache_uniform(u_a)
		tangent_fluid_compute.set_texture(1, texture_b)
	else:
		tangent_fluid_compute.cache_uniform(u_b)
		tangent_fluid_compute.set_texture(1, texture_a)

func _InitialisationSampler():
	
	var sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	
	sampler_rid = tangent_fluid_compute.rd.sampler_create(sampler_state)

	u_a = RDUniform.new()
	u_a.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_a.binding = 0
	u_a.add_id(sampler_rid)
	u_a.add_id(texture_a)
	
	u_b = RDUniform.new()
	u_b.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_b.binding = 0
	u_b.add_id(sampler_rid)
	u_b.add_id(texture_b)
	
	tangent_fluid_compute.cache_uniform(u_a)
	tangent_fluid_compute.set_texture(1, texture_b)
	
	
