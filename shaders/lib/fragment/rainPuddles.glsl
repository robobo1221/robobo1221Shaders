float getRainPuddles(vec3 wpos){
	wpos *= 0.000325945241199;
	
	float noise = texture2D(noisetex, wpos.xz).x;
		  noise += texture2D(noisetex, wpos.xz * 2.0).x * 0.5;
		  noise += texture2D(noisetex, wpos.xz * 4.0).x * 0.25;
	
	return clamp((0.96 * wetness) + (noise - 1.56), 0.0, 1.0);
}