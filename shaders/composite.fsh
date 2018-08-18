#version 120
#define program_composite0
#define FRAGMENT

varying vec2 texcoord;
varying mat4 shadowMatrix;

varying vec3 sunVector;
varying vec3 moonVector;
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

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex5;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 shadowLightPosition;
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
#include "/lib/fragment/directLighting.glsl"

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateWorldSpacePosition(vec3 coord) {
	return transMAD(gbufferModelViewInverse, coord);
}

vec3 getNormal(float data) {
	return decodeNormal(data, gbufferModelView);
}

vec2 getLightmaps(float data)
{
	vec2 lightmaps = decodeVec2(data);
	return vec2(lightmaps.x, lightmaps.y * lightmaps.y);
}

vec3 renderTranslucents(vec3 color, mat2x3 position, vec3 normal, vec3 viewVector, vec3 lightVector, vec3 wLightVector, vec2 lightmaps, float roughness){
	vec4 albedo = texture2D(colortex0, texcoord);
	vec3 correctedAlbedo = srgbToLinear(albedo.rgb);

	vec3 litColor = calculateDirectLighting(correctedAlbedo, position[1], normal, viewVector, lightVector, wLightVector, lightmaps, roughness);

	return mix(color * mix(vec3(1.0), albedo.rgb, fsign(albedo.a)), litColor, albedo.a);
}

/* DRAWBUFFERS:5 */

void main() {
	float depth = texture2D(depthtex0, texcoord).x;
	float backDepth = texture2D(depthtex1, texcoord).x;

	bool isTranslucent = depth < backDepth;

	vec4 data1 = texture2D(colortex1, texcoord);
	vec4 data2 = texture2D(colortex2, texcoord);

	vec3 color = max0(decodeRGBE8(data2));

	mat2x3 position;
		   position[0] = calculateViewSpacePosition(texcoord, depth);
		   position[1] = calculateWorldSpacePosition(position[0]);

	mat2x3 backPosition;
		   backPosition[0] = calculateViewSpacePosition(texcoord, backDepth);
		   backPosition[1] = calculateWorldSpacePosition(backPosition[0]);

	vec3 viewVector = normalize(position[0]);
	vec3 worldVector = mat3(gbufferModelViewInverse) * viewVector;
	vec3 shadowLightVector = shadowLightPosition * 0.01;

	vec3 normal = getNormal(data1.x);
	vec2 lightmaps = getLightmaps(data1.y);

	float dither = bayer64(gl_FragCoord.xy);
	#ifdef VOLUMETRIC_CLOUDS
		if (backDepth >= 1.0) color = calculateVolumetricClouds(color, worldVector, wLightVector, backPosition[1], dither);
	#endif

	color = calculateVolumetricLight(color, backPosition[1], wLightVector, worldVector, dither);
	
	if (isTranslucent) {
		color = renderTranslucents(color, position, normal, -viewVector, shadowLightVector, wLightVector, lightmaps, 1.0);
		color = calculateVolumetricLight(color, position[1], wLightVector, worldVector, dither);
	}

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
