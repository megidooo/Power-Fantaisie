@tool
extends CompositorEffect
class_name RayMarcher

@export_group("Shader Settings")
@export var parametres = Vector4(0.93, 30., 1., 0.68)


var rd: RenderingDevice


var raymarching_compute: ACompute

var x_groups
var y_groups



#endregion 


func _init():
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

	raymarching_compute = ACompute.new("RayMarchingSDF")




func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		raymarching_compute.free()


func _render_callback(p_effect_callback_type, p_render_data):
	if not enabled:
		return
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not rd:
		push_error("No rendering device")
		return

	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	var render_scene_data = p_render_data.get_render_scene_data()

	if not render_scene_buffers:
		push_error("No buffer to render to")
		return
	if not render_scene_data:
		push_error("No scene data")
		return

	var size = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		push_error("Rendering to 0x0 buffer")
		return
	x_groups = (size.x-1)/8+1;
	y_groups = (size.y-1)/8+1;
	var push_constant = PackedFloat32Array([
		size.x,
		size.y,
		Time.get_ticks_msec() / 1000.0,
		0.0
	]).to_byte_array()

	for view in range(render_scene_buffers.get_view_count()):
		_render_view(render_scene_buffers, render_scene_data, view, Vector2i(x_groups,y_groups), push_constant)


func _render_view(render_scene_buffers, render_scene_data, view, groups, push_constant):
	var input_image = render_scene_buffers.get_color_layer(view)
	
	var uniform_array = PackedFloat32Array([
		parametres.x,
		parametres.y,
		parametres.z,
		parametres.w
	])

	_setupRayMarcherUniforms(render_scene_data, view, uniform_array)

	raymarching_compute.set_texture(0, input_image)
	raymarching_compute.set_uniform_buffer(1, uniform_array.to_byte_array())
	raymarching_compute.set_push_constant(push_constant)
	raymarching_compute.dispatch(0, groups.x, groups.y, 1)





func _setupRayMarcherUniforms(render_scene_data, view, uniform_array: PackedFloat32Array):
	var projectionMatrix: Projection = render_scene_data.get_view_projection(view)
	_pack_4x4_matrix(uniform_array, projectionMatrix.inverse())

	var cam_transform: Transform3D = render_scene_data.get_cam_transform()

	uniform_array.append(cam_transform.origin.x)
	uniform_array.append(cam_transform.origin.y)
	uniform_array.append(cam_transform.origin.z)
	uniform_array.append(0.0)

	_pack_transform(uniform_array, cam_transform)


func _pack_4x4_matrix(arr: PackedFloat32Array, p: Projection):
	for col in [p.x, p.y, p.z, p.w]:
		arr.append(col.x); arr.append(col.y)
		arr.append(col.z); arr.append(col.w)


func _pack_transform(arr: PackedFloat32Array, t: Transform3D):
	var b = t.basis
	arr.append(b.x.x); arr.append(b.x.y); arr.append(b.x.z); arr.append(0.0)
	arr.append(b.y.x); arr.append(b.y.y); arr.append(b.y.z); arr.append(0.0)
	arr.append(b.z.x); arr.append(b.z.y); arr.append(b.z.z); arr.append(0.0)
	arr.append(t.origin.x); arr.append(t.origin.y); arr.append(t.origin.z); arr.append(1.0)
