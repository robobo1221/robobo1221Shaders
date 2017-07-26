#define STARS

//#define DRAW_GALAXY

#ifdef STARS
	vec3 getStars(vec3 color, vec3 fpos, float land){
		if (land < 0.9) {
			vec3 uVec = normalize(fpos);
			vec3 tPos = toWorldSpaceNoMAD(gbufferModelViewInverse, fpos);
			
			const float moonAngularDiameterCos = 0.99833194915;

			float cosViewSunAngle = dot(uVec, moonVec);
			float moondisk = smoothstep(moonAngularDiameterCos,moonAngularDiameterCos+0.001,cosViewSunAngle);

			float cosT = max(dot(uVec,upVec),0.0);

			vec3 starCoord = tPos * (50.0 / tPos.y);
			
			//Curve the fragposition so that the stars and the galaxy doesnt look weird
			starCoord *= mix(1.0, cosT, 1.0 - cosT);
			
			vec2 coord = starCoord.xz * 0.005;

				float starNoise = texture2D(noisetex,fract(coord.xy * 0.5)).x;
					  starNoise = 0.5 * texture2D(noisetex,fract(coord.xy)).x + starNoise;
				
				float star = max(starNoise - 1.3,0.0);
				
			#ifdef DRAW_GALAXY
				
			float galaxyMask = 0.01 * starCoord.z + 0.75;
			
			float galaxyMask0 = 0.125 * texture2D(noisetex, fract(starCoord * 0.0002).xz).x;
				  galaxyMask0 = 0.0675 * texture2D(noisetex, fract(starCoord * 0.0004).xz).x + galaxyMask0;
				  galaxyMask0 = 0.0335 * texture2D(noisetex, fract(starCoord * 0.0016).xz).x + galaxyMask0;
			
			galaxyMask += galaxyMask0;
			galaxyMask = min(galaxyMask, 1.0 - galaxyMask);
			galaxyMask = max(galaxyMask * 8.0 - 1.5,0.0) * 0.45;
			galaxyMask *= galaxyMask * 0.8;
		
			vec3 galaxy = galaxyMask * mix(vec3(1.0, 1.0, 2.0), vec3(100.0, 75.0, 50.0), pow3(galaxyMask0 * 0.75 + 0.25));
				 galaxy = mix(galaxy, vec3(50.0), pow7(vec3(dot(galaxy * 0.14, vec3(0.33333))))) * 2.0 + 1.0;
				 galaxy *= time[1].y;

				return mix(color, mix(vec3(1.0), galaxy, transition_fading),(star * (2.0 * galaxy) + (galaxy * 0.001) * transition_fading) * cosT * time[1].y * (1.0 - rainStrength) * (1.0 - moondisk));
				
			#else
				return mix(color, vec3(3.0),(star * 2.0) * (cosT * time[1].y) * ((1.0 - rainStrength) * (1.0 - moondisk)));
			#endif
		} else {
			return color;
		}
	}
#endif