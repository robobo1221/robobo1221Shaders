float getTerrainBump(vec2 posxz){
	float time = frameTimeCounter * 0.5;

	vec2 coord0 = (posxz + time) * 0.01;
	vec2 coord1 = (posxz - time) * 0.01;
	
	float noise = texture2D(noisetex, coord0).x;
		  noise += texture2D(noisetex, coord1).x;
	
	return (noise * 0.05) * wetness;
	
}

vec3 getTerrainHeight(vec2 posxz){

	vec2 coord = posxz;

		float deltaPos = 0.1;

		float h0 = getTerrainBump(coord);
		float h1 = getTerrainBump(coord + vec2(deltaPos,0.0));
		float h2 = getTerrainBump(coord + vec2(0.0,deltaPos));

		float xDelta = (h0 - h1) * 10.0;
		float yDelta = (h0 - h2) * 10.0;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow2(abs(xDelta+yDelta))));

		return wave;
}