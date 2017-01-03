
	sunlight = vec3(1.0, 0.6, 0.25) * time[0].x;
	sunlight = mix(sunlight, vec3(1.0, 1.0, 1.0), sqrt(time[0].y));
	sunlight = mix(sunlight, vec3(1.0, 0.6, 0.25), pow(time[1].x, 2.0));
	sunlight = mix(sunlight, vec3(1.0, 0.3, 0.01), time[1].y);

	ambientColor = vec3( 0.058, 0.11, 0.28) * time[0].x;
	ambientColor = mix(ambientColor, vec3( 0.058, 0.11, 0.28), time[0].y);
	ambientColor = mix(ambientColor, vec3( 0.058, 0.11, 0.28), time[1].x);
	ambientColor /= ambientColor.b;
	ambientColor = mix(ambientColor, vec3(0.3, 0.55, 1.0) * 0.1, time[1].y);

	moonlight = vec3(0.3, 0.55, 1.0) * 0.075;

	ambientColor = mix(ambientColor, vec3(dot(ambientColor, vec3(0.3333))), 0.2 * time[1].y);
	moonlight = mix(moonlight, vec3(dot(moonlight, vec3(0.3333))), 0.2 * time[1].y);
