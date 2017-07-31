	vec3 shadowsForward = getShadow(pixeldepth, compositeNormals,5.0, false, true);
	
	#ifdef DYNAMIC_HANDLIGHT
		float handItemLightFactor2 = getHandItemLightFactor(fragpos, compositeNormals) * handLightMult;
		float forwardEmissive = getEmissiveLightmap(aux2, false) + handItemLightFactor2;
	#else
		float forwardEmissive = getEmissiveLightmap(aux2, false);
	#endif

vec3 getShadingForward(vec3 normal, vec3 color){

	float skyLightMap = getSkyLightmap(aux2.z);

	float diffuse = OrenNayar(fragpos.rgb, lightVector, normal, 0.0) * ((1.0 - rainStrength) * transition_fading);
	float lightAbsorption = smoothstep(-0.1, 0.5, dot(upVec, sunVec));

	vec3 lightCol = mix(sunlight * lightAbsorption, moonlight, time[1].y) * sunlightAmount;
	vec3 emissiveLightmap = forwardEmissive * emissiveLightColor;
	
	#ifdef DYNAMIC_HANDLIGHT
		emissiveLightmap = getEmessiveGlow(color, handLightMult * emissiveLightColor, emissiveLightmap, hand);
	#endif

	vec3 sunlightDirect = lightCol * (shadowsForward * diffuse) * max(dynamicCloudCoverage * 2.4 - 1.4, 0.0);
	vec3 indirectLight = mix(ambientlight, lightCol * lightAbsorption, mix(mix(mix(0.175, 0.0, rainStrength),0.0,time[1].y), 0.0, 1.0 - skyLightMap)) * (0.14 * skyLightMap * shadowDarkness) + (minLight * (1.0 - skyLightMap));

	return (sunlightDirect + indirectLight) + emissiveLightmap;
}