#define SHADOW_DISTORTION 0.85

float calculateDistFactor(vec2 shadowPosition){
	shadowPosition = shadowPosition * 2.0 - 1.0;
	return length(shadowPosition) * (length(shadowPosition * 1.169) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION)) + 1.0;
}

vec2 distortShadowMap(vec2 shadowPosition){
	return shadowPosition / (length(shadowPosition * 1.169) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION));
}

vec3 distortShadowMap(vec3 shadowPosition){
	return vec3(distortShadowMap(shadowPosition.xy), shadowPosition.z * 0.25);
}

vec2 remapShadowMap(vec2 shadowPosition){
	return shadowPosition / (length(shadowPosition * 1.169) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION));
}

vec3 remapShadowMap(vec3 shadowPosition){
	return vec3(remapShadowMap(shadowPosition.xy), shadowPosition.z * 0.25) * 0.5 + 0.5;
}
