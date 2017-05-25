#ifdef WATER_CAUSTICS
	#ifdef PROJECTED_CAUSTICS

	vec3 waterCaustics(){
		vec2 posxz = worldpos.xz - worldpos.y;

		float caustics = dot(getWaveHeight(posxz, 1.0).xyz * 2.0 - 1.0, vec3(1.88888));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 20.0;
			  caustics *= CAUSTIC_MULT;
			  caustics = (caustics * 0.25) + 0.75;

		return vec3(caustics);
	}

	#else

	vec3 waterCaustics(vec3 color, vec3 fpos){
		vec3 wpos = getWorldSpace(vec4(fpos, 0.0)).rgb + cameraPosition;
		vec2 posxz = wpos.xz - wpos.y;

		float caustics = dot(getWaveHeight(posxz, 1.0).xyz * 2.0 - 1.0, vec3(1.88888));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 20.0;
			  caustics *= (0.5 * CAUSTIC_MULT) * (mix(iswater * land2, 1.0 - (iswater + istransparent), isEyeInWater) * (1.0 - time[1].y * 0.5));
			  caustics = mix(caustics, 1.0, 0.75 + 0.25 * (1.0 - mix(iswater, land, isEyeInWater)));

		return color * caustics;
	}
	#endif
#endif