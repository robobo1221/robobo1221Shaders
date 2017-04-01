	vec3 shadowsForward = getShadow(pixeldepth, normal2,5.0, false, true);
	
	#ifdef DYNAMIC_HANDLIGHT
		float handItemLightFactor2 = getHandItemLightFactor(fragpos, normal2) * handLightMult;
		float forwardEmissive = getEmissiveLightmap(aux2, false) + handItemLightFactor2;
	#else
		float forwardEmissive = getEmissiveLightmap(aux2, false);
	#endif

vec3 getShadingForward(vec3 normal, vec3 color){

	float skyLightMap = getSkyLightmap2();

	float diffuse = OrenNayar(fragpos.rgb, lightVector, normal, 0.0) * ((1.0 - rainStrength) * transition_fading);
	float lightAbsorption = smoothstep(-0.1, 0.5, dot(upVec, sunVec));

	vec3 lightCol = mix(sunlight * lightAbsorption, moonlight, time[1].y);
	vec3 emissiveLightmap = forwardEmissive * emissiveLightColor;
	
	#ifdef DYNAMIC_HANDLIGHT
		emissiveLightmap = getEmessiveGlow(color, handLightMult * emissiveLightColor, emissiveLightmap, hand * 0.25);
	#endif

	vec3 sunlightDirect = (lightCol * sunlightAmount) * 0.5;
	vec3 indirectLight = (mix(ambientlight, lightCol * lightAbsorption, mix(mix(0.5, 0.0, rainStrength),0.0,time[1].y)) * 0.05) * (skyLightMap * shadowDarkness) + (minLight * (1.0 - skyLightMap));

	return ((sunlightDirect * (shadowsForward * diffuse)) + indirectLight) + emissiveLightmap;
}