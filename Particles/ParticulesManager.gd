extends MultiMeshInstance3D

@export var nombreParticule : int
@export var vitesseInitialeParticule := 1.
@export var parametres := Vector4 (1,1,1,1)

var camera: Camera3D
var view_dir: Vector3
var inv_proj: Projection
var inv_view_matrix: Transform3D
var view_matrix: Transform3D


var rd : RenderingDevice

var particule_buffer
var instance_buffer

var simulation_compute: ACompute

var push : PackedByteArray

var x_groups
var y_groups 

var TIME : float = 0;

#setup multimesh
var multimesh_rid: RID
var multimesh_particule_buffer_rid : RID
var multimesh_cmd_buffer_rid : RID

func _ready():
	camera = get_viewport().get_camera_3d();
	rd = RenderingServer.get_rendering_device()
	
	#Le nom doit être exact
	simulation_compute = ACompute.new('ParticuleSim')
	
	
	
	
	_setupMultimesh()
	
	_setupSimulation()
	_configPush(0.)
	simulation_compute.dispatch(0,x_groups,1,1)
	
	
	
	var buffer = rd.buffer_get_data(multimesh_particule_buffer_rid).to_float32_array()
	multimesh.buffer = buffer

	
	

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		simulation_compute.free()
		

func _process(_delta):
	TIME+=_delta
	
	
	
	_setCameraData()
	_updateMultimesh(_delta)
	
func _setupMultimesh():
	
	
	
	multimesh_rid = multimesh.get_rid()
	multimesh.instance_count = 0
	
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = nombreParticule
	
	
	multimesh_particule_buffer_rid = RenderingServer.multimesh_get_buffer_rd_rid(multimesh_rid)
	multimesh_cmd_buffer_rid = RenderingServer.multimesh_get_command_buffer_rd_rid(multimesh_rid)
	
func _setCameraData():
	view_dir = -camera.global_transform.basis.z
	var proj = camera.get_camera_projection()
	inv_proj = proj.inverse()
	view_matrix = camera.get_camera_transform().inverse()
	inv_view_matrix = camera.get_camera_transform()
	#Array Info Camera
	var uniform_array = PackedFloat32Array([parametres.x, parametres.y, parametres.z, parametres.w])
		
	#Projection matrix

	_pack_4x4_matrix(uniform_array, inv_proj)

	uniform_array.append(inv_view_matrix.origin.x)
	uniform_array.append(inv_view_matrix.origin.y)
	uniform_array.append(inv_view_matrix.origin.z)
	uniform_array.append(0.0) # padding
	
	_pack_transform(uniform_array,inv_view_matrix)
	uniform_array = uniform_array.to_byte_array()

	simulation_compute.set_uniform_buffer(1, uniform_array)

func _setupSimulation():
	x_groups = (nombreParticule+255)/256;

	
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform.binding = 0
	data_uniform.add_id(multimesh_particule_buffer_rid) 
	simulation_compute.cache_uniform(data_uniform)
	_setCameraData()
	

	
	

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

	
	
func _updateMultimesh(delta):
	#RenderingServer.multimesh_allocate_data(multimesh_rid,nombreParticule,RenderingServer.MULTIMESH_TRANSFORM_3D,true,true,true)
	_configPush(delta)
	
	simulation_compute.dispatch(1,x_groups,1,1)

	
func _configPush(_delta):
	#Envoi de la push constant
	push = PackedFloat32Array([_delta, vitesseInitialeParticule,float(nombreParticule), TIME]).to_byte_array()
	simulation_compute.set_push_constant(push)
