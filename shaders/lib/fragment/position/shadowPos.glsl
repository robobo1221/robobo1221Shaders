vec3 toShadowSpace(vec3 p3){
	p3.xy *= 1.0 - 0.183 * isEyeInWater;

    p3 = toWorldSpace(gbufferModelViewInverse, p3);
	p3 = toWorldSpace(shadowModelView, p3);
	p3 = projMAD3(shadowProjection, p3);

    return p3;
}

float getDistordFactor(vec3 worldposition){
	vec2 pos1 = abs(worldposition.xy * 1.2);

	float dist = pow(pow8(pos1.x) + pow8(pos1.y), 0.125);
	return mix(1.0, dist, SHADOW_DISTORTION);
}

vec3 biasedShadows(vec3 worldposition){

	float distortFactor = getDistordFactor(worldposition);

	worldposition.xy /= distortFactor;
	worldposition = worldposition * vec3(0.5,0.5,0.2) + vec3(0.5,0.5,0.5);

	return worldposition;
}