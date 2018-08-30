#version 120
#define program_composite0
#define VERTEX

varying vec2 texcoord;
varying mat4 shadowMatrix;

varying vec3 sunVector;
varying vec3 wSunVector;
varying vec3 moonVector;
varying vec3 wMoonVector;
varying vec3 upVector;
varying vec3 lightVector;
varying vec3 wLightVector;

varying vec3 baseSunColor;
varying vec3 sunColor;
varying vec3 sunColorClouds;
varying vec3 baseMoonColor;
varying vec3 moonColor;
varying vec3 moonColorClouds;
varying vec3 skyColor;

varying float transitionFading;

uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float eyeAltitude;
uniform int worldTime;

#include "/lib/utilities.glsl"
#include "/lib/fragment/sky.glsl"

void main() {
	gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
	texcoord = gl_MultiTexCoord0.xy;

	const float tTime = (1.0 / 50.0);
	float wTime = float(worldTime);
	transitionFading = clamp01(clamp01((wTime - 23215.0) * tTime) + (1.0 - clamp01((wTime - 12735.0) * tTime)) + clamp01((wTime - 12925.0) * tTime) * (1.0 - clamp01((wTime - 23075.0) * tTime)));

	upVector = upPosition * 0.01;
	sunVector = sunPosition * 0.01;
	moonVector = -sunVector;

	wSunVector = mat3(gbufferModelViewInverse) * sunVector;
	wMoonVector = mat3(gbufferModelViewInverse) * moonVector;

	lightVector = (worldTime > 23075 || worldTime < 12925 ? sunVector : moonVector);
	wLightVector = mat3(gbufferModelViewInverse) * lightVector;

	baseSunColor = sunColorBase;
	baseMoonColor = moonColorBase;

	sunColor = sky_transmittance(vec3(0.0, sky_planetRadius, 0.0), wSunVector, 3) * baseSunColor;
	moonColor = sky_transmittance(vec3(0.0, sky_planetRadius, 0.0), wMoonVector, 3) * baseMoonColor;
	sunColorClouds = sky_transmittance(vec3(0.0, sky_planetRadius + volumetric_cloudMaxHeight, 0.0), wSunVector, 3) * baseSunColor;
	moonColorClouds = sky_transmittance(vec3(0.0, sky_planetRadius + volumetric_cloudMaxHeight, 0.0), wMoonVector, 3) * baseMoonColor;
	
	vec2 planetSphere = vec2(0.0);
	skyColor = calculateAtmosphere(vec3(0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), wSunVector, wMoonVector, planetSphere, 10);

	shadowMatrix = shadowProjection * shadowModelView;
}
