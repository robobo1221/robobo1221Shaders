float findBlocker(vec3 rawPosition, float shadowBias, float dither, float maxSpread, float angle, const int steps, const float rSteps){
	float blockerDepth = 0.0;
	
	for (int i = 0; i < steps; ++i) {
		vec3 offset = circlemapL((dither + float(i)) * rSteps, 4096.0 * float(steps));
			 offset.z *= maxSpread;

		vec3 shadowPosition = vec3(offset.xy, -shadowBias) * offset.z + rawPosition;
			 shadowPosition = remapShadowMap(shadowPosition);

		float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;

		blockerDepth = max(blockerDepth, (shadowPosition.z - shadowBias) - shadowDepth0);
	}

	return min(blockerDepth * angle, maxSpread);
}

vec3 calculateShadows(vec3 rawPosition, mat2x3 position, vec3 normal, vec3 shadowSpaceNormal, vec3 lightVector, float dither, bool isVegitation, bool isLava) {
	float NdotL = dot(normal, lightVector);
		  NdotL = fCondition(isVegitation, 0.5, NdotL);
	vec3 earlyOutPosition = remapShadowMap(rawPosition);
	
	if (any(greaterThanEqual(earlyOutPosition, vec3(1.0))) ||
		any(lessThanEqual(earlyOutPosition, vec3(0.0))) ||
		NdotL <= 0.0) return vec3(1.0);
	
	const int steps = SHADOW_QUALITY;
	const float rSteps = 1.0 / steps;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL) * rShadowMapResolution;
		  shadowBias = shadowBias * calculateDistFactor(rawPosition.xy) * 0.15;

	vec3 shadows = vec3(0.0);

	const float sunCosAngle = radians(sunAngularSize);

	const float angle = sunCosAngle * 4.0;
	const float maxSpread = 10.0 * rShadowMapResolution;

	#ifdef SHADOW_PENUMBRA
		float shadowBlur = findBlocker(rawPosition, shadowBias, dither, maxSpread, angle, steps, rSteps);
	#else
		float shadowBlur = rShadowMapResolution * 0.5;
	#endif

	float shadowSurfaceDepth = transMAD(shadowModelView, position[1]).z;
	
	for (int i = 0; i < steps; ++i) {
		vec3 offset = circlemapL((dither + float(i)) * rSteps, 4096.0 * float(steps));
			 offset.z *= shadowBlur;

		vec3 shadowPosition = vec3(offset.xy, -shadowBias) * offset.z + rawPosition;
			 shadowPosition = remapShadowMap(shadowPosition);

		float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;
		float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;

		vec4 colorShadow1 = texture2D(shadowcolor1, shadowPosition.xy);
		vec3 shadowNormal = colorShadow1.rgb * 2.0 - 1.0;

		float waterMask = colorShadow1.a * 2.0 - 1.0;

		shadowBias = fCondition((shadowDepth0 == shadowDepth1 && !(isVegitation || isLava)), fCondition(dot(shadowNormal, shadowSpaceNormal) > 0.1, shadowBias, 0.0), shadowBias);

		float shadow0 = calculateHardShadows(shadowDepth0, shadowPosition, shadowBias);
		float shadow1 = calculateHardShadows(shadowDepth1, shadowPosition, shadowBias);

		float surfaceDepth0 = (shadowDepth0 * 8.0 - 4.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		float waterDepth = max0(surfaceDepth0 - shadowSurfaceDepth);
			  waterDepth = mix(0.0, waterDepth, waterMask);

		vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);

		#ifdef COLOURED_SHADOWS
			vec3 colorShadow = texture2D(shadowcolor0, shadowPosition.xy).rgb;
			vec3 colouredShadows = mix(vec3(shadow0), colorShadow, clamp01(shadow1 - shadow0)) * waterTransmittance;

			shadows += colouredShadows;
		#else
			shadows += shadow1 * waterTransmittance;
		#endif
	}

    return shadows * rSteps;
}

float calculateTorchLightAttenuation(float lightmap){
	lightmap *= 1.135;
	lightmap = clamp01(lightmap);

	float dist = (1.0 - lightmap) * 16.0 + 1.0;
	return lightmap * pow(dist, -2.0);
}

