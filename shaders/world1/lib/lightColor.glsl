vec3 getSunlight(){

	vec3 sunlight = vec3(1.0, 0.55, 0.22) * time[0].x;
		 sunlight = mix(sunlight, vec3(1.0, 1.0, 1.0), sqrt(time[0].y));
		 sunlight = mix(sunlight, vec3(1.0, 0.55, 0.22), pow(time[1].x, 2.0));
		 sunlight = mix(sunlight, vec3(1.0, 0.3, 0.01), time[1].y);

	return clamp(sunlight, 0.0, 1.0);
}

vec3 getMoonLight(){

	vec3 moonlight = vec3(0.3, 0.55, 1.0) * 0.075;
		 moonlight = mix(moonlight, vec3(dot(moonlight, vec3(0.3333))), 0.2 * time[1].y);

	return clamp(moonlight, 0.0, 1.0);
}

vec3 getAmbienLight(){
	
	vec3 ambientColor = vec3(0.064, 0.125, 0.280) * 0.5 * time[0].x;
		 ambientColor = mix(ambientColor, vec3(0.064, 0.125, 0.280), time[0].y);
		 ambientColor = mix(ambientColor, vec3(0.064, 0.125, 0.280) * 0.5, time[1].x);
		 ambientColor /= ambientColor.b;
		 ambientColor = mix(ambientColor, vec3(0.3, 0.55, 1.0) * 0.1, time[1].y);

		 ambientColor = mix(ambientColor, vec3(dot(ambientColor, vec3(0.3333))), 0.2 * time[1].y);

		 ambientColor = mix(ambientColor, vec3(0.2) * (1.0 - time[1].y * 0.97), rainStrength);

	return clamp(ambientColor, 0.0, 1.0);
}

vec3 sunlight = getSunlight();
vec3 moonlight = getMoonLight();
vec3 ambientlight = getAmbienLight();
