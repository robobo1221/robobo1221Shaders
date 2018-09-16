#version 120
#define program_composite0
#define FRAGMENT

varying vec2 texcoord;
varying mat4 shadowMatrix;

flat varying vec2 jitter;

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
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float eyeAltitude;

uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform int frameCounter;

/*
const float sunPathRotation = -45.0;

const int colortex0Format = RGBA8;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA8;
const int colortex4Format = RGBA8;
const int colortex5Format = RGBA16F;

const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;

/const float ambientOcclusionLevel = 0.0;
const float eyeBrightnessHalfLife = 10.0;

*/

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/volumetricClouds.glsl"
#include "/lib/fragment/volumetricLighting.glsl"
#include "/lib/fragment/directLighting.glsl"

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord - jitter, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 ViewSpaceToScreenSpace(vec3 viewPos) {
	return ((projMAD(gbufferProjection, viewPos) / -viewPos.z)) * 0.5 + 0.5 + vec3(jitter, 0.0);
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

void getRoughnessF0(float data, out float roughness, out float f0){
	vec2 decodedData = decodeVec2(data);
	
	roughness = decodedData.x;
	f0 = decodedData.y;
}

void getMatflag(float data, out float matFlag){
	vec2 decodedData = decodeVec2(data);

	matFlag = (1.0 - decodedData.y) * 32.0 + (1.0 / 8.0);
}

vec3 renderTranslucents(vec3 color, mat2x3 position, vec3 normal, vec3 viewVector, vec3 lightVector, vec3 wLightVector, vec2 lightmaps, float roughness, bool isWater){
	vec4 albedo = texture2D(colortex0, texcoord);
	vec3 correctedAlbedo = srgbToLinear(albedo.rgb);

	albedo.a = isWater ? 0.0 : albedo.a;

	vec3 litColor = calculateDirectLighting(correctedAlbedo, position[1], normal, viewVector, lightVector, wLightVector, lightmaps, roughness, false);

	return mix(color * mix(vec3(1.0), albedo.rgb, fsign(albedo.a)), litColor, albedo.a);
}

vec3 rayTaceReflections(vec3 viewPosition, vec3 p, vec3 reflectedVector, float dither, vec3 sky, float skyLightmap) {
	const int rayTraceQuality = 16;
	const float rQuality = 1.0 / rayTraceQuality;

	int raySteps = rayTraceQuality + 4;
	int refinements = 4;

	vec3 direction = ViewSpaceToScreenSpace(viewPosition + reflectedVector);

	float maxLength = rQuality;
    float minLength = maxLength * 0.01;

	float stepLength = minLength + minLength * dither;

	direction = normalize(direction - p);

	float stepWeight = 1.0 / abs(direction.z);

	p += direction * stepLength;

	float depth = texture2D(depthtex0, p.xy).x;
	bool rayHit = false;

	while(--raySteps > 0){
		stepLength = clamp((depth - p.z) * stepWeight, minLength, maxLength);
		p = direction * stepLength + p;
		depth = texture2D(depthtex1, p.xy).x;

		if (clamp01(p) != p) return sky * skyLightmap;

		rayHit = depth <= p.z;
		if (rayHit)
            break;
	}

	float marchedDepth = depth;

	while (--refinements > 0) {

		p = direction * clamp((depth - p.z) * stepWeight, -stepLength, stepLength) + p;
		depth = texture2D(depthtex1, p.xy).x;

		stepLength *= 0.5;
	}

	if (depth >= 1.0) return sky;

	bool visible = abs(p.z - marchedDepth) * min(stepWeight, 400.0) <= maxLength && 0.96 < texture2D(depthtex0, p.xy).x;

	return visible ? decodeRGBE8(texture2D(colortex2, p.xy)) : sky * skyLightmap;
}

vec3 specularReflections(vec3 color, vec3 viewPosition, vec3 p, vec3 viewVector, vec3 normal, float dither, float originalDepth, float roughness, float f0, float skyLightmap, float shadows){
	if (f0 < 0.005) return color;

	float alpha2 = roughness * roughness * roughness * roughness;

	float NoV = clamp01(-dot(normal, viewVector));

	vec3 fresnel = Fresnel(f0, 1.0, NoV);
	vec3 reflectVector = reflect(viewVector, normal);
	vec3 reflectVectorWorld = mat3(gbufferModelViewInverse) * reflectVector;

	float NoL = clamp01(dot(normal, reflectVector));
	float LoV = dot(reflectVector, viewVector);

	vec3 sunReflection = specularGGX(normal, -viewVector, lightVector, roughness, f0) * (sunColor + moonColor);
	vec3 sky = decodeRGBE8(texture2D(colortex3, sphereToCart(-reflectVectorWorld) * 0.5));
	
	skyLightmap = clamp01(skyLightmap * 1.1);
	vec3 reflection = max0(rayTaceReflections(viewPosition, p, reflectVector, dither, sky, skyLightmap) * fresnel);
	reflection += sunReflection * shadows;

	return reflection + color * (1.0 - fresnel);
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
	
	#ifdef TAA
		dither = fract(frameCounter * (1.0 / 7.0) + dither);
	#endif

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);

	float ambientFogOcclusion = eyeBrightnessSmooth.y * (1.0 / 255.0);
		  ambientFogOcclusion = pow2(ambientFogOcclusion);

	float vDotL = dot(viewVector, sunVector);

	if (backDepth >= 1.0) {
		sky = calculateAtmosphere(vec3(0.0), viewVector, upVector, sunVector, moonVector, planetSphere, skyAbsorb, 25);
		color = sky;

		color += calculateSunSpot(vDotL) * sunColorBase * skyAbsorb;
		color += calculateMoonSpot(-vDotL) * moonColorBase * skyAbsorb;
		color += calculateStars(worldVector, wMoonVector) * skyAbsorb;
	}

	float roughness, f0, matFlag;

	getRoughnessF0(data1.z, roughness, f0);
	getMatflag(data1.w, matFlag);

	bool isWater = matFlag > 2.5 && matFlag < 3.5;

	#ifdef VOLUMETRIC_CLOUDS
		color = calculateVolumetricClouds(color, sky, worldVector, wLightVector, backPosition[1], backDepth, planetSphere, dither, vDotL, VC_QUALITY, 5, 3);
	#endif
	
	if (isTranslucent && (!isWater || isEyeInWater == 1)){
		color = calculateVolumetricLight(color, isEyeInWater == 1 ? position[1] : gbufferProjectionInverse[3].xyz, isEyeInWater == 1 ? backPosition[1] : position[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

	if (isTranslucent) {
		color = renderTranslucents(color, position, normal, -viewVector, shadowLightVector, wLightVector, lightmaps, roughness, isWater);
	}

	if (isWater || isEyeInWater == 1) {
		color = calculateVolumetricLightWater(color, isEyeInWater == 1 ? gbufferModelViewInverse[3].xyz : position[1], isEyeInWater == 1 ? position[1] : backPosition[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

	if (depth < 1.0 && isEyeInWater == 0)
	{
		vec3 shadowPosition = remapShadowMap(transMAD(shadowMatrix, position[1]));
		float hardShadows = float(texture2D(shadowtex0, shadowPosition.xy).x > shadowPosition.z - 0.001) * transitionFading;
		color = specularReflections(color, position[0], vec3(texcoord, depth), viewVector, normal, dither, depth, roughness, f0, lightmaps.y, hardShadows);
	}

	if (isEyeInWater == 0) {
		color = calculateVolumetricLight(color, gbufferModelViewInverse[3].xyz, position[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

	//color = decodeRGBE8(texture2D(colortex3, texcoord * 0.5));

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