#if defined program_deferred
	vec3 calculateGlobalIllumination(vec3 shadowPosition, vec3 shadowSpaceNormal, float dither, float skyLightMap, bool isVegitation, float sunlum, float moonlum){
		const int steps = GI_STEPS;
		const float rSteps = 1.0 / steps;

		const float offsetSize = GI_RADIUS;
		const float rOffsetSize = 1.0 / offsetSize;

		const float pixelOffset = offsetSize * (1.0 / 2048.0);

		vec3 total = vec3(0.0);
		float totalWeight = 0.0;

		shadowSpaceNormal *= vec3(1.0, 1.0, -1.0);

		for (int i = 0; i < steps; ++i){
			vec2 coordOffset = circlemap((float(i) + dither) * rSteps, 4096.0 * float(steps)) * pixelOffset;
			float weight = 1.0;

			vec2 offsetCoord = shadowPosition.xy + coordOffset;
			vec2 remappedCoord = remapShadowMap(offsetCoord) * 0.5 + 0.5;

			float shadow = texture2D(shadowtex1, remappedCoord).x - 0.00005;

			vec3 samplePostion = vec3(offsetCoord.xy, shadow * 8.0 - 4.0) - shadowPosition;
			float normFactor = dot(samplePostion, samplePostion);
			vec3 sampleVector = samplePostion * inversesqrt(normFactor);
			float SoN = clamp01(dot(sampleVector, shadowSpaceNormal));
				  SoN = fCondition(isVegitation, 1.0, SoN);

			if (SoN <= 0.0) continue;

			vec3 normal = (texture2D(shadowcolor1, remappedCoord).rgb * 2.0 - 1.0);
					normal.xy = -normal.xy;

			float LoN = clamp01(dot(sampleVector, normal));
			float falloff = 1.0 / (normFactor * rOffsetSize * 16384.0 + rOffsetSize * 16.0);

			SoN = sqrt(SoN);

			if (LoN <= 0.0) continue;

			/*
			float waterMask = texture2DLod(shadowcolor1, remappedCoord, 3).a * 2.0 - 1.0;

			float surfaceDepth0 = (texture2DLod(shadowtex0, remappedCoord, 3).x * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
			float surfaceDepth1 = (shadow * 2.0 - 1.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
			float waterDepth = (surfaceDepth0 - surfaceDepth1) * 4.0;
			waterDepth = mix(0.0, waterDepth, waterMask);

			vec3 waterTransmittance = exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);
			*/

			vec4 albedo = texture2D(shadowcolor0, remappedCoord);
					albedo.rgb = srgbToLinear(albedo.rgb);
					albedo.rgb = albedo.rgb /** waterTransmittance*/;

			float skyLightMapShadow = albedo.a * 2.0 - 1.0;
			float bleedingMask = skyLightMapShadow - skyLightMap;
					bleedingMask = pow6(bleedingMask);
					bleedingMask = clamp01(0.005 / (max(bleedingMask, 0.005)));

			//LoN = sqrt(LoN);

			total += albedo.rgb * LoN * SoN * falloff * bleedingMask;
		}

		total = total * rSteps * rPI;

		return mix(total, vec3(dot(total, lumCoeff)), clamp01(moonlum * 2.0 - sunlum));;
	}
#endif

vec3 calculateSkyLighting(float lightmap, vec3 normal){
	#if defined program_deferred
		vec3 skyCol = FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal) * PI;
	#else
		vec3 skyCol = skyColor;
	#endif

	//fake bounced sunlight
	skyCol += (sunColor + moonColor) * transitionFading * pow2(rPI) * 0.06;

	return skyCol * lightmap * anisotropicMultibounceConst;
}

