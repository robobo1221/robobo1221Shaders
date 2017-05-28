#ifdef SHADOW_FILTER
vec2 shadowOffset[8] = vec2[8] (
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(0.0, -1.0),
		vec2(0.5, 0.0),
		vec2(0.0, 0.5),
		vec2(-0.5, 0.0),
		vec2(0.0, -0.5));
#endif

vec3 getShadow(float shadowDepth, vec3 normal, float stepSize, bool advDisFactor, bool isClamped){

	vec3 shadowPosition = toShadowSpace(toScreenSpace(vec3(texcoord.st, shadowDepth)));
		 shadowPosition = biasedShadows(shadowPosition);

	float NdotL = clamp(dot(normal, lightVector),0.0,1.0);
		  NdotL = mix(NdotL, 1.0, translucent);

	float step = 1.0 / shadowMapResolution;

	float distortFactor = getDistordFactor(shadowPosition);

	float diffthresh = pow(distortFactor, 4.0)/ 4096.0 * sqrt(1.0 - NdotL*NdotL)/NdotL + clamp(pow(dot(fragpos,fragpos),.125),0.0,1.0) / 4096;
		  diffthresh = mix(advDisFactor ? diffthresh : 0.0003 , 0.0003, translucent);

	vec3 shading = vec3(0.0);
	vec3 shading2 = vec3(0.0);
	vec3 colorShading = vec3(0.0);

	float noise = fract(sin(dot(texcoord.xy, vec2(18.9898f, 28.633f))) * 4378.5453f) * 4.0;
		mat2 noiseM = mat2(cos(noise), -sin(noise),
						   sin(noise), cos(noise));

	if (max(abs(shadowPosition.x),abs(shadowPosition.y)) < 0.99) {

	#ifdef SHADOW_FILTER
	for (int i = 0; i < 8; i++) {

		shading += shadowStep(shadowtex1, vec3(shadowPosition.xy + noiseM * shadowOffset[i] * step * stepSize, shadowPosition.z - diffthresh));

		#ifdef COLOURED_SHADOWS
			shading2 += shadowStep(shadowtex0, vec3(shadowPosition.xy + noiseM * shadowOffset[i] * step * stepSize, shadowPosition.z - diffthresh));
			colorShading += texture2D(shadowcolor0, shadowPosition.xy + noiseM * shadowOffset[i] * step * stepSize).rgb * 10.0;
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
		shading /= 8.0;
	#endif

	#ifdef COLOURED_SHADOWS

		#ifdef SHADOW_FILTER
			shading2 /= 8.0;
			colorShading /= 8.0;
		#endif

		colorShading = getDesaturation(colorShading, min(emissiveLM, 1.0));

		shading = mix(shading2, colorShading, max(shading - shading2, 0.0));
	#endif

	}

	return isClamped ? vec3(clamp(shading,0.0, 1.0)) : shading;
}
