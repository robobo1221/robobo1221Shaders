vec3 calculateShadows(vec3 worldPosition, vec3 normal, vec3 lightVector) {
    vec3 shadowPosition = transMAD(shadowMatrix, worldPosition);
	     shadowPosition = remapShadowMap(shadowPosition);

	float NdotL = dot(normal, lightVector);

	float pixelSize = rShadowMapResolution;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL);
		  shadowBias = shadowBias * calculateDistFactor(shadowPosition.xy) * pixelSize * 0.2;

	float shadow1 = calculateHardShadows(shadowtex1, shadowPosition, shadowBias);

	#ifndef COLOURED_SHADOWS
		return vec3(shadow1);
	#endif

	float shadow0 = calculateHardShadows(shadowtex0, shadowPosition, shadowBias);
	vec3 colorShadow = texture2D(shadowcolor0, shadowPosition.xy).rgb;

	vec3 colouredShadows = mix(vec3(shadow0), colorShadow, clamp01(shadow1 - shadow0));

    return colouredShadows;
}

float calculateTorchLightAttenuation(float lightmap){
	float dist = clamp((1.0 - lightmap) * 15.0, 1.0, 15.0);
	return (1.0 - clamp01((1.0 - lightmap) * 2.0 - 1.0)) / (dist * dist);
}

vec3 calculateSkyLighting(float lightmap, vec3 normal){
	#if defined program_deferred
		vec3 skyCol = FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal);
	#else
		vec3 skyCol = skyColor;
	#endif

	return skyCol * PI * lightmap;
}

vec3 calculateDirectLighting(vec3 albedo, vec3 worldPosition, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec3 wLightVector, vec2 lightmaps, float roughness) {
	vec3 shadows = calculateShadows(worldPosition, normal, shadowLightVector);
		 shadows *= calculateVolumeLightTransmittance(worldPosition, wLightVector, max3(shadows), 8);

	#if defined program_deferred
		vec3 diffuse = GeometrySmithGGX(albedo, normal, viewVector, shadowLightVector, roughness);
	#else
		float diffuse = clamp01(dot(normal, shadowLightVector));	//Lambert for stained glass
	#endif

	vec3 lighting = vec3(0.0);

	lighting += shadows * diffuse * (sunColor + moonColor) * transitionFading;
	lighting += calculateSkyLighting(lightmaps.y, normal);
	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor;

	return lighting * albedo;
}
