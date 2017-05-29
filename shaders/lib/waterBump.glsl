float getWaterBump(vec3 posxz, float waveM, float waveZ, float iswater){

	float radiance = 0.5;

	mat2 rotationMatrix = mat2(vec2(cos(radiance), -sin(radiance)),
						vec2(sin(radiance), cos(radiance)));
						
	radiance = -0.5;

	mat2 rotationMatrix2 = mat2(vec2(cos(radiance), -sin(radiance)),
						vec2(sin(radiance), cos(radiance)));
	
	float wave = 0.0;
	vec2 movement = abs(vec2(0.0, -frameTimeCounter * 0.0003));

	vec2 waveMovement = movement * waveM * 697.0;
	vec2 wavePosition = (posxz.xz - posxz.y) * waveZ;
	
	vec2 coord0 = (wavePosition * rotationMatrix) + waveMovement;
	vec2 coord1 = (wavePosition * rotationMatrix2) + waveMovement;
	vec2 coord2 = wavePosition + (waveMovement * 0.5);
	
	coord0.y *= 3.0;
	coord1.y *= 3.0;
	coord2.y *= 3.0;
	
	wave += 1.0 - noise(coord0) * 10.0;
	wave += 1.0 - noise(coord1) * 10.0;
	wave += pow(noise(coord2 * 4.0) * 6.5, 0.5) * 1.7;
	wave += pow(noise(coord2 * 8.0) * 6.5, 0.5) * 0.7;
	
	wave *= mix(0.3,1.0,iswater);
	wave *= 0.0157;
	
	return wave;
	
}

vec3 getWaveHeight(vec3 posxz, float iswater){

	vec3 coord = posxz;

	float deltaPos = 0.5;
	
	float waveZ = mix(2.0,0.25,iswater);
	float waveM = mix(0.0,2.0,iswater);

	float h0 = getWaterBump(coord, waveM, waveZ, iswater);
	float h1 = getWaterBump(coord + vec3(deltaPos,0.0, 0.0), waveM, waveZ, iswater);
	float h2 = getWaterBump(coord + vec3(0.0,deltaPos, 0.0), waveM, waveZ, iswater);

	float xDelta = -(h0 - h1)/deltaPos;
	float yDelta = -(h0 - h2)/deltaPos;

	vec3 wave = normalize(vec3(xDelta, yDelta, 0.5));

	return wave;
}