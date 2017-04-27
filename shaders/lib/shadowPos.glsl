
vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec4 getShadowSpace(float shadowdepth, vec2 texcoord){

	vec4 fragpos = nvec4(convertScreenSpaceToWorldSpace(texcoord.st,shadowdepth));
	
	if (isEyeInWater > 0.9)
	fragpos.xy *= 0.817;

	vec4 wpos = getWorldSpace(fragpos);

	//Pixel locked shadows.
	/*
	const float resourcePackRes = 16.0;

	float offset = 0.01 / resourcePackRes;
	
	wpos.rgb += cameraPosition.rgb;
	wpos.rgb += offset;													//fix z fighting.
	wpos.rgb = floor(wpos.rgb * resourcePackRes) / resourcePackRes; 	//Lock it on the pixels of a block;
	wpos.rgb -= offset;													//reverse back to lock the position back into place.
	wpos.rgb -= cameraPosition.rgb;
	*/

	wpos = shadowModelView * wpos;
	wpos = shadowProjection * wpos;

	return wpos;

}

float getDistordFactor(vec4 worldposition){
	vec2 pos1 = abs(worldposition.xy * 1.165);

	float distb = pow(pow(pos1.x, 8.) + pow(pos1.y, 8.), 1.0 / 8.0);
	return (1.0 - SHADOW_BIAS) + distb * SHADOW_BIAS;
}

vec4 biasedShadows(vec4 worldposition){

	float distortFactor = getDistordFactor(worldposition);

	worldposition.xy /= distortFactor*0.97;
	worldposition = worldposition * vec4(0.5,0.5,0.2,0.5) + vec4(0.5,0.5,0.5,0.5);

	return worldposition;
}