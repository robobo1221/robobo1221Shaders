float getRainPuddles(vec3 wpos){
	wpos *= 0.000325945241199;
	
	float noise = texture2D(noisetex, wpos.xz).x;
		  noise = 0.5 * texture2D(noisetex, wpos.xz * 2.0).x + noise;
		  noise = 0.25 * texture2D(noisetex, wpos.xz * 4.0).x + noise;
	
	return clamp((0.96 * wetness) + (noise - 1.56), 0.0, 1.0);
}