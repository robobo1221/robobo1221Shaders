vec3 calculateShadows(vec3 worldPosition, vec3 normal, vec3 lightVector, bool isVegitation) {
    vec3 shadowPosition = transMAD(shadowMatrix, worldPosition);
	     shadowPosition = remapShadowMap(shadowPosition);

	float NdotL = dot(normal, lightVector);
		  NdotL = isVegitation ? 0.5 : NdotL;

	float pixelSize = rShadowMapResolution;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL);
		  shadowBias = shadowBias * calculateDistFactor(shadowPosition.xy) * pixelSize * 0.2;
	
	float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;
	float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;
	float shadow1 = calculateHardShadows(shadowDepth1, shadowPosition, shadowBias);

	vec4 colorShadow1 = texture2D(shadowcolor0, shadowPosition.xy);
	float waterMask = colorShadow1.a * 2.0 - 1.0;

	float surfaceDepth0 = (shadowDepth0 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
	float surfaceDepth1 = (shadowDepth1 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
	float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;

	vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);

	#ifndef COLOURED_SHADOWS
		return shadow1 * waterTransmittance;
	#endif

	float shadow0 = calculateHardShadows(shadowDepth0, shadowPosition, shadowBias);
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
		vec3 skyCol = FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal) * PI;
	#else
		vec3 skyCol = skyColor;
	#endif

	return skyCol * lightmap;
}

vec3 calculateDirectLighting(vec3 albedo, vec3 worldPosition, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec3 wLightVector, vec2 lightmaps, float roughness, bool isVegitation) {
	vec3 shadows = calculateShadows(worldPosition, normal, shadowLightVector, isVegitation);
		 shadows *= calculateVolumeLightTransmittance(worldPosition, wLightVector, max3(shadows), 8);

		#ifdef VOLUMETRIC_CLOUDS
		 	shadows *= calculateCloudShadows(worldPosition + cameraPosition, wLightVector, 5);
		#endif

	#if defined program_deferred
		vec3 diffuse = GeometrySmithGGX(albedo, normal, viewVector, shadowLightVector, roughness);
			 diffuse = isVegitation ? vec3(rPI) : diffuse;
	#else
		float diffuse = clamp01(dot(normal, shadowLightVector)) * rPI;	//Lambert for stained glass
	#endif

	vec3 lighting = vec3(0.0);

	lighting += shadows * diffuse * (sunColor + moonColor) * transitionFading;
	lighting += calculateSkyLighting(lightmaps.y, normal);
	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor;

	return lighting * albedo;
}
