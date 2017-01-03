float getWaterBump(vec2 posxz, float waveM, float waveZ, float iswater){

float radiance = 0.5;

mat2 rotationMatrix = mat2(vec2(cos(radiance), -sin(radiance)),
					vec2(sin(radiance), cos(radiance)));
					
float radiance2 = -0.5;

mat2 rotationMatrix2 = mat2(vec2(cos(radiance2), -sin(radiance2)),
					vec2(sin(radiance2), cos(radiance2)));
	
	float wave = 0.0;
	vec2 movement = abs(vec2(0.0, -frameTimeCounter * 0.0003));
	
	vec2 coord0 = posxz * waveZ * rotationMatrix + movement * waveM * 697.0;
	vec2 coord1 = posxz * waveZ * rotationMatrix2 + movement * 0.9 * waveM * 697.0;
	vec2 coord2 = posxz * waveZ + movement * 0.5 * waveM * 697.0;
	
	coord0.y *= 3.0;
	coord1.y *= 3.0;
	coord2.y *= 3.0;
	
	wave += 1.0 - noise(coord0) * 10.0;
	wave += 1.0 - noise(coord1) * 10.0;
	wave += 1.0 - noise(coord2 * 4.0) * 7.5;

	wave *= mix(0.3,1.0,iswater) * 0.1;
	wave *= 0.157;
	
	return wave;
	
}

vec3 getWaveHeight(vec2 posxz, float iswater){

	vec2 coord = posxz;

		float deltaPos = 0.25;
		
		float waveZ = mix(2.0,0.25,iswater);
		float waveM = mix(0.0,2.0,iswater);

		float h0 = getWaterBump(coord, waveM, waveZ, iswater);
		float h1 = getWaterBump(coord + vec2(deltaPos,0.0), waveM, waveZ, iswater);
		float h2 = getWaterBump(coord + vec2(-deltaPos,0.0), waveM, waveZ, iswater);
		float h3 = getWaterBump(coord + vec2(0.0,deltaPos), waveM, waveZ, iswater);
		float h4 = getWaterBump(coord + vec2(0.0,-deltaPos), waveM, waveZ, iswater);

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}