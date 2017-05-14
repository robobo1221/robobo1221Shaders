
#define CLOUD_PLANE_2D


#ifdef CLOUD_PLANE_2D

	float subSurfaceScattering(vec3 lPos, vec3 uPos, float size){
		return pow(clamp(dot(lPos, uPos),0.0,1.0),size);
	}

	float degreesToRadiance(float x){
		return x * (pi / 180.0); 
	}

	float cloudNoise(vec2 coord){
		float noise = 1.0;

		coord.y *= 2.0;
		coord.x *= 0.5;

		noise = texture2D(noisetex, vec2(0.0, coord.y) * 0.7).x;
		noise = texture2D(noisetex, vec2(coord.y, coord.x) * 0.7).x * 2.0;
		noise /= noise + 1.0;
		noise -= 0.2;

		float deg0 = -90.0 - (noise * 45.0 * 0.5);
		float rad0 = degreesToRadiance(deg0);
		mat2 rM0 = mat2(cos(rad0), -sin(rad0), sin(rad0), cos(rad0));

		vec2 rCoord0 = rM0 * coord;
			 rCoord0.y *= 9.0;

		float deg1 = -90.0 - (noise * 45.0 * 0.5);
		float rad1 = degreesToRadiance(deg1);
		mat2 rM1 = mat2(cos(rad1), -sin(rad1), sin(rad1), cos(rad1));

		vec2 rCoord1 = rM1 * coord;
			 rCoord1.y *= 9.0;

		noise += texture2D(noisetex, rCoord0 * 4.0).x * 0.025;
		noise += texture2D(noisetex, rCoord1 * 16.0).x * 0.0125;

		coord.x *= 2.0;
		noise += (texture2D(noisetex, coord * 4.0).x - 0.1) * 0.05;

		float cl = max(pow(noise, 4.0) - 0.005, 0.0) * 10.0;
		cl *= (1.0 - rainStrength * 0.5);
		cl /= cl + 1.0;
		cl = cl * cl * (3.0 - 2.0 * cl);

		return cl;
	}

	vec3 getClouds(vec3 color, vec3 fpos, float land){

		if (land < 0.9){
			vec2 wind = abs(vec2(frameTimeCounter / 20000.0, 0.0));

			//Cloud Generation Constants.
			const float cloudHeight = 600.0;

			vec4 fposition = normalize(vec4(fpos,0.0));
			vec3 tPos = getWorldSpace(fposition).rgb;
			vec3 wVec = normalize(tPos);
			
			float cosT = clamp(dot(fposition.rgb,upVec),0.0,1.0);

			float sunUpCos = clamp(dot(sunVec, upVec) * 0.9 + 0.1, 0.0, 1.0);
			float MoonUpCos = clamp(dot(moonVec, upVec) * 0.9 + 0.1, 0.0, 1.0);

			vec3 dayTimeColor = sunlight * sunUpCos;
			vec3 nightTimeColor = moonlight * MoonUpCos;

			vec3 cloudCol = (dayTimeColor + nightTimeColor) * 2.0;
				 cloudCol = mix(cloudCol, ambientlight, rainStrength);
				 cloudCol *= mix(1.0, 0.5, rainStrength * time[1].y);

			float totalcloud = 	0.0f;
			float height = 		0.0f;

			vec3 cloudPosition = vec3(0.0);
				
			height = cloudHeight / wVec.y;

			cloudPosition = wVec * height;

			vec2 coord = (cloudPosition.xz + cameraPosition.xz * 2.5) / 200000.0;
				 coord += wind;

			totalcloud = cloudNoise(coord);

			return mix(color, cloudCol ,totalcloud * sqrt(cosT));
		} else {
			return color;
		}

	}
#endif