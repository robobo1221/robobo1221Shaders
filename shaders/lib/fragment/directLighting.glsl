#include "/lib/utilities/lightingOperators.glsl"

vec3 calculateShadows(vec3 worldPosition, vec3 normal, vec3 lightVector) {
    vec3 shadowPosition = transMAD(shadowMatrix, worldPosition);
	     shadowPosition = remapShadowMap(shadowPosition);

	float NdotL = dot(normal, lightVector);

	float pixelSize = rShadowMapResolution;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL + 1.0);
		  shadowBias = shadowBias * calculateDistFactor(shadowPosition.xy) * pixelSize * 0.2;

    float shadows = calculateHardShadows(shadowtex1, shadowPosition, shadowBias);

    return vec3(shadows);
}

float calculateTorchLightAttenuation(float lightmap){
	float dist = clamp((1.0 - lightmap) * 15.0, 0.0, 15.0);
	return (1.0 - clamp01((1.0 - lightmap) * 2.0 - 1.0)) / (dist * dist);
}

vec3 calculateDirectLighting(vec3 albedo, vec3 worldPosition, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec3 wLightVector, vec2 lightmaps, float roughness) {
	vec3 shadows = calculateShadows(worldPosition, normal, shadowLightVector);
		 shadows *= calculateVolumeLightTransmittance(worldPosition, wLightVector, 8);

	float diffuse = GeometrySmithGGX(normal, viewVector, shadowLightVector, roughness);

	vec3 lighting = vec3(0.0);

	lighting += shadows * diffuse * (sunColor + moonColor);
	lighting += FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal) * lightmaps.y * PI;
	lighting += calculateTorchLightAttenuation(lightmaps.x) * torchColor;

	return lighting * albedo;
}
