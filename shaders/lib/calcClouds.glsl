
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

			vec3 cloudCol = mix(mix(sunlight, moonlight * 2.0, time[1].y), vec3(0.1) * (1.0 - time[1].y * 0.8), rainStrength) * (1.0 - (time[1].x + time[0].x) * 0.5);
			cloudCol *= mix(1.0, 0.5, rainStrength * time[1].y);

			float height = (cloudHeight / wVec.y);

			float weight = 0.0;
			float density = 0.0;
			float totalcloud = 0.0;

			vec3 cloudPosition = vec3(0.0);
			
			if (cosT <= 1.0) {
				for (int i = 0; i < itterations; i++){

					cloudPosition = wVec * (height - i * 150 / itterations * (1.0 - pow(cosT, 2.0)));

					vec2 coord = (cloudPosition.xz + cameraPosition.xz * 2.5) / 200000.0;
						coord += wind;

					noise = texture2D(noisetex, coord - wind * 0.25).x;
					noise += texture2D(noisetex, coord * 3.5).x / 3.5;
					noise += texture2D(noisetex, coord * 6.125).x / 6.125;
					noise += texture2D(noisetex, coord * 12.25).x / 12.25;
					noise /= clamp(texture2D(noisetex,coord / 3.1).x * 1.0,0.0,1.0);

					noise /= (0.13 * CLOUD_COVERAGE);

					float cl = max(noise-0.7,0.0);
					cl = max(cl,0.)*0.04 * (1.0 - rainStrength * 0.5);
					density = pow(max(1-cl*2.5,0.),2.0) / 11.0 / 3.0;
					density *= 2.0 * CLOUD_DENSITY;

					totalcloud += density;
					if (totalcloud > (1.0 - 1.0 / itterations + 0.1)) break;

					weight++;
				}
			}

			totalcloud /= weight;
			totalcloud = mix(totalcloud,0.0,pow(1-density, 100.0));

			float sss = subSurfaceScattering(moonVec, fposition.rgb, 50.0) * (1.0 - rainStrength);

			cloudCol = mix(cloudCol, sunlight * 10.0,
			pow(cosT, 0.5) * subSurfaceScattering(sunVec, fposition.rgb, 15.0) * pow(1.0 - density, 100.0) * (1.0 - rainStrength) * cosSunUpAngle);
			
			cloudCol *= 1.0 + pow(1.0 - density, 25.0) * 5.0 * (1.0 + sss * 10.0 * pow(1.0 - totalcloud, 200.0) * transition_fading * (1.0 - rainStrength) * pow(cosT, 0.5));

			return pow(mix(pow(color, vec3(2.2)), pow(cloudCol, vec3(2.2)),totalcloud * cosT * 0.25), vec3(0.4545));
		} else {
			return color;
		}

	}
#endif