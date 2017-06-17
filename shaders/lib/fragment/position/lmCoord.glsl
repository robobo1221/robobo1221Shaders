	vec4 lightmaps = vec4(1.0);
	lightmaps.x = clamp(lmcoord.x * 1.0328125 - 0.0328125, 0.0, 1.0);
	
	lightmaps.y = clamp(lmcoord.y * 1.0328125 - 0.0328125, 0.0, 1.0);