
#define CLOUDS
	#define CLOUD_COVERAGE 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
	#define CLOUD_DENSITY 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]


#ifdef CLOUDS

	float subSurfaceScattering(vec3 lPos, vec3 uPos, float size){
		return pow(clamp(dot(lPos, uPos),0.0,1.0),size);
	}

	vec3 getClouds(vec3 color, vec3 fpos, float land, int itterations){

		if (land < 0.9){
			vec2 wind = abs(vec2(frameTimeCounter / 20000.0));

			//Cloud Generation Constants.
			const float cloudHeight = 600.0;
			
			float noise = 1.0;

			vec4 fposition = normalize(vec4(fpos,0.0));
			vec3 tPos = getWorldSpace(fposition).rgb;
			vec3 wVec = normalize(tPos);
			
			float cosT = clamp(dot(fposition.rgb,upVec),0.0,1.0);
			float cosSunUpAngle = clamp(smoothstep(-0.05,0.5,dot(sunVec, upVec)* 0.95 + 0.05) * 10.0, 0.0, 1.0);

			vec3 cloudCol = mix(mix(sunlight, moonlight * 2.0, time[1].y), vec3(1.0) * (1.0 - time[1].y * 0.96), rainStrength) * (1.0 - (time[1].x + time[0].x) * 0.5);
				 cloudCol *= mix(1.0, 0.5, rainStrength * time[1].y);
				 cloudCol *= 0.175  * 0.5;

			float density = 	0.0f;
			float totalcloud = 	0.0f;
			float height = 		0.0f;

			vec3 cloudPosition = vec3(0.0);
			
			if (cosT <= 1.0) {
				for (int i = 0; i < itterations; i++){
				
					height = cloudHeight / wVec.y - ((totalcloud * 15000.0 / itterations * bayer16x16(texcoord.st)) * 2.0 - 1.0);

					cloudPosition = wVec * height;

					vec2 coord = (cloudPosition.xz + cameraPosition.xz * 2.5) / 200000.0;
						coord += wind;

					noise = texture2D(noisetex, coord - wind * 0.25).x;
					noise += texture2D(noisetex, coord * 3.5).x / 3.5;
					noise += texture2D(noisetex, coord * 6.125).x / 6.125;
					noise += texture2D(noisetex, coord * 12.25).x / 12.25;
					noise += texture2D(noisetex, coord * 24.50).x / 24.50;
					noise /= clamp(texture2D(noisetex,coord / 5.0).x,0.0,1.0);

					noise /= 0.15 * CLOUD_COVERAGE;

					float cl = max(noise-1.0,0.0);
					cl = max(cl,0.)*0.05 * (1.0 - rainStrength * 0.5);
					density = pow(max(1.0 - cl * 2.0,0.),2.0) * 0.0303030;
					density *= 2.0 * CLOUD_DENSITY;

					totalcloud += density;
					
					if (totalcloud > (1.0 - 1.0 / itterations + 0.1)) break;
				}
			}

			totalcloud /= itterations;
			totalcloud = mix(totalcloud,0.0,pow(1.0 - totalcloud, 100.0));

			float sss = subSurfaceScattering(moonVec, fposition.rgb, 6.0) * (1.0 - rainStrength);

			cloudCol = mix(cloudCol, sunlight * 3.0,
			pow(cosT, 0.5) * subSurfaceScattering(sunVec, fposition.rgb, 10.0) * pow(1.0 - totalcloud, 600.0) * (1.0 - rainStrength) * cosSunUpAngle);
			
			float scatterMask = pow(1.0 - totalcloud, 100.0);
			
			cloudCol *= 1.0 + scatterMask * (1.0 - rainStrength * (1.0 - cosSunUpAngle)) * 6.0 * (1.0 + sss * 5.0 * (1.0 - cosSunUpAngle)) * sqrt(cosT);
			cloudCol = mix(cloudCol, ambientlight * 0.4, (1.0 - scatterMask) * 0.3);
			cloudCol *= 0.75;

			return mix(color, cloudCol ,clamp(totalcloud * 500.0, 0.0, 1.0) * sqrt(cosT));
		} else {
			return color;
		}

	}
#endif