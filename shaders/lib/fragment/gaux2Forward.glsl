vec3 renderGaux2(vec3 color, vec3 normal){

	vec4 albedo = forWardAlbedo;

	bool multMask = albedo.a > 0.0 + iswater && albedo.a < 1.0;

	#ifdef DYNAMIC_HANDLIGHT
		albedo.rgb = getDesaturation(albedo.rgb, mix(forwardEmissive, min(handLightMult * 10.0, 1.0), hand));
	#else
		albedo.rgb = getDesaturation(albedo.rgb, forwardEmissive);
	#endif
		albedo.rgb = pow(albedo.rgb, !multMask ? vec3(2.2) : vec3(1.0));

	vec3 shading = vec3(0.0);

	if (!multMask)
		shading = getShadingForward(normal, albedo.rgb);

	return mix(color, albedo.rgb * (multMask ? color : shading), float(albedo.a > 0.0 + iswater));
}