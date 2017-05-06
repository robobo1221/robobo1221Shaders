#ifdef WATER_CAUSTICS
	#ifdef PROJECTED_CAUSTICS

	vec3 waterCaustics(){
		vec2 posxz = worldpos.xz - worldpos.y;

		float caustics = dot(getWaveHeight(posxz, 1.0).xyz * 2.0 - 1.0, vec3(1.88888));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 15.0;

		return vec3(1.0 + (caustics * CAUSTIC_MULT));
	}

	#else

	vec3 waterCaustics(vec3 color, vec4 fpos){
		vec3 wpos = getWorldSpace(fpos).rgb + cameraPosition;
		vec2 posxz = wpos.xz - wpos.y;

		float caustics = dot(getWaveHeight(posxz, 1.0).xyz * 2.0 - 1.0, nvec3(gbufferModelViewInverse * nvec4(sunVec)));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 15.0;

		return color + (color * caustics) * (0.5 * CAUSTIC_MULT) * (mix(iswater * land2, 1.0 - (iswater + istransparent), isEyeInWater) * (1.0 - time[1].y * 0.5));
	}
	#endif
#endif