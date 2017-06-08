float getTerrainBump(vec2 posxz){
	vec2 coord0 = (posxz + frameTimeCounter * 0.5) * 0.01;
	vec2 coord1 = (posxz - frameTimeCounter * 0.5) * 0.01;
	
	float noise = texture2D(noisetex, coord0).x;
		  noise += texture2D(noisetex, coord1).x;
	
	return noise * 0.1 * wetness;
	
}

vec3 getTerrainHeight(vec2 posxz){

	vec2 coord = posxz;

		float deltaPos = 0.1;

		float h0 = getTerrainBump(coord);
		float h1 = getTerrainBump(coord + vec2(deltaPos,0.0));
		float h2 = getTerrainBump(coord + vec2(0.0,deltaPos));

		float xDelta = (h0 - h1) / deltaPos;
		float yDelta = (h0 - h2) / deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}