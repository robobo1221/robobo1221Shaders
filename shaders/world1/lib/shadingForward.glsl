	#ifdef DYNAMIC_HANDLIGHT
		float handItemLightFactor2 = getHandItemLightFactor(fragpos, normal2) * handLightMult;
		float forwardEmissive = getEmissiveLightmap(aux2, false) + handItemLightFactor2;
	#else
		float forwardEmissive = getEmissiveLightmap(aux2, false);
	#endif

vec3 getShadingForward(vec3 normal, vec3 color){

	vec3 emissiveLightmap = forwardEmissive * emissiveLightColor;
	
	#ifdef DYNAMIC_HANDLIGHT
		emissiveLightmap = getEmessiveGlow(color, handLightMult * emissiveLightColor, emissiveLightmap, hand);
	#endif

	return MIN_LIGHT * ambientlight + emissiveLightmap;
}