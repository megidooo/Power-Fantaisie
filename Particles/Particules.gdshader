shader_type spatial;
render_mode unshaded;

uniform vec4 _Couleur : source_color = vec4(1.0);

uniform vec2 presence =vec2(0.0,1.);
uniform vec2 view_sphere =vec2(0.0,1.);
uniform float _AjustementTaille = 1.;

varying vec3 local_pos;
varying vec4 custom;

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}
void vertex() {
	local_pos = VERTEX;
	custom = INSTANCE_CUSTOM;
	
	float hit_sphere = smoothstep(view_sphere.x,view_sphere.y,custom.w);
	
	VERTEX=VERTEX*map(COLOR.a,0.,1.,0.01,0.05)*smoothstep(5.,2.,custom.w)*_AjustementTaille*hit_sphere*smoothstep(presence.x,presence.y,length(COLOR.xyz));
}

void fragment() {
	ALBEDO = texture(photo,UV).xyz;
	float fac = local_pos.y;
	float maxA = max(max(abs(COLOR.y),abs(COLOR.x)),COLOR.z);
	vec3 vecCol = mix(vec3(1.,0.,0.),vec3(0.,1.,0.), float(maxA==abs(COLOR.y)));
	vecCol = mix(vecCol,vec3(0.,0.,1.), float(maxA==abs(COLOR.z)));

	
	
	vec4 col = vecCol.xyzz;
	col = mix(COLOR,custom,0.5)*100.*COLOR.a*_Couleur;
	
	 //col = vec4(custom.w);
	
	ALBEDO = col.xyz;
	//ALPHA = 1.;
}
