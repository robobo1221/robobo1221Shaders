#version 120
#define program_deferred
#define FRAGMENT

varying vec2 texcoord;
varying mat4 shadowMatrix;

flat varying vec2 jitter;

varying mat3x4 skySH;

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

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform float eyeAltitude;
uniform float frameTimeCounter;

uniform int frameCounter;

#include "/lib/utilities.glsl"

vec3 getNormal(float data) {
	return decodeNormal(data, gbufferModelView);
}

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord - jitter, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateWorldSpacePosition(vec3 coord) {
	return transMAD(gbufferModelViewInverse, coord);
}

vec3 ViewSpaceToScreenSpace(vec3 viewPos) {
	return ((projMAD(gbufferProjection, viewPos) / -viewPos.z)) * 0.5 + 0.5;
}

vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir) {
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(3.0 * rPI);
    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 sqrtOverPI = vec2(sqrt1OverPI, sqrt3OverPI);
    const vec4 foo = halfnhalf.xyxy * sqrtOverPI.xyyy;

    vec4 sh = foo * vec4(1.0, lightDir.yzx);

    // know to work
    return vec3(
        dot(sh,cR),
        dot(sh,cG),
        dot(sh,cB)
    );
}

#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/fragment/volumetricClouds.glsl"
#include "/lib/fragment/volumetricLighting.glsl"
#include "/lib/fragment/directLighting.glsl"
#include "/lib/fragment/sky.glsl"

vec2 getLightmaps(float data)
{
	vec2 lightmaps = decodeVec2(data);
	return vec2(lightmaps.x, lightmaps.y * lightmaps.y);
}

void getRoughnessF0(float data, out float roughness, out float f0){
	vec2 decodedData = decodeVec2(data);
	
	roughness = decodedData.x;
	f0 = decodedData.y;
}

void getMatflag(float data, out float matFlag){
	vec2 decodedData = decodeVec2(data);

	matFlag = (1.0 - decodedData.y) * 32.0 + (1.0 / 8.0);
}

vec3 calculateSkySphere(vec2 p){
	if (any(greaterThan(p, vec2(0.501)))) return vec3(0.0);
	p *= 2.0;

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);
	vec3 color = vec3(0.0);

	vec3 positionWorld = cartToSphere(p) * vec3(1.0, 1.0, -1.0);
	vec3 positionView = mat3(gbufferModelView) * positionWorld;
	vec3 viewVector = -positionView;

	float vDotL = dot(viewVector, sunVector);

	sky = calculateAtmosphere(vec3(0.0), viewVector, upVector, sunVector, moonVector, planetSphere, skyAbsorb, 25);
	color = sky;

	#ifdef VOLUMETRIC_CLOUDS
		color = calculateVolumetricClouds(color, sky, -positionWorld, wLightVector, positionWorld, 1.0, planetSphere, 0.5, vDotL, 10, 3, 3);
	#endif

	//color += calculateSunSpot(vDotL) * sunColorBase * skyAbsorb;
	//color += calculateMoonSpot(-vDotL) * moonColorBase * skyAbsorb;
	//color += calculateStars(positionWorld, wMoonVector) * skyAbsorb;

	return color;
}

/* DRAWBUFFERS:203 */

void main() {
	float depth = texture2D(depthtex1, texcoord).x;
	vec3 skySphere = calculateSkySphere(texcoord);

	gl_FragData[2] = encodeRGBE8(max0(skySphere));

	if (depth >= 1.0) {
		return;
		discard;
	}

	vec4 data0 = texture2D(colortex0, texcoord);

	mat2x3 position;
		   position[0] = calculateViewSpacePosition(texcoord, depth);
		   position[1] = calculateWorldSpacePosition(position[0]);

	vec3 viewVector = -normalize(position[0]);
	vec3 worldVector = mat3(gbufferModelViewInverse) * viewVector;
	vec3 shadowLightVector = shadowLightPosition * 0.01;

	float roughness, f0, matFlag;
	vec4 data1 = texture2D(colortex1, texcoord);

	vec3 albedo = srgbToLinear(data0.rgb);
	vec3 normal = getNormal(data1.x);
	vec2 lightmaps = getLightmaps(data1.y);

	getRoughnessF0(data1.z, roughness, f0);
	getMatflag(data1.w, matFlag);

	bool isVegitation = (matFlag > 1.99 && matFlag < 2.01);

	float dither = bayer64(gl_FragCoord.xy);
	
	#ifdef TAA
		dither = fract(frameCounter * (1.0 / 7.0) + dither);
	#endif

	vec3 finalColor = calculateDirectLighting(albedo, position[1], normal, viewVector, shadowLightVector, wLightVector, lightmaps, roughness, dither, isVegitation);

	gl_FragData[0] = encodeRGBE8(max0(finalColor));
	gl_FragData[1] = vec4(0.0);
}
