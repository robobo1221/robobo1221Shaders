float getTerrainBump(vec2 posxz){
	vec2 coord0 = (posxz) / 100.0;
	vec2 coord1 = (posxz - frameTimeCounter * 0.25) / 100.0;
	
	float noise = texture2D(noisetex, coord0).x;
	noise += texture2D(noisetex, coord1 * 2.0).x * 0.5;
	
	return noise * 0.1 * wetness;
	
}

vec3 getTerrainHeight(vec2 posxz){

	vec2 coord = posxz;

		float deltaPos = 0.22;

		float h0 = getTerrainBump(coord);
		float h1 = getTerrainBump(coord + vec2(deltaPos,0.0));
		float h2 = getTerrainBump(coord + vec2(-deltaPos,0.0));
		float h3 = getTerrainBump(coord + vec2(0.0,deltaPos));
		float h4 = getTerrainBump(coord + vec2(0.0,-deltaPos));

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}