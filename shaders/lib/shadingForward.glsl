	vec3 shadows = getShadow(pixeldepth, normal2,5.0, false, true);
	
	#ifdef DYNAMIC_HANDLIGHT
		float handItemLightFactor2 = getHandItemLightFactor(fragpos, normal2) * handLightMult;
		float forwardEmissive = getEmissiveLightmap(aux2) + handItemLightFactor2;
	#else
		float forwardEmissive = getEmissiveLightmap(aux2);
	#endif

vec3 getShadingForward(vec3 normal, vec3 color){

	float skyLightMap = getSkyLightmap2();

	float diffuse = mix(clamp(dot(normal, lightVector), 0.0, 1.0),0.0, isEyeInWater) * (1.0 - rainStrength) * transition_fading;

	vec3 lightCol = mix(sunlight, moonlight, time[1].y);
	
	vec3 emissiveLightmap = forwardEmissive * emissiveLightColor;
	
	#ifdef DYNAMIC_HANDLIGHT
		emissiveLightmap = getEmessiveGlow(color, handItemLightFactor2 * emissiveLightColor, emissiveLightmap, hand * 15.0);
	#endif

	vec3 sunlightDirect = lightCol * sunlightAmount;
	vec3 indirectLight = mix(ambientlight, lightCol, mix(mix(0.7, 0.0, rainStrength),0.0,time[1].y)) * 0.2 * skyLightMap * shadowDarkness + minLight * (1.0 - skyLightMap);

	return mix(indirectLight, sunlightDirect, shadows * diffuse) + emissiveLightmap;
}