vec3 renderGaux2(vec3 color, vec3 normal){

	vec4 albedo = texture2D(gaux2, texcoord.st);
	#ifdef DYNAMIC_HANDLIGHT
		albedo.rgb = albedo.rgb, mix(forwardEmissive, min(handLightMult * 10.0, 1.0), hand);
	#endif
	
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * (2.0 - hand);

	return mix(color, albedo.rgb * getShadingForward(normal, albedo.rgb) * mix(color * 4.0, vec3(1.0), clamp(albedo.a, 0.0, 1.0)), pow(albedo.a, 0.05));
}