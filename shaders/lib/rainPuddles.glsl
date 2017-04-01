float getRainPuddles(vec3 wpos){
	wpos /= 3068.0;
	
	float noise = texture2D(noisetex, wpos.xz).x;
	noise += texture2D(noisetex, wpos.xz * 2.0).x / 2.0;
	noise += texture2D(noisetex, wpos.xz * 4.0).x / 4.0;
	
	return clamp((noise - mix(1.3, 0.5, wetness)) * 1.2, 0.0, 1.0);
}