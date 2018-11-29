vec3 calculateShadows(vec3 rawPosition, vec3 normal, vec3 lightVector, float dither, bool isVegitation) {
	const int steps = 4;
	const float rSteps = 1.0 / steps;

	float NdotL = dot(normal, lightVector);
		  NdotL = isVegitation ? 0.5 : NdotL;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL) * rShadowMapResolution;
		  shadowBias = shadowBias * calculateDistFactor(rawPosition.xy) * 0.1;

	vec3 shadows = vec3(0.0);
	
	for (int i = 0; i < steps; ++i) {
		vec3 offset = circlemapL((dither + float(i)) * rSteps, 256.0 * float(steps)) * 0.015;
		vec3 shadowPosition = vec3(offset.xy, -shadowBias) * offset.z + rawPosition;
			 shadowPosition = remapShadowMap(shadowPosition);
		
		float shadowDepth0 = texture2DLod(shadowtex0, shadowPosition.xy, 0).x;
		float shadowDepth1 = texture2DLod(shadowtex1, shadowPosition.xy, 0).x;
		float shadow0 = calculateHardShadows(shadowDepth0, shadowPosition, shadowBias);
		float shadow1 = calculateHardShadows(shadowDepth1, shadowPosition, shadowBias);

		vec4 colorShadow1 = texture2DLod(shadowcolor1, shadowPosition.xy, 0);
		float waterMask = colorShadow1.a * 2.0 - 1.0;

		float surfaceDepth0 = (shadowDepth0 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		float surfaceDepth1 = (shadowDepth1 * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;
			  waterDepth = mix(0.0, waterDepth, waterMask);

		vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);

		#ifdef COLOURED_SHADOWS
			vec3 colorShadow = texture2DLod(shadowcolor0, shadowPosition.xy, 0).rgb;
			vec3 colouredShadows = mix(vec3(shadow0), colorShadow, clamp01(shadow1 - shadow0)) * waterTransmittance;

			shadows += colouredShadows;
		#else
			shadows += shadow1 * waterTransmittance;
		#endif
	}

    return shadows * rSteps;
}

float calculateTorchLightAttenuation(float lightmap){
	float dist = clamp((1.0 - lightmap) * 15.0, 1.0, 15.0);
	return lightmap / (dist * dist);
}

#if defined program_deferred
	vec3 calculateGlobalIllumination(vec3 shadowPosition, vec3 viewSpaceNormal, float dither, float skyLightMap){
		const int iSteps = 3;
		const int jSteps = 6;
		const float rISteps = 1.0 / iSteps;
		const float rJSteps = 1.0 / jSteps;

		float rotateAmountI = (dither * rISteps + rISteps) * PI;

		const float offsetSize = 50.0;
		const float rOffsetSize = 1.0 / offsetSize;

		vec2 pixelOffset = vec2(offsetSize) * rShadowMapResolution;
		float pixelLength = inversesqrt(dot(pixelOffset, pixelOffset)) * 16.0;

		vec3 total = vec3(0.0);
		float totalWeight = 0.0;

		vec3 shadowSpaceNormal = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * viewSpaceNormal * vec3(1.0, 1.0, -1.0);

		for (int i = 0; i < iSteps; ++i){
			vec2 rotatedCoordOffset = rotate(pixelOffset, rotateAmountI * (float(i) + 1.0)) * rJSteps;
			for (int j = 0; j < jSteps; ++j){
				vec2 coordOffset = rotatedCoordOffset * (float(j) + 1.0);
				float weight = 1.0;

				totalWeight += weight;

				vec2 offsetCoord = shadowPosition.xy + coordOffset;
				vec2 remappedCoord = remapShadowMap(offsetCoord) * 0.5 + 0.5;

				float shadow = texture2DLod(shadowtex1, remappedCoord, 3).x - 0.00005;

				vec3 samplePostion = vec3(offsetCoord.xy, shadow * 8.0 - 4.0) - shadowPosition;
				float normFactor = dot(samplePostion, samplePostion);
				vec3 sampleVector = samplePostion * inversesqrt(normFactor);
				float SoN = clamp01(dot(sampleVector, shadowSpaceNormal));

				if (SoN <= 0.0) continue;

				vec3 normal = mat3(shadowModelView) * (texture2DLod(shadowcolor1, remappedCoord, 3).rgb * 2.0 - 1.0);
				normal.xy = -normal.xy;

				float LoN = clamp01(dot(sampleVector, normal));
				if (LoN <= 0.0) continue;

				float falloff = 1.0 / max(normFactor * rOffsetSize * 16384.0, 1.0);
				/*
				float waterMask = texture2DLod(shadowcolor1, remappedCoord, 3).a * 2.0 - 1.0;

				float surfaceDepth0 = (texture2DLod(shadowtex0, remappedCoord, 3).x * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
				float surfaceDepth1 = (shadow * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
				float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;
				waterDepth = mix(0.0, waterDepth, waterMask);

				vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);
				*/

				vec4 albedo = texture2DLod(shadowcolor0, remappedCoord, 3);
					 albedo.rgb = albedo.rgb /** waterTransmittance*/;

				float skyLightMapShadow = albedo.a * 2.0 - 1.0;
				float bleedingMask = skyLightMapShadow - skyLightMap;
					  bleedingMask = pow6(bleedingMask);
					  bleedingMask = clamp01(0.001 / (max(bleedingMask, 0.001)));

				total += albedo.rgb * LoN * SoN * falloff * bleedingMask * weight;
			}
		}

		return total / totalWeight;
	}
#endif

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

	float cloudShadows = 1.0;
	
	vec3 shadows = calculateShadows(shadowPosition, normal, shadowLightVector, dither, isVegitation);
		 shadows *= calculateVolumeLightTransmittance(worldPosition, wLightVector, max3(shadows), 8);

		#ifdef VOLUMETRIC_CLOUDS
		 	cloudShadows = calculateCloudShadows(worldPosition + cameraPosition, wLightVector, 5);
			shadows *= cloudShadows;
		#endif

	#if defined program_deferred
		vec3 diffuse = GeometrySmithGGX(albedo, normal, viewVector, shadowLightVector, roughness);
			 diffuse = isVegitation ? vec3(rPI) : diffuse;
	#else
		float diffuse = clamp01(dot(normal, shadowLightVector)) * rPI;	//Lambert for stained glass
	#endif

	vec3 lighting = vec3(0.0);

	lighting += shadows * diffuse * (sunColor + moonColor) * transitionFading + 0.01 * (-lightmaps.y + 1.0);
	lighting += calculateSkyLighting(lightmaps.y, normal);
	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor;

	#if defined program_deferred
		#ifdef GI
			#ifdef TAA
				dither = fract(frameCounter * (1.0 / 7.0) + dither);
			#endif
			lighting += calculateGlobalIllumination(shadowPosition, normal, dither, lightmaps.y) * (sunColor + moonColor) * transitionFading * cloudShadows;
		#endif
	#endif

	return lighting * albedo;
}
