@tool
extends CompositorEffect
class_name Crounche

@export_group("Shader Settings")
@export var width = 200;
var finalRes := Vector2i(200,200);
@export var coupes := 1;
@export var iterations_verticales := 50;
var iterations_horizontales = 2
var x_groups;
var y_groups;
var z_groups;
var initialized = false
var last_width = -1
var invertt = 0.
var rd : RenderingDevice
var seam_carving_compute : ACompute

var buffer_rid : RID
var small_rid : RID
var carved_rid : RID
func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

	# To make use of an existing ACompute shader we use its filename to access it, in this case, the example compute shader file is 'exposure_example.acompute'
	seam_carving_compute = ACompute.new('seam_carving')
	
	

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# ACompute will handle the freeing of any resources attached to it
		seam_carving_compute.free()

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
	if (!initialized) or last_width!=width:
		finalRes.x = width;
		finalRes.y = int(finalRes.x*size.y/size.x);
		buffer_rid = _create_tex(finalRes,buffer_rid);
		
		small_rid = _create_tex(finalRes,small_rid);
		carved_rid = _create_tex(finalRes,carved_rid);
		
		seam_carving_compute.set_texture(1, buffer_rid)
		seam_carving_compute.set_texture(2, small_rid)
		seam_carving_compute.set_texture(3, carved_rid)
		x_groups = (size.x - 1) / 8 + 1
		y_groups = (size.y - 1) / 8 + 1
		z_groups = 1
		last_width = width
		initialized = true;
		
	iterations_horizontales = ceil(iterations_verticales*size.y/size.x)
	
	
	var nombre_coupesV = max(int(coupes),1);
	
	var nombre_coupesH = max(int(coupes*size.y/size.x),1);
	
	
	
	
	# Vulkan has a feature known as push constants which are like uniform sets but for very small amounts of data
	
	for view in range(render_scene_buffers.get_view_count()):
		
		var input_image = render_scene_buffers.get_color_layer(view)
		seam_carving_compute.set_texture(0, input_image)
		
		var push_constant : PackedFloat32Array = PackedFloat32Array([size.x, size.y, finalRes.x,finalRes.y,nombre_coupesV,0.,nombre_coupesH,invertt])
		seam_carving_compute.set_push_constant(push_constant.to_byte_array())
		# ACompute handles uniform caching under the hood, as long as the exposure value doesn't change or the render target doesn't change, these functions will only do work once
	
		var resSmall = finalRes;
		
		var sx_groups = (finalRes.x - 1) / 8 + 1
		var sy_groups = ((finalRes.y) - 1) / 8 + 1
		var sz_groups = 1
		
		# Downsize
		seam_carving_compute.dispatch(0, sx_groups, sy_groups, sz_groups);
		
		
		
		for i in range(iterations_verticales):
			
			#Sobel
			seam_carving_compute.dispatch(1,sx_groups, sy_groups, sz_groups)
			
			#EnergyMap
			for row in range(resSmall.y):
				push_constant = PackedFloat32Array([size.x, size.y, resSmall.x, resSmall.y,nombre_coupesV, float(row),nombre_coupesH, invertt])
				seam_carving_compute.set_push_constant(push_constant.to_byte_array())
				seam_carving_compute.dispatch(2, sx_groups, 1, 1)
			
			#SeamCarving
			seam_carving_compute.dispatch(3,nombre_coupesV, 1, 1)
		 
			#SeamSkipping
			seam_carving_compute.dispatch(4,sx_groups, sy_groups, sz_groups)
			
			resSmall.x-=nombre_coupesV;
			
			push_constant = PackedFloat32Array([size.x, size.y, resSmall.x,resSmall.y,nombre_coupesV,0.,nombre_coupesH,invertt]);
			seam_carving_compute.set_push_constant(push_constant.to_byte_array())
			
			sx_groups = (resSmall.x - 1) / 8 + 1
			sy_groups = (resSmall.y - 1) / 8 + 1
			sz_groups = 1 
			
			seam_carving_compute.dispatch(5,sx_groups, sy_groups, sz_groups)
			
		for i in range(iterations_horizontales):
			
			#Sobel
			seam_carving_compute.dispatch(1,sx_groups, sy_groups, sz_groups)
			
			#EnergyMap
			for col in range(resSmall.x):
				push_constant = PackedFloat32Array([size.x, size.y, resSmall.x, resSmall.y,nombre_coupesV, float(col),nombre_coupesH, invertt])
				seam_carving_compute.set_push_constant(push_constant.to_byte_array())
				seam_carving_compute.dispatch(7, sy_groups, 1, 1)
			
			#SeamCarving
			seam_carving_compute.dispatch(8,nombre_coupesH, 1, 1)
		 
			#SeamSkipping
			seam_carving_compute.dispatch(9,sx_groups, sy_groups, sz_groups)
			
			resSmall.y-=nombre_coupesH;
			
			push_constant = PackedFloat32Array([size.x, size.y, resSmall.x,resSmall.y,nombre_coupesV,0.,nombre_coupesH,invertt]);
			seam_carving_compute.set_push_constant(push_constant.to_byte_array())
			
			sx_groups = (resSmall.x - 1) / 8 + 1
			sy_groups = (resSmall.y - 1) / 8 + 1
			sz_groups = 1 
			
			seam_carving_compute.dispatch(5,sx_groups, sy_groups, sz_groups)
		
		#Upsizing
		
		seam_carving_compute.dispatch(6,x_groups, y_groups, z_groups)
