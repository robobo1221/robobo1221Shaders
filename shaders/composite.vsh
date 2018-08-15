#version 120
#define program_composite0
#define VERTEX

varying vec2 texcoord;

varying vec3 sunVector;
varying vec3 moonVector;
varying vec3 upVector;
varying vec3 wLightVector;

varying vec3 sunColor;
varying vec3 sunColorClouds;
varying vec3 moonColor;
varying vec3 moonColorClouds;
varying vec3 skyColor;

uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float eyeAltitude;

#include "/lib/utilities.glsl"
#include "/lib/fragment/sky.glsl"

void main() {
	gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
	texcoord = gl_MultiTexCoord0.xy;

	upVector = upPosition * 0.01;
	sunVector = sunPosition * 0.01;
	moonVector = -sunVector;

	vec3 wSunVector = mat3(gbufferModelViewInverse) * sunVector;
	vec3 wMoonVector = mat3(gbufferModelViewInverse) * moonVector;

	wLightVector = wSunVector;

	sunColor = sky_transmittance(vec3(0.0, sky_planetRadius, 0.0), wSunVector, 3) * sunColorBase;
	moonColor = sky_transmittance(vec3(0.0, sky_planetRadius, 0.0), wMoonVector, 3) * moonColorBase;
	sunColorClouds = sky_transmittance(vec3(0.0, sky_planetRadius + volumetric_cloudHeight, 0.0), wSunVector, 3) * sunColorBase;
	moonColorClouds = sky_transmittance(vec3(0.0, sky_planetRadius + volumetric_cloudHeight, 0.0), wMoonVector, 3) * moonColorBase;
	
	skyColor = calculateAtmosphere(vec3(0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), wSunVector, wMoonVector, 10);
}
