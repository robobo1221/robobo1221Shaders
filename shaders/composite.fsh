#version 120
#define program_composite0
#define FRAGMENT

varying vec2 texcoord;
varying mat4 shadowMatrix;

varying vec3 sunVector;
varying vec3 moonVector;
varying vec3 upVector;
varying vec3 wLightVector;

varying vec3 sunColor;
varying vec3 sunColorClouds;
varying vec3 moonColor;
varying vec3 moonColorClouds;
varying vec3 skyColor;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex5;
uniform sampler2D shadowtex0;

uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform float eyeAltitude;

uniform float frameTimeCounter;

const int noiseTextureResolution = 64;
const float rNoiseTexRes = 1.0 / noiseTextureResolution;

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/volumetricClouds.glsl"
#include "/lib/fragment/volumetricLighting.glsl"

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateWorldSpacePosition(vec3 coord) {
	return transMAD(gbufferModelViewInverse, coord);
}

/* DRAWBUBBERS:5 */

void main() {
	float depth = texture2D(depthtex0, texcoord).x;
	float backDepth = texture2D(depthtex1, texcoord).x;

	vec3 colorSample2 = max0(decodeRGBE8(texture2D(colortex2, texcoord)));
	vec3 color = colorSample2;

	vec4 translucentAlbedo = texture2D(colortex0, texcoord);

	mat2x3 position;
		   position[0] = calculateViewSpacePosition(texcoord, depth);
		   position[1] = calculateWorldSpacePosition(position[0]);

	mat2x3 backPosition;
		   backPosition[0] = calculateViewSpacePosition(texcoord, backDepth);
		   backPosition[1] = calculateWorldSpacePosition(backPosition[0]);

	vec3 viewVector = normalize(position[0]);
	vec3 worldVector = mat3(gbufferModelViewInverse) * viewVector;

	float dither = bayer64(gl_FragCoord.xy);
	#ifdef VOLUMETRIC_CLOUDS
		if (backDepth >= 1.0) color = calculateVolumetricClouds(color, worldVector, wLightVector, backPosition[1], dither);
	#endif
	
	color = mix(color, translucentAlbedo.rgb, translucentAlbedo.a);
	color = calculateVolumetricLight(color, backPosition[1], wLightVector, worldVector, dither);

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
