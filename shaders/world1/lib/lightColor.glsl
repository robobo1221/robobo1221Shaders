vec3 getAmbienLight(){
	
	vec3 ambientColor = vec3(0.1, 0.1, 0.1);

	return clamp(ambientColor, 0.0, 1.0);
}

vec3 ambientlight = getAmbienLight();