float calculateRoboboAO(vec2 coord, mat2x3 position, vec3 normal, float dither){

	const int steps = AO_QUALITY;
	const float rSteps = 1.0 / steps;

	const float radius = 0.5;

	float PdotN = dot(position[0], normal);
	float pLength = inversesqrt(dot(position[0], position[0]));
		  pLength = min(0.4, pLength) * radius * length(gbufferProjection[1][1]);

	vec3 offsetMul = vec3(vec2(1.0, aspectRatio) * pLength, 1.0);
	
	float d = 0.0;

	for (int i = 0; i < steps; ++i){
		vec3 offset = circlemapL((dither + float(i)) * rSteps, 4096.0 * float(steps));
		offset *= offsetMul * offset.z * offset.z;

		vec3 offsetCoord = vec3(texcoord + offset.xy, texture2D(depthtex1, texcoord + offset.xy).x);
		vec3 offsetViewCoord = calculateViewSpacePosition(offsetCoord.xy, offsetCoord.z);

		float OdotN = dot(offsetViewCoord, normal);
		float tangent = PdotN / OdotN;
              tangent = fCondition(OdotN >= 0.0, 16.0, tangent);

		float depthAware = smoothstep(0.0, 1.0, radius / abs(offsetViewCoord.z - position[0].z));

        float correction = mix(tangent, min(1.0, tangent), depthAware);
              correction = fCondition(clamp01(coord) != coord, 1.0, correction);

		float nDotL = dot(normal, normalize(offsetViewCoord * correction - position[0]));
		d += nDotL;
	}

	float ao = 1.0 - clamp01(d * rSteps);

	return pow2(ao);
}

vec3 calculateDirectLighting(vec3 albedo, mat2x3 position, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec3 wLightVector, vec2 lightmaps, float roughness, float dither, float pomShadow, bool isVegitation, bool isLava) {
	vec3 shadowPosition = transMAD(shadowMatrix, position[1]);

	vec3 shadowSpaceNormal = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * normal;
	vec3 flatNormal = clamp(normalize(cross(dFdx(position[1]), dFdy(position[1]))), -1.0, 1.0);
	vec3 shadowSpaceFlatNormal = mat3(shadowModelView) * flatNormal;

	float cloudShadows = 1.0;
	vec3 shadows = calculateShadows(shadowPosition, position, normal, shadowSpaceFlatNormal, shadowLightVector, dither, isVegitation, isLava) * pomShadow;
		 //shadows *= calculateVolumeLightTransmittance(position[1], wLightVector, max3(shadows), 8);

		#ifdef VOLUMETRIC_CLOUDS
		 	cloudShadows = calculateCloudShadows(position[1] + cameraPosition, wLightVector, 5);
			shadows *= cloudShadows;
		#endif

	float ao = 1.0;

	#if defined program_deferred
		vec3 diffuse = vec3(1.0);

		if (isVegitation) {
			diffuse = vec3(rPI);
		} else {
			diffuse = GeometrySmithGGX(albedo, normal, viewVector, shadowLightVector, roughness);
		}
		
		#ifdef AMBIENT_OCCLUSION
			ao = calculateRoboboAO(texcoord, position, normal, dither);
		#endif
	#else
		float diffuse = clamp01(dot(normal, shadowLightVector)) * rPI;	//Lambert for stained glass
	#endif
	
	vec3 directionalLighting = shadows * diffuse * transitionFading;
	vec3 lighting = vec3(0.0);

	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor * ao;
	lighting += 0.03 * (-lightmaps.y + 1.0);
	lighting += directionalLighting * sunColor;

	//albedo = lightmaps.x > 0.99 ? vec3(1.0) : albedo;

	lighting *= albedo;

	float moonlum = dot(moonColor, lumCoeff);
	float sunlum = dot(sunColor, lumCoeff);
	float albedolum = dot(albedo, lumCoeff);
	vec3 unsaturatedAlbedo = mix(albedo, vec3(albedolum), clamp01(moonlum * 2.0 - sunlum));
	
	#if defined program_deferred
		#ifdef GI
			#ifdef TAA
				dither = fract(frameTimeCounter * (1.0 / 16.0) + dither);
			#endif
			lighting += calculateGlobalIllumination(shadowPosition, shadowSpaceNormal, dither, lightmaps.y, isVegitation, sunlum, moonlum) * (sunColor + moonColor) * transitionFading * cloudShadows * unsaturatedAlbedo;
		#endif
	#endif

	lighting += calculateSkyLighting(lightmaps.y, normal) * unsaturatedAlbedo * ao;
	lighting += directionalLighting * moonColor * albedolum; //Fake Purkinje effect

	return lighting;
}
