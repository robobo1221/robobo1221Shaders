vec3 getDesaturation(vec3 color, float skyLightMap){
	return mix(color, vec3(dot(color, vec3(0.333))),0.9 * time[1].y * clamp(1.0 - skyLightMap,0.0,1.0));
}