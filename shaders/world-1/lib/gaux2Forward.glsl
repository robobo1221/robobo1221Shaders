vec3 renderGaux2(vec3 color, vec3 normal){

	vec4 albedo = texture2D(gaux2, texcoord.st);
		albedo.rgb = pow(albedo.rgb, vec3(2.2));

	return mix(color, albedo.rgb * getShadingForward(normal, albedo.rgb) * mix(color, vec3(1.0), clamp(albedo.a, 0.0, 1.0)), pow(albedo.a, mix(0.25, 1.0, iswater)));
}