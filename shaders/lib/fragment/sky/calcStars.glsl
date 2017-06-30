#define STARS

//#define DRAW_GALAXY

#ifdef STARS
	vec3 getStars(vec3 color, vec3 fpos, float land){
		if (land < 0.9) {
			vec3 fposition = normalize(fpos);
			vec3 tPos = toWorldSpace(fposition);
			vec3 wVec = normalize(tPos);
			
			const float moonAngularDiameterCos = 0.99833194915;

			float cosViewSunAngle = dot(normalize(fposition.rgb), moonVec);
			float moondisk = smoothstep(moonAngularDiameterCos,moonAngularDiameterCos+0.001,cosViewSunAngle);

			float cosT = max(dot(fposition.rgb,upVec),0.0);

			vec3 starCoord = wVec*(50.0 / wVec.y);
			
			//Curve the fragposition so that the stars and the galaxy doesnt look weird
			starCoord *= mix(1.0, cosT, 1.0 - cosT);
			
			vec2 coord = starCoord.xz/200.0 + 0.1;

				float starNoise = texture2D(noisetex,fract(coord.xy/2.0)).x;
				starNoise += texture2D(noisetex,fract(coord.xy)).x/2.0;
				
				float star = max(starNoise - 1.3,0.0);
				
				#ifdef DRAW_GALAXY
				
					float galaxyNoise = length((starCoord.z + 50.0) * 0.01 + 0.25);
					
					float oldGalaxy = texture2D(noisetex, fract(starCoord / 5000.0).xz).x * 0.125;
						  oldGalaxy += texture2D(noisetex, fract(starCoord / 2500.0).xz).x * 0.125 * 0.5;
						  oldGalaxy += texture2D(noisetex, fract(starCoord / 1250.0).xz).x * 0.125 * 0.25;
					
					galaxyNoise += oldGalaxy;
					galaxyNoise = min(galaxyNoise, 1.0 - galaxyNoise);
					galaxyNoise = max(galaxyNoise * 8.0 - 1.5,0.0);
					galaxyNoise *= 0.45;
					galaxyNoise *= galaxyNoise * 0.8;
				
					vec3 galaxy = vec3(galaxyNoise);
						 galaxy *= mix(vec3(1.0, 1.0, 2.0), vec3(1.0, 0.75, 0.5) * 100.0, pow(oldGalaxy * 0.75 + 0.25, 3.0));
						 galaxy = mix(galaxy, vec3(1.0) * 50.0, pow(vec3(dot(galaxy * 0.14, vec3(0.33333))), vec3(7.0)));
						 galaxy += 1.0;
						 galaxy *= time[1].y;

				return mix(color, mix(vec3(1.0), galaxy, transition_fading),(star * 2.0 * galaxy + galaxy * 0.001 * transition_fading) * cosT * time[1].y * (1.0 - rainStrength) * (1.0 - moondisk));
				
			#else
				return mix(color, vec3(3.0),star * 2.0 * cosT * time[1].y * (1.0 - rainStrength) * (1.0 - moondisk));
			#endif
		} else {
			return color;
		}
	}
#endif