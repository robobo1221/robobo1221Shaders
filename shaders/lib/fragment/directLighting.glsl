#include "/lib/utilities/lightingOperators.glsl"
#include "/lib/uniform/shadowDistortion.glsl"

float calculateHardShadows(sampler2D shadowMap, vec3 shadowPosition, float bias) {
    return 1.0 - fstep(texture2D(shadowMap, shadowPosition.xy).x, shadowPosition.z - bias);
}

vec3 calculateShadows(vec3 worldPosition, vec3 normal, vec3 lightVector) {
    vec3 shadowPosition = transMAD(shadowMatrix, worldPosition);
	     shadowPosition = remapShadowMap(shadowPosition);

	float NdotL = dot(normal, lightVector);

	float pixelSize = rShadowMapResolution;

	float shadowBias = sqrt(sqrt(1.0 - NdotL * NdotL) / NdotL + 1.0);
		  shadowBias = shadowBias * calculateDistFactor(shadowPosition.xy) * pixelSize * 0.2;

    float shadows = calculateHardShadows(shadowtex0, shadowPosition, shadowBias);

    return vec3(shadows);
}

vec3 calculateDirectLighting(vec3 albedo, vec3 worldPosition, vec3 normal, vec3 viewVector, vec3 shadowLightVector, vec2 lightmaps, float roughness) {
	vec3 shadows = calculateShadows(worldPosition, normal, shadowLightVector);
	float diffuse = GeometrySmithGGX(normal, viewVector, shadowLightVector, roughness);

	vec3 lighting = vec3(0.0);

	lighting += shadows * diffuse * (sunColor + moonColor);
	lighting += FromSH(skySH[0], skySH[1], skySH[2],mat3(gbufferModelViewInverse) * normal) * lightmaps.y * PI; 

	return lighting * albedo;
}
