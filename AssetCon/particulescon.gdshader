shader_type spatial;
render_mode unshaded;


uniform vec2 presence =vec2(0.0,1.);
uniform sampler2D photo;
uniform float scale =0.05;
uniform int nombre = 3;
varying vec4 custom;
uniform bool alpha =false;


uniform vec4 _Couleur : source_color = vec4(1.0);

uniform vec2 view_sphere =vec2(0.0,1.);
uniform float _AjustementTaille = 1.;

varying vec3 local_pos;
varying vec2 offset;

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}
void vertex() {
	local_pos = VERTEX;
	custom = INSTANCE_CUSTOM;
	offset = vec2(floor(COLOR.x*float(nombre)),floor(COLOR.y*float(nombre)));

	float hit_sphere = smoothstep(view_sphere.x,view_sphere.y,custom.w);

	VERTEX=VERTEX*(1.-smoothstep(presence.x,presence.y,custom.w))*_AjustementTaille*hit_sphere;
	//VERTEX=VERTEX*smoothstep(presence.x,presence.y,custom.w)*_AjustementTaille*hit_sphere;
}

void fragment() {
	vec2 nuv =UV/vec2(float(nombre));
	nuv += vec2(1./float(nombre),1./float(nombre))*offset;

	float fac = local_pos.y;
	float maxA = max(max(abs(COLOR.y),abs(COLOR.x)),COLOR.z);
	vec3 vecCol = mix(vec3(1.,0.,0.),vec3(0.,1.,0.), float(maxA==abs(COLOR.y)));
	vecCol = mix(vecCol,vec3(0.,0.,1.), float(maxA==abs(COLOR.z)));



	vec4 col = vecCol.xyzz;
	col = mix(COLOR,custom,0.5)*100.*COLOR.a*_Couleur;



	ALBEDO = texture(photo,nuv).xyz;
	//ALBEDO = offset.xyy;
	if(alpha){
		ALPHA = texture(photo,nuv).w;
	}

}
