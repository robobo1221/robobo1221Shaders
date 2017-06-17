#ifdef WATER_DEPTH_FOG

	float getWaterDepth(vec3 fragpos, vec3 fragpos2){
		return distance(fragpos, fragpos2);
	}

	float getWaterScattering(float NdotL){
		const float wrap = 0.1;
		const float scatterWidth = 0.5;
		
		float NdotLWrap = (NdotL + wrap) / (1.0 + wrap);
		return smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);
	}

	vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2){

		vec3 lightCol = mix(sunlight, pow(moonlight, vec3(0.4545)), time[1].y);

		float depth = getWaterDepth(fragpos, fragpos2); // Depth of the water volume
		depth *= mix(iswater, 1.0, isEyeInWater);

		float depthFog = 1.0 - clamp(exp2(-depth * DEPTH_FOG_DENSITY), 0.0, 1.0); // Beer's Law

		float sunAngleCosine = pow(clamp(dot(normalize(fragpos.rgb), lightVector), 0.0, 1.0), 8.0);
		float NdotL = dot(compositeNormals, lightVector);
		float SSS = pow(getWaterScattering(NdotL), 2.0);

		vec3 fogColor = (ambientlight * lightCol) * 0.0333;
			 if (isEyeInWater < 0.9){
				fogColor = (fogColor * (pow(aux2.b, skyLightAtten) + 0.25)) * 0.75;
				fogColor = mix(fogColor, (fogColor * lightCol) * 3.75, SSS * (1.0 - rainStrength) * shadowsForward);
				fogColor = mix(fogColor, (fogColor * lightCol) * 6.0,(sunAngleCosine * shadowsForward) * (transition_fading * (1.0 - pow(max(NdotL,0.0), 2.0))) * (1.0 - rainStrength));
				}
			 
		color *= pow(vec3(0.1, 0.5, 0.8), vec3(depth) * 0.25);

		return mix(color, fogColor, depthFog);
	}
#endif