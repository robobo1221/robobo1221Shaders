
#define CLOUD_PLANE_2D


#ifdef CLOUD_PLANE_2D

	float subSurfaceScattering(vec3 lPos, vec3 uPos, float size){
		return pow(clamp(dot(lPos, uPos),0.0,1.0),size);
	}

	float cloudNoise(vec2 coord, vec2 wind){
		float noise = 1.0;

		coord -= wind * 0.8;

		noise = texture2D(noisetex, vec2(coord.y * 3.0, coord.x * 0.5) * 0.7).x * 2.0;
		noise /= noise + 1.0;
		noise -= 0.3;
		noise = max(noise, 0.0);

		coord += wind * 0.8;

		float deg0 = 90.0 - noise * 4.0;
		float rad0 = radians(deg0);
		mat2 rM0 = mat2(cos(rad0), -sin(rad0), sin(rad0), cos(rad0));

		vec2 rCoord0 = coord;
		rCoord0 = rM0 * rCoord0;
		rCoord0.y *= 3.0;
		rCoord0.x = 0.0;

		noise += texture2D(noisetex, (rCoord0 + wind * 0.5) * 8.0).x * 0.025;
		noise += texture2D(noisetex, rCoord0 * 16.0).x * 0.0125;

		coord.x *= 2.0;
		noise += (texture2D(noisetex, coord * 4.0).x) * 0.05;

		float cl = max(pow(noise, 4.0) - 0.005, 0.0) * 5.0;
		cl *= (1.0 - rainStrength * 0.5);
		cl /= cl + 1.0;

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

			float height = cloudHeight / wVec.y;
			vec3 cloudPosition = wVec * height;

			vec2 coord = (cloudPosition.xz + cameraPosition.xz * 2.5) / 200000.0;
				 coord += wind;

			float totalcloud = cloudNoise(coord, wind);
			
			float cosT = clamp(dot(fposition.rgb,upVec),0.0,1.0);

			float sunUpCos = clamp(dot(sunVec, upVec) * 0.95 + 0.15, 0.0, 1.0);
			float MoonUpCos = clamp(dot(moonVec, upVec) * 0.95 + 0.15, 0.0, 1.0);

			vec3 dayTimeColor = sunlight * sunUpCos;
				 dayTimeColor *= 1.0 + subSurfaceScattering(sunVec, fposition.rgb, 5.0) * 10.0 * pow(1.0 - totalcloud, 5.0);

			vec3 nightTimeColor = moonlight * MoonUpCos * 3.0;
				 nightTimeColor *= 1.0 + subSurfaceScattering(moonVec, fposition.rgb, 5.0) * 10.0 * pow(1.0 - totalcloud, 5.0);

			vec3 cloudCol = (dayTimeColor + nightTimeColor);
				 cloudCol = mix(cloudCol, ambientlight, rainStrength);
				 cloudCol *= mix(1.0, 0.5, rainStrength * time[1].y);

			return mix(color, cloudCol, totalcloud * cosT);
		} else {
			return color;
		}

	}
#endif