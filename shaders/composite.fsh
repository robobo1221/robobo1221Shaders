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
varying vec3 sunColorClouds2D;
varying vec3 baseMoonColor;
varying vec3 moonColor;
varying vec3 moonColorClouds;
varying vec3 moonColorClouds2D;
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

uniform float aspectRatio;

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

const bool colortex4Clear = false;
const bool colortex5Clear = false;

const float ambientOcclusionLevel = 0.0;
const float eyeBrightnessHalfLife = 10.0;

*/

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/fragment/sky.glsl"
#include "/lib/fragment/volumetricClouds.glsl"
#include "/lib/fragment/volumetricLighting.glsl"
#include "/lib/fragment/2DClouds.glsl"

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord - jitter, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateViewSpacePosition(vec3 coord) {
	vec3 viewCoord = vec3(coord.xy - jitter, coord.z) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

#include "/lib/fragment/diffuseLighting.glsl"

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

vec3 renderTranslucents(vec3 color, vec4 data0, mat2x3 position, vec3 normal, vec3 viewVector, vec3 lightVector, vec3 wLightVector, vec2 lightmaps, float dither, float roughness, bool isWater){
	if (isWater) return color;
	
	vec3 correctedAlbedo = srgbToLinear(data0.rgb);

	vec3 litColor = calculateDirectLighting(correctedAlbedo, position, normal, viewVector, lightVector, wLightVector, lightmaps, roughness, dither, false, false);

	return mix(color * mix(vec3(1.0), data0.rgb, fsign(data0.a)), litColor, data0.a);
}

vec3 rayTaceReflections(vec3 viewPosition, float NoV, vec3 p, vec3 reflectedVector, float dither, vec3 sky, float skyLightmap) {
	const int rayTraceQuality = 16;
	const float rQuality = 1.0 / rayTraceQuality;

	int raySteps = rayTraceQuality + 4;
	int refinements = 4;

	vec3 direction = normalize(ViewSpaceToScreenSpace(viewPosition + reflectedVector) - p);

	float maxLength = rQuality;
    float minLength = maxLength * 0.01;

	float stepLength = mix(minLength, maxLength, NoV) * (dither + 1.0);

	float stepWeight = 1.0 / abs(direction.z);

	p += direction * stepLength;

	float depth = texture2D(depthtex1, p.xy).x;
	bool rayHit = false;

	while(--raySteps > 0){
		stepLength = clamp((depth - p.z) * stepWeight, minLength, maxLength);
		p = direction * stepLength + p;
		depth = texture2D(depthtex1, p.xy).x;

		if (clamp01(p) != p) return sky * skyLightmap;

		if (depth <= p.z)
            break;
	}

	float marchedDepth = depth;

	vec3 rp = p;
	float rdepth = depth;

	while (--refinements > 0) {

		rp = direction * clamp((depth - p.z) * stepWeight, -stepLength, stepLength) + p;
		rdepth = texture2D(depthtex1, rp.xy).x;
		bool rayHit = rdepth < rp.z;

		p = rayHit ? rp : p;
		depth = rayHit ? rdepth : depth;

		stepLength *= 0.5;

	}

	float sceneDepth = texture2D(depthtex0, p.xy).x;

	if (sceneDepth >= 1.0) return sky;

	bool visible = abs(p.z - marchedDepth) * min(stepWeight, 400.0) <= maxLength && 0.96 < sceneDepth;

	return visible ? decodeRGBE8(texture2D(colortex2, p.xy)) : sky * skyLightmap;
}

float calculateNoH(float radiusTan, float NoL, float NoV, float VoL){
	float radiusCos = inversesqrt(radiusTan * radiusTan + 1.0);

	float RoL = 2.0 * NoL * NoV - VoL;
	if (RoL >= radiusCos)
		return 1.0;

	float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RoL * RoL);
	float NoTr = rOverLengthT * (NoV - RoL * NoL);
	float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

	float triple = sqrt(clamp01(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL));

	float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
	float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
	float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;
	float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
	float xDenom = p * p + s * (s - 2.0 * p) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr +
				   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
	float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
	float sinTheta = twoX1 * xDenom;
	float cosTheta = 1.0 - twoX1 * xNum;

	NoTr = cosTheta * NoTr + sinTheta * NoBr;
	VoTr = cosTheta * VoTr + sinTheta * VoBr;

	float newNol = NoL * radiusCos + NoTr;
	float newVol = VoL * radiusCos + VoTr;
	float NoH = NoV + newNol;
	float HoH = 2.0 * newVol + 2.0;
	
	return sqrt(max0(NoH * NoH / HoH));
}

vec3 calculateSpecularBRDF(vec3 normal, vec3 lightVector, vec3 viewVector, float f0, float alpha2, const float tanSunRadius){
	vec3 H = normalize(lightVector - viewVector);
	
	float VoH = clamp01(dot(H, lightVector));
	float NoL = clamp01(dot(normal, lightVector));
	float NoV = clamp01(dot(normal, -viewVector));
	float VoL = (dot(lightVector, -viewVector));
	//float NoH = calculateNoH(tanSunRadius, NoL, NoV, VoL);
	float NoH = clamp01(dot(normal, H));

	float D = GGXDistribution(alpha2, NoH);
	float G = GSpecular(alpha2, NoV, NoL);
	vec3 F = Fresnel(f0, 1.0, VoH);

	return max0(F * D * G / (4.0 * NoL * NoV)) * NoL;
}

vec3 calculateSharpSunSpecular(vec3 normal, vec3 viewVector, float f0){
	vec3 reflectedVector = reflect(viewVector, normal);
	
	float LoR = dot(sunVector, reflectedVector);
	float NoV = clamp01(dot(normal, -viewVector));

	vec3 F = Fresnel(f0, 1.0, NoV);

	vec3 sunSpec = calculateSunSpot(LoR) * sunColor;
	vec3 moonSpec = calculateMoonSpot(-LoR) * moonColor;
	
	return (sunSpec + moonSpec) * F;
}

vec3 specularReflections(vec3 color, vec3 diffuseColor, vec3 viewPosition, vec3 p, vec3 viewVector, vec3 normal, float dither, float originalDepth, float roughness, float f0, float skyLightmap, float shadows){
	if (f0 < 0.005) return color;

	const int steps = 4;
	const float rSteps = 1.0 / steps;

	const float sunRadius = radians(sunAngularSize);
	const float tanSunRadius = tan(sunRadius);
	
	float alpha2 = roughness * roughness * roughness * roughness;

	vec3 sunReflection = vec3(0.0);

	skyLightmap = clamp01(skyLightmap * 1.1);

	vec3 reflection = vec3(0.0);
	vec3 fresnel = vec3(0.0);

	#ifdef TAA
		dither = fract(frameTimeCounter * (1.0 / 7.0) + dither);
	#endif

	if (roughness >= 0.03) {
		sunReflection = calculateSpecularBRDF(normal, lightVector, viewVector, f0, alpha2, sunRadius) * (sunColor + moonColor);

		float NoV = clamp01(dot(normal, -viewVector));

		vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
		mat3 tbn = mat3(tangent, cross(normal, tangent), normal);

		float specularOffset = dither * rSteps;

		for (int i = 0; i < steps; ++i) {
			vec3 halfVector = tbn * calculateRoughSpecular((float(i) + specularOffset) * rSteps, alpha2, steps);

			float VoH = abs(dot(halfVector, -viewVector));

			vec3 reflectVector = (2.0 * VoH) * halfVector + viewVector;
				 reflectVector = (dot(reflectVector, normal) <= 0.0) ? reflect(reflectVector, normal) : reflectVector;

			vec3 reflectVectorWorld = mat3(gbufferModelViewInverse) * reflectVector;

			float NoL = clamp01(dot(normal, reflectVector));
			float G = GSpecular(alpha2, NoV, NoL);

			vec3 sky = decodeRGBE8(texture2D(colortex3, sphereToCart(-reflectVectorWorld) * 0.5));
			reflection += rayTaceReflections(viewPosition, VoH, p, reflectVector, dither, sky, skyLightmap) * G;

			fresnel += Fresnel(f0, 1.0, VoH);
		}

		fresnel *= rSteps;
		reflection *= rSteps;
		
	} else {
		sunReflection = calculateSharpSunSpecular(normal, viewVector, f0);

		float VoN = clamp01(dot(normal, -viewVector));
		
		vec3 reflectVector = (2.0 * VoN) * normal + viewVector;
		vec3 reflectVectorWorld = mat3(gbufferModelViewInverse) * reflectVector;

		vec3 sky = decodeRGBE8(texture2D(colortex3, sphereToCart(-reflectVectorWorld) * 0.5));

		reflection = rayTaceReflections(viewPosition, VoN, p, reflectVector, dither, sky, skyLightmap);
		fresnel = Fresnel(f0, 1.0, VoN);

	}

	reflection *= fresnel;
	reflection += sunReflection * shadows;

	return blendMetallicDielectric(color, fresnel, reflection, diffuseColor, f0);
}

void calculateRefraction(mat2x3 position, vec3 normal, vec3 viewVector, bool isTranslucent, inout vec2 coord, inout float backDepth, inout mat2x3 backPosition, inout vec3 refractViewVector){
	if (isTranslucent) {
		vec3 flatNormal = clamp(normalize(cross(dFdx(position[0]), dFdy(position[0]))), -1.0, 1.0);
		vec3 waveDirection = normal - flatNormal;
		vec3 refractedVector = refract(viewVector, waveDirection, 0.75);

		vec3 refractedPosition = refractedVector * abs(distance(position[0], backPosition[0])) + position[0];
			 refractedPosition = ViewSpaceToScreenSpace(refractedPosition);
			 refractedPosition.z = texture2D(depthtex1, refractedPosition.xy).x;

		if (refractedPosition.z > texture2D(depthtex0, refractedPosition.xy).x){
			coord = refractedPosition.xy;
			backDepth = refractedPosition.z;

			backPosition[0] = calculateViewSpacePosition(refractedPosition);
			backPosition[1] = calculateWorldSpacePosition(backPosition[0]);

			float normFactor = inversesqrt(dot(backPosition[0], backPosition[0]));
			refractViewVector = normFactor * backPosition[0];
		}
	}
}

/* DRAWBUFFERS:5 */

void main() {
	float depth = texture2D(depthtex0, texcoord).x;
	float backDepth = texture2D(depthtex1, texcoord).x;

	bool isTranslucent = depth < backDepth;

	vec4 data0 = texture2D(colortex0, texcoord);
	vec4 data1 = texture2D(colortex1, texcoord);

	vec3 albedo = srgbToLinear(data0.rgb);

	mat2x3 position;
		   position[0] = calculateViewSpacePosition(texcoord, depth);
		   position[1] = calculateWorldSpacePosition(position[0]);

	mat2x3 backPosition;
		   backPosition[0] = calculateViewSpacePosition(texcoord, backDepth);
		   backPosition[1] = calculateWorldSpacePosition(backPosition[0]);

	vec3 viewVector = normalize(position[0]);

	vec3 normal = getNormal(data1.x);
	vec2 lightmaps = getLightmaps(data1.y);

	float roughness, f0, matFlag;

	getRoughnessF0(data1.z, roughness, f0);
	getMatflag(data1.w, matFlag);

	vec2 coord = texcoord;
	vec3 refractViewVector = viewVector;
	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);

	#ifdef REFRACTION
		calculateRefraction(position, normal, viewVector, isTranslucent, coord, backDepth, backPosition, refractViewVector);
	#endif

	float ambientFogOcclusion = eyeBrightnessSmooth.y * (1.0 / 255.0);
		  ambientFogOcclusion = pow2(ambientFogOcclusion);

	float vDotL = dot(viewVector, lightVector);
	float vDotV = dot(refractViewVector, sunVector);

	vec4 data2 = texture2D(colortex2, coord.xy);
	vec3 color = max0(decodeRGBE8(data2));

	vec3 worldVector = mat3(gbufferModelViewInverse) * refractViewVector;
	vec3 shadowLightVector = shadowLightPosition * 0.01;

	bool isWater = matFlag > 2.5 && matFlag < 3.5;

	float dither = bayer64(gl_FragCoord.xy);
	
	#ifdef TAA
		dither = fract(frameCounter * (1.0 / 7.0) + dither);
	#endif

	if (backDepth >= 1.0) {
		sky = calculateAtmosphere(vec3(0.0), refractViewVector, upVector, sunVector, moonVector, planetSphere, skyAbsorb, 25);
		color = sky;

		color += calculateSunSpot(vDotV) * sunColorBase * skyAbsorb;
		color += calculateMoonSpot(-vDotV) * moonColorBase * skyAbsorb;
		color += calculateStars(worldVector, wMoonVector) * skyAbsorb;
		
		//color = calculateClouds2D(color, sky, worldVector, wLightVector, dither, vDotL, 24);
	}

	#ifdef VOLUMETRIC_CLOUDS
		color = calculateVolumetricClouds(color, sky, worldVector, wLightVector, backPosition[1], backDepth, planetSphere, dither, vDotL, VC_QUALITY, VC_SUNLIGHT_QUALITY, 3);
	#endif
	
	if (isTranslucent && (!isWater || isEyeInWater == 1)){
		color = calculateVolumetricLight(color, position[1], backPosition[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

	if (isTranslucent) {
		color = renderTranslucents(color, data0, position, normal, -viewVector, shadowLightVector, wLightVector, lightmaps, dither, roughness, isWater);
	}

	if (isWater || isEyeInWater == 1) {
		color = calculateVolumetricLightWater(color, isEyeInWater == 1 ? gbufferModelViewInverse[3].xyz : position[1], isEyeInWater == 1 ? position[1] : backPosition[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

	if (depth < 1.0 && isEyeInWater == 0)
	{
		vec3 shadowPosition = remapShadowMap(transMAD(shadowMatrix, position[1]));
		float hardShadows = float(texture2D(shadowtex0, shadowPosition.xy).x > shadowPosition.z - rShadowMapResolution) * transitionFading;
		color = specularReflections(color, albedo, position[0], vec3(texcoord, depth), viewVector, normal, dither, depth, roughness, f0, lightmaps.y, hardShadows);
	}

	if (isEyeInWater == 0) {
		color = calculateVolumetricLight(color, gbufferModelViewInverse[3].xyz, position[1], wLightVector, worldVector, dither, ambientFogOcclusion, vDotL);
	}

/*
	vec3 marchDirection = normalize(reflect(viewVector, normal));

	vec3 startPosition = position[0];

	const float marchSteps = 200;
	const float rMarchSteps = 1.0 / marchSteps;
	float stepLength = 100.0 * rMarchSteps;

	vec3 marchIncrement = marchDirection * stepLength;
	vec3 marchPosition = startPosition;

	float marchDepth = texture2D(depthtex0, ViewSpaceToScreenSpace(marchPosition).xy).x;

	vec3 result = vec3(0.0);
	vec3 screenPositionMarched = vec3(texcoord, marchDepth);

	for(int i = 0; i < marchSteps; i++){
		if (clamp01(screenPositionMarched) != screenPositionMarched) {result = vec3(1.0); continue;}
		marchPosition += marchIncrement;

		screenPositionMarched = ViewSpaceToScreenSpace(marchPosition);
		marchDepth = texture2D(depthtex0, screenPositionMarched.xy).x;
		if (screenPositionMarched.z > marchDepth) break;
	}

	bool outOfBounds = length(marchPosition) < marchSteps * stepLength;
	bool visible = abs(screenPositionMarched.z - marchDepth) * length(marchPosition) < rMarchSteps && outOfBounds;

	result = (result != vec3(1.0) && visible) ? decodeRGBE8(texture2D(colortex2, screenPositionMarched.xy)) : vec3(0.0);

	color = result;
	*/

	//color = decodeRGBE8(texture2D(colortex3, texcoord * 0.5));

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
