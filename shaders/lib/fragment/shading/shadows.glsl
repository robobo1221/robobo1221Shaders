#ifdef SHADOW_FILTER
const vec2 shadowOffset[8] = vec2[8] (
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(0.0, -1.0),
		vec2(0.5, 0.0),
		vec2(0.0, 0.5),
		vec2(-0.5, 0.0),
		vec2(0.0, -0.5));
#endif

float shadowStep(sampler2D shadow, vec3 sPos) {
	return clamp(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).x, 0.0) * float(shadowMapResolution), 0.0, 1.0);
}

vec3 getShadow(float shadowDepth, vec3 normal, float stepSize, bool advDisFactor, bool isClamped){

	vec3 shadowPosition = toShadowSpace(toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, shadowDepth)));
		 shadowPosition = biasedShadows(shadowPosition);

	float NdotL = clamp(dot(normal, lightVector),0.0,1.0);
		  NdotL = mix(NdotL, 1.0, translucent);

	float step = 1.0 / shadowMapResolution;

	float distortFactor = getDistordFactor(shadowPosition);

	float diffthresh = distortFactor*distortFactor*distortFactor*distortFactor * 0.0002 * sqrt(1.0 - NdotL*NdotL)/NdotL + clamp(pow(dot(fragpos,fragpos),.125),0.0,1.0) * 0.000244140625;
		  diffthresh = mix(advDisFactor ? diffthresh : 0.0003 , 0.0003, translucent);

	vec3 shading = vec3(0.0);
	vec3 shading2 = vec3(0.0);
	vec3 colorShading = vec3(0.0);

	float rotationMult = dither * pi;
	mat2 rotationMat = mat2(cos(rotationMult), -sin(rotationMult),
					   sin(rotationMult), cos(rotationMult));

	if (max(abs(shadowPosition.x),abs(shadowPosition.y)) < 0.99) {

	#ifdef SHADOW_FILTER
	for (int i = 0; i < 8; i++) {

		shading += shadowStep(shadowtex1, vec3(shadowPosition.xy + rotationMat * shadowOffset[i] * step * stepSize, shadowPosition.z - diffthresh));

		#ifdef COLOURED_SHADOWS
			shading2 += shadowStep(shadowtex0, vec3(shadowPosition.xy + rotationMat * shadowOffset[i] * step * stepSize, shadowPosition.z - diffthresh));
			colorShading += texture2D(shadowcolor0, shadowPosition.xy + rotationMat * shadowOffset[i] * step * stepSize).rgb * 10.0;
		#endif
	}

	#else

		shading += shadowStep(shadowtex1, vec3(shadowPosition.xy, shadowPosition.z - diffthresh));

		#ifdef COLOURED_SHADOWS
			shading2 += shadowStep(shadowtex0, vec3(shadowPosition.xy, shadowPosition.z - diffthresh));
			colorShading += texture2D(shadowcolor0, shadowPosition.xy).rgb * 10.0;
		#endif

	#endif

	#ifdef SHADOW_FILTER
		shading *= 0.125;
	#endif

	#ifdef COLOURED_SHADOWS

		#ifdef SHADOW_FILTER
			shading2 *= 0.125;
			colorShading *= 0.125;
		#endif

		colorShading = getDesaturation(colorShading, min(emissiveLM, 1.0));

		shading = mix(shading2, colorShading, max(shading - shading2, 0.0));
	#endif

	}

	return isClamped ? vec3(clamp(shading,0.0, 1.0)) : shading;
}
