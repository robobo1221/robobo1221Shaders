vec3 calculateShadows(vec3 shadowPosition, vec3 normal, vec3 lightVector, bool isVegitation) {
	shadowPosition = remapShadowMap(shadowPosition);

	float NdotL = dot(normal, lightVector);
		  NdotL = isVegitation ? 0.5 : NdotL;

	float pixelSize = rShadowMapResolution;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL);
		  shadowBias = shadowBias * calculateDistFactor(shadowPosition.xy) * pixelSize * 0.2;
	
	float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;
	float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;
	float shadow1 = calculateHardShadows(shadowDepth1, shadowPosition, shadowBias);

	vec4 colorShadow1 = texture2D(shadowcolor1, shadowPosition.xy);
	float waterMask = colorShadow1.a * 2.0 - 1.0;

	float surfaceDepth0 = (shadowDepth0 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
	float surfaceDepth1 = (shadowDepth1 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
	float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;
	waterDepth = mix(0.0, waterDepth, waterMask);

	vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);

	#ifndef COLOURED_SHADOWS
		return shadow1 * waterTransmittance;
	#endif

	float shadow0 = calculateHardShadows(shadowDepth0, shadowPosition, shadowBias);
	vec3 colorShadow = texture2D(shadowcolor0, shadowPosition.xy).rgb;

	vec3 colouredShadows = mix(vec3(shadow0), colorShadow, clamp01(shadow1 - shadow0));

    return colouredShadows * waterTransmittance;
}

float calculateTorchLightAttenuation(float lightmap){
	float dist = clamp((1.0 - lightmap) * 15.0, 1.0, 15.0);
	return (1.0 - clamp01((1.0 - lightmap) * 2.0 - 1.0)) / (dist * dist * TAU);
}

	vec3 calculateGlobalIllumination(vec3 shadowPosition, vec3 viewSpaceNormal, float dither, const bool isVolumetric){
		const int iSteps = 3;
		const int jSteps = 6;
		const float rISteps = 1.0 / iSteps;
		const float rJSteps = 1.0 / jSteps;

		float rotateAmountI = (rISteps + rISteps * dither) * TAU;
		float rotateAmountJ = PI * 0.5;

		vec2 pixelOffset = vec2(50.0) * rShadowMapResolution;
		float pixelLength = inversesqrt(dot(pixelOffset, pixelOffset)) * 16.0;

		vec3 total = vec3(0.0);
		float totalWeight = 0.0;

		vec3 shadowSpaceNormal = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * viewSpaceNormal * vec3(1.0, 1.0, -1.0);

		for (int i = 0; i < iSteps; ++i){
			vec2 rotatedCoordOffset = rotate(pixelOffset, rotateAmountI * (float(i) + 1.0)) * rJSteps;
			for (int j = 0; j < jSteps; ++j){
				vec2 coordOffset = rotate(rotatedCoordOffset * (float(j) + 1.0), rotateAmountJ * float(j));
				float weight = 1.0;

				totalWeight += weight;

				vec2 offsetCoord = shadowPosition.xy + coordOffset;
				vec2 remappedCoord = remapShadowMap(offsetCoord) * 0.5 + 0.5;

				float shadow = texture2D(shadowtex1, remappedCoord).x;

				vec3 samplePostion = vec3(offsetCoord.xy, shadow * 8.0 - 4.0) - shadowPosition;
				float normFactor = dot(samplePostion, samplePostion);
				vec3 sampleVector = samplePostion * inversesqrt(normFactor);
				float SoN = isVolumetric ? 1.0 : clamp01(dot(sampleVector, shadowSpaceNormal));

				if (SoN <= 0.0) continue;

				vec3 normal = mat3(shadowModelView) * (texture2D(shadowcolor1, remappedCoord).rgb * 2.0 - 1.0);
				normal.xy = -normal.xy;

				float LoN = clamp01(dot(sampleVector, normal));
				if (LoN <= 0.0) continue;

				float falloff = 1.0 / max(pixelLength * normFactor, 1.0);

				float waterMask = texture2D(shadowcolor1, remappedCoord).a * 2.0 - 1.0;

				/*
				float surfaceDepth0 = (texture2D(shadowtex0, remappedCoord).x * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
				float surfaceDepth1 = (shadow * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
				float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;
				waterDepth = mix(0.0, waterDepth, waterMask);

				vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);
				*/

				vec4 albedo = texture2D(shadowcolor0, remappedCoord);
					 albedo.rgb = albedo.rgb * albedo.a /** waterTransmittance*/;

				total += albedo.rgb * LoN * SoN * falloff * weight;
			}
		}

		return total / totalWeight;
	}

vec3 calculateSkyLighting(float lightmap, vec3 normal){
	#if defined program_deferred
		vec3 skyCol = FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal) * PI;
	#else
		vec3 skyCol = skyColor;
	#endif

	return skyCol * lightmap;
}

vec3 calculateDirectLighting(vec3 albedo, vec3 worldPosition, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec3 wLightVector, vec2 lightmaps, float roughness, float dither, bool isVegitation) {
	vec3 shadowPosition = transMAD(shadowMatrix, worldPosition);
	
	vec3 shadows = calculateShadows(shadowPosition, normal, shadowLightVector, isVegitation);
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

	lighting += shadows * diffuse * (sunColor + moonColor) * transitionFading + 0.02 * (-lightmaps.y + 1.0);
	lighting += calculateSkyLighting(lightmaps.y, normal);
	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor;

	#if defined program_deferred
		#ifdef GI
			lighting += calculateGlobalIllumination(shadowPosition, normal, dither, false) * (sunColor + moonColor) * transitionFading;
		#endif
	#endif

	return lighting * albedo;
}
