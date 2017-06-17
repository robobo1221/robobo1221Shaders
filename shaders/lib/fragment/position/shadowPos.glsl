mat4 screenToShadowMat = shadowProjection * shadowModelView * gbufferModelViewInverse;

vec3 toShadowSpace(vec3 p3){
	p3.xy *= 1.0 - 0.183 * isEyeInWater;

    p3 = mat3(screenToShadowMat) * p3 + screenToShadowMat[3].xyz;

    return p3;
}

float getDistordFactor(vec3 worldposition){
	vec2 pos1 = abs(worldposition.xy * 1.2);

	float distb = pow(pow(pos1.x, 8.) + pow(pos1.y, 8.), 1.0 / 8.0);
	return (1.0 - SHADOW_BIAS) + distb * SHADOW_BIAS;
}

vec3 biasedShadows(vec3 worldposition){

	float distortFactor = getDistordFactor(worldposition);

	worldposition.xy /= distortFactor;
	worldposition = worldposition * vec3(0.5,0.5,0.2) + vec3(0.5,0.5,0.5);

	return worldposition;
}