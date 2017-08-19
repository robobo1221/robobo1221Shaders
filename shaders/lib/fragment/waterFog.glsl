#ifdef WATER_DEPTH_FOG

	float getWaterDepth(vec3 fragpos, vec3 fragpos2){
		return distance(fragpos, fragpos2);
	}

	float getWaterScattering(float NdotL){
		const float wrap = 0.1;
		const float scatterWidth = 0.5;
		
		float NdotLWrap = (NdotL + wrap) / (wrap + 1.0);
		return smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);
	}

	vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2){

		vec3 lightCol = sunlight;

		float depth = getWaterDepth(fragpos, fragpos2); // Depth of the water volume
			  depth *= mix(iswater, 1.0, isEyeInWater);

		float depthFog = 1.0 - clamp(exp2(-depth * DEPTH_FOG_DENSITY), 0.0, 1.0); // Beer's Law

		float sunAngleCosine = 1.0 - clamp(dot(normalize(fragpos.rgb), lightVector), 0.0, 1.0);
			  sunAngleCosine = sunAngleCosine*sunAngleCosine*(3.0 - 2.0 * sunAngleCosine);
			  sunAngleCosine = 1.0 / sunAngleCosine - 1.0;
			  sunAngleCosine /= sunAngleCosine * 0.02 + 1.0;

		float NdotL = dot(compositeNormals, lightVector);
		float SSS = pow(getWaterScattering(NdotL), 2.0);

		vec3 fogColor = ambientlight * 0.0333;
			 if (isEyeInWater < 0.9){
				fogColor = (fogColor * (pow(aux2.b, skyLightAtten) + 0.25)) * 0.75;
				fogColor = mix(fogColor, (fogColor * lightCol) * 3.75, SSS * (1.0 - rainStrength) * shadowsForward);
				fogColor = fogColor * (1.0 + lightCol * (sunAngleCosine * shadowsForward) * transition_fading * (1.0 - rainStrength));
				}
			 const vec3 waterCoeff = vec3(0.4510, 0.0867, 0.0476) / log(2.0);
		color *= pow(vec3(0.1, 0.5, 0.8), vec3(depth) * 0.2);

		return mix(color, fogColor, depthFog);
	}
#endif