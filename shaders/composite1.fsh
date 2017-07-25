#version 120
#include "lib/util/fastMath.glsl"

#include "lib/util/colorRange.glsl"

#define SHADOW_DISTORTION 0.85

#define DYNAMIC_HANDLIGHT

//-------------------------------------------------//

#include "lib/options/directLightOptions.glsl" //Go here for shadowResolution, distance etc.
#include "lib/options/options.glsl"

/*

//----------------------------------------------------------------------------------------------------------------------------------------------------//

Standard shader configuration.

const float 	wetnessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]
const float 	drynessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]

const int 		noiseTextureResolution  	= 1024;

const float		sunPathRotation				= -40.0; //[-50.0 -40.0 -30.0 -20.0 -10.0 0.01 10.0 20.0 30.0 40.0 50.0]

const float 	ambientOcclusionLevel 		= 1.0; //[0.0 0.25 0.5 0.75 1.0]

const float		eyeBrightnessHalflife		= 16.0; //[1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 16.0 18.0 20.0 24.0 28.0 32.0 ]

const bool 		gcolorMipmapEnabled			= true;
const bool 		gaux4MipmapEnabled			= true;
const bool 		gnormalMipmapEnabled		= true;

//----------------------------------------------------------------------------------------------------------------------------------------------------//

Texture Formats

const int 		gcolorFormat				= RGBA16;
const int 		gaux1Format					= RGB10_A2;
const int 		gaux2Format					= RGBA16;
const int 		gaux3Format					= RGB10_A2;
const int 		gaux4Format					= RGB10_A2;
const int 		gnormalFormat				= RGB10_A2;
const int 		compositeFormat				= RGBA16;
*/

//----------------------------------------------------------------------------------------------------------------------------------------------------//

//-------------------------------------------------//

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying float handLightMult;

uniform sampler2D gcolor;
uniform sampler2D composite;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gdepth;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux4;
uniform sampler2D gnormal;
uniform sampler2D noisetex;

uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform ivec2 eyeBrightnessSmooth;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;

uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

const float pi = 3.141592653589793238462643383279502884197169;

float comp = 1.0-near/far/far;

float timefract = worldTime;


mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f)),
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),

				vec2(

				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and mindight.

float transition_fading = 1.0-(
    clamp(0.00333333*timefract - 40.,0.0,1.0)-
    clamp(0.00333333*timefract - 43.3333,0.0,1.0)+
    clamp(0.005*timefract - 110.,0.0,1.0)-
    clamp(0.005*timefract - 117.,0.0,1.0)
);

float getEyeBrightnessSmooth = 1.0 - pow3(clamp(eyeBrightnessSmooth.y / 220.0f,0.0,1.0));

//Unpack textures.
vec3 color = 			texture2D(gcolor, texcoord.st).rgb;
vec3 normal = 			texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3 compositeNormals = texture2D(composite, texcoord.st).rgb * 2.0 - 1.0;
vec4 aux = 				texture2D(gaux1, texcoord.st);
vec4 aux2 = 			texture2D(gdepth, texcoord.st);
vec4 forWardAlbedo = 	texture2D(gaux2, texcoord.st);
float pixeldepth = 		texture2D(gdepthtex, texcoord.st).x;
float pixeldepth2 = 	texture2D(depthtex1, texcoord.st).x;

float land = 			float(pixeldepth2 < comp);
float land2 = 			float(pixeldepth < comp);

float translucent = 	float(aux.g > 0.09 && aux.g < 0.11);
float emissive = 		float(aux.g > 0.34 && aux.g < 0.36);
float iswater = 		float(aux2.g > 0.12 && aux2.g < 0.28);
float istransparent = 	float(aux2.g > 0.28 && aux2.g < 0.32);
float hand = 			float(aux2.g > 0.85 && aux2.g < 0.87);

#include "lib/util/spaceConversions.glsl"

float expDepth(float dist){
	return (far * (dist - near)) / (dist * (far - near));
}

float getDepth(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec4 bilateralTexture(sampler2D sample, vec2 position, float lod){

	const vec2 offset[4] = vec2[4](
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(0.0, -1.0)
	);

	float totalWeight = 0.0;
	vec4 result = vec4(0.0);

	float linearDepth = ld(pixeldepth2);
	vec2 offsetMult = 5.0 / vec2(viewWidth, viewHeight);

	for (int i = 0; i < 4; i++){

		vec2 coord = offset[i] * offsetMult + position;

		vec3 offsetNormal = texture2D(gnormal, coord, lod).rgb * 2.0 - 1.0;
		float normalWeight = pow32(abs(dot(offsetNormal, normal)));

		float offsetDepth = ld(texture2D(depthtex1, coord).r);
		float depthWeight = 1.0 / (abs(linearDepth - offsetDepth) + 1e-8);

		float weight = normalWeight * depthWeight;

		result += texture2D(sample, coord, lod) * weight;

		totalWeight += weight;
	}

	result /= totalWeight;

	return max(result, 0.0);
}

float getEmissiveLightmap(vec4 aux, bool isForwardRendered){

	float lightmap = aux.r * 2.0;
	
	lightmap		= pow(lightmap, 2.0 * EMISSIVE_LIGHT_ATTEN);
	lightmap 		= 1.0 / (1.0 - lightmap) - 1.0;
	lightmap 		= clamp(lightmap, 0.0, 100000.0);
	
	lightmap 		*= 0.08 * (1.0 + mix(getEyeBrightnessSmooth,1.0,time[1].y) / 0.08) * 0.23;
	
	lightmap		= isForwardRendered ? lightmap * (1.0 - emissive) + emissive : lightmap; //Prevent glowstone and all emissive stuff to clip with the lightmap
	lightmap		= isForwardRendered ? lightmap * (1.0 - handLightMult * hand) + handLightMult * hand : lightmap; //Also do this to the hand

	return lightmap * EMISSIVE_LIGHT_MULT;
}

float getSkyLightmap(float l){
	return pow(l, skyLightAtten);
}

vec3 fragpos = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, pixeldepth));
vec3 uPos = fNormalize(fragpos);

vec3 fragpos2 = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, pixeldepth2));

vec3 worldPosition = toWorldSpace(gbufferModelViewInverse, fragpos).rgb;
vec3 worldPosition2 = toWorldSpace(gbufferModelViewInverse, fragpos2).rgb;

vec3 getEmessiveGlow(vec3 color, vec3 emissivetColor, vec3 emissiveMap, float emissive){

	emissiveMap += (emissivetColor * 20.0) * (sqrt(dot(color, color)) * emissive);

	return emissiveMap;
}

#ifdef DYNAMIC_HANDLIGHT
	float getHandItemLightFactor(vec3 fragpos, vec3 normal){
		float handItemLightFactor = sqrt(dot(fragpos, fragpos));
			handItemLightFactor = 1.0 - handItemLightFactor / 25.0;
			handItemLightFactor = smoothstep(0.5, 1.1, handItemLightFactor) * 0.5;
		
			handItemLightFactor = getEmissiveLightmap(vec4(handItemLightFactor), true);
			
			handItemLightFactor *= pow2(clamp(mix(1.0, max(dot(-fragpos.xyz,normal),0.0), handItemLightFactor), 0.0, 1.0)) * 1.6;
			handItemLightFactor *= 1.0 - emissive; //Temp fix for emissive blocks getting lit up while you hold a lightsource.
		
		return handItemLightFactor * handLightMult;
	}

	float handItemLightFactor = getHandItemLightFactor(fragpos2, normal);
	float emissiveLM = getEmissiveLightmap(aux, true) + handItemLightFactor;
#else
	float emissiveLM = getEmissiveLightmap(aux, true);
#endif

float OrenNayar(vec3 v, vec3 l, vec3 n, float r) {
    
    r *= r;
    
    float NdotL = dot(n,l);
    float NdotV = dot(n,v);
    
    float t = max(NdotL,NdotV);
    float g = max(0.0, dot(v - n * NdotV, l - n * NdotL));
    float c = g/t - g*t;
    
    float a = 0.285 / (r+0.57) + 0.5;
    float b = 0.45 * r / (r+0.09);

    return max(0.0, NdotL) * ( b * c + a);

}

#include "lib/util/etc/nightDesat.glsl"
#include "lib/util/noise.glsl"
#include "lib/util/etc/cloudCoverage.glsl"
#include "lib/lightColor.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/phases.glsl"
#include "lib/fragment/position/shadowPos.glsl"
#include "lib/fragment/shading/shadows.glsl"
#include "lib/fragment/shading/shadingForward.glsl"
#include "lib/fragment/sky/skyGradient.glsl"
#include "lib/fragment/sky/calcClouds.glsl"
#include "lib/fragment/sky/calcStars.glsl"
#include "lib/fragment/gaux2Forward.glsl"
#include "lib/displacement/normalDisplacement/waterBump.glsl"
#include "lib/fragment/caustics.glsl"
#include "lib/fragment/waterFog.glsl"

float getSubSurfaceScattering(){
	float cosV = pow10(clamp(dot(uPos.xyz, lightVector), 0.0, 1.0)) * 4.0;
		  cosV /= cosV * 0.01 + 1.0;

	return clamp(cosV, 0.0, 90.0);
}

#ifdef GLOBAL_ILLUMINATION
	vec3 getGlobalIllumination(vec2 uv){

		const float lod = 2.5;

		vec3 globalIllumination = bilateralTexture(gaux4, uv, lod).rgb;
		globalIllumination /= 1.0 - globalIllumination;
		
		return getDesaturation(globalIllumination, min(emissiveLM, 1.0));
	}
#endif

vec3 shadows = getShadow(pixeldepth2, normal, 2.0, true, false);

vec3 getShading(vec3 color){

	float skyLightMap = getSkyLightmap(aux.z);

	float diffuse = mix(OrenNayar(fragpos.rgb, lightVector, normal, 0.0), 1.0, translucent * 0.5) * ((1.0 - rainStrength) * transition_fading);
		  diffuse = diffuse * mix(1.0, pow(skyLightMap, 0.25) * 0.9 + 0.1, isEyeInWater * (1.0 - iswater));
		  diffuse = clamp(diffuse*1.01-0.01, 0.0, 1.0);

	vec3 emissiveLightmap = emissiveLM * mix(emissiveLightColor, vec3(1.0), emissiveLM * 0.05);
		emissiveLightmap = getEmessiveGlow(color,emissiveLightmap, emissiveLightmap, emissive);

	float lightAbsorption = smoothstep(-0.1, 0.5, dot(upVec, sunVec));

	vec3 lightCol = mix(sunlight * lightAbsorption, moonlight, time[1].y) * max(dynamicCloudCoverage * 2.4 - 1.4, 0.0) * sunlightAmount;
	vec3 sunlightDirect = lightCol * (shadows * diffuse) * (1.0 + (getSubSurfaceScattering() * translucent));

	vec3 indirectLight = mix(ambientlight, lightCol * lightAbsorption, mix(mix(mix(0.15, 0.0, rainStrength),0.0,time[1].y), 0.0, 1.0 - skyLightMap)) * (0.14 * skyLightMap * shadowDarkness) + (minLight * (1.0 - skyLightMap));
	
	vec3 globalIllumination = vec3(0.0);

	#if defined WATER_CAUSTICS && !defined PROJECTED_CAUSTICS
		sunlightDirect = waterCaustics(sunlightDirect, fragpos2);
	#endif
	
	#ifdef GLOBAL_ILLUMINATION
		globalIllumination = getGlobalIllumination(texcoord.st) * (lightCol * transition_fading) * (1.0 - rainStrength);
	#endif

	return ((sunlightDirect + indirectLight) + globalIllumination + emissiveLightmap) * color;
}

#ifdef VOLUMETRIC_LIGHT

	float getVolumetricRays() {

		///////////////////////Setting up functions///////////////////////
			
			vec3 rSD = vec3(0.0);
				rSD.x = 0.0;
				rSD.y = 4.0 / VL_QUALITY;
				rSD.z = dither;
			
			rSD.z *= rSD.y;

			const int maxDist = int(VL_DISTANCE);
			float minDist = 0.01f;
				minDist += rSD.z;

			float weight = 128.0 / rSD.y;

			const float diffthresh = 0.0005;	// Fixes light leakage from walls
			
			vec3 worldposition = vec3(0.0);

			for (minDist; minDist < maxDist; ) {

				//MAKING VL NOT GO THROUGH WALLS
				if (getDepth(pixeldepth) < minDist){
					break;
				}

				//Getting worldpositon
				worldposition = toShadowSpace(toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, expDepth(minDist))));

				//Rescaling ShadowMaps
				worldposition = biasedShadows(worldposition);

				//Projecting shadowmaps on a linear depth plane
				#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
					float shadow0 = shadowStep(shadowtex0, vec3(worldposition.rg, worldposition.b + diffthresh ));
					float shadow1 = shadowStep(shadowtex1, vec3(worldposition.rg, worldposition.b + diffthresh ));
					float caustics = length(texture2D(shadowcolor0, worldposition.rg).rgb * 10.0);

				rSD.x += mix(shadow0, shadow1, caustics);
				#else
					rSD.x += shadowStep(shadowtex1, vec3(worldposition.rg, worldposition.b + diffthresh ));
				#endif
				
				minDist += rSD.y;
		}

			rSD.x /= weight;
			rSD.x *= 1.0 - isEyeInWater * 0.5;
			
			return rSD.x;
	}


#else

float getVolumetricRays(){
	return 0.0;
}

#endif

#ifdef VOLUMETRIC_CLOUDS

float getVolumetricCloudNoise(vec3 p){

	float wind = abs(frameTimeCounter - 0.5);

	p.xz += wind;
	
	p *= 0.02;

	float noise = noise3D(vec3(p.x - wind * 0.01, p.y, p.z - wind * 0.015));
		  noise += noise3D(p * 3.5) * 0.28571428571428571428571428571429;
		  noise += abs(noise3D(p * 6.125) * 2.0 - 1.0) * 0.16326530612244897959183673469388;
		  noise += abs(noise3D(p * 12.25) * 2.0 - 1.0) * 0.08163265306122448979591836734694;

		  noise = noise * (1.0 - rainStrength * 0.5);
		  noise = pow2(max(1.0 - noise * 1.5 * dynamicCloudCoverageMult,0.)) * 0.0303030;

	return clamp(noise * 10.0, 0.0, 1.0);
}

vec3 getVolumetricCloudPosition(float depth)
{
	vec3 position = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, expDepth(depth)));
	     position = toWorldSpace(gbufferModelViewInverse, position);

	return position + cameraPosition;
}

vec4 getVolumetricCloudsColor(vec3 wpos){
	
	const float height = VOLUMETRIC_CLOUDS_HEIGHT;  		//Height of the clouds
	const float distRatio = VOLUMETRIC_CLOUDS_THICKNESS;  	//Distance between top and bottom of the cloud in block * 10.

	float maxHeight = (distRatio * 0.5) + height;
	float minHeight = height - (distRatio * 0.5);

	if (wpos.y < minHeight || wpos.y > maxHeight){
		return vec4(0.0);
	} else {

		float sunViewCos = max(dot(sunVec, uPos.xyz), 0.0);
			//Inverse Square Root
			//Min it to prevent black dot bug on the sun
			sunViewCos = min((0.5 / sqrt(1.0 - sunViewCos)) - 0.5, 100000.0);
			//Reinhard to prevent over exposure
			sunViewCos /= 1.0 + sunViewCos * 0.01; 

		float moonViewCos = max(dot(moonVec, uPos.xyz), 0.0);
			//Inverse Square Root
			//Min it to prevent black dot bug on the moon
			moonViewCos = min((0.5 / sqrt(1.0 - moonViewCos)) - 0.5, 100000.0);
			//Reinhard to prevent over exposure
			moonViewCos /= 1.0 + moonViewCos * 0.01; 

		float sunUpCos = clamp(dot(sunVec, upVec) * 0.9 + 0.1, 0.0, 1.0);
		float MoonUpCos = clamp(dot(moonVec, upVec) * 0.9 + 0.1, 0.0, 1.0);

		float cloudAlpha = getVolumetricCloudNoise(wpos);
		float cloudTreshHold = pow12(1.0f - clamp(distance(wpos.y, height) / (distRatio / 2.0f), 0.0f, 1.0f));

		cloudAlpha *= cloudTreshHold;

		float absorption = clamp((-(minHeight - wpos.y) / distRatio), 0.0f, 1.0f);

		float sunLightAbsorption = pow3(absorption * 0.86) * dynamicCloudCoverage;

		vec3 dayTimeColor = (sunlight * 16.0) * sunUpCos;
			 dayTimeColor += sunlight * (sunlight * sunViewCos) * (64.0 * sqrt(sunLightAbsorption) * sunUpCos);

		vec3 nightTimeColor = (moonlight * 16.0) * MoonUpCos;
			 nightTimeColor += (moonlight * moonViewCos) * (8.0 * sqrt(sunLightAbsorption) * MoonUpCos);

		vec3 rainColor = ambientlight;
			 rainColor += (ambientlight * 64.0) * (sunLightAbsorption * (sqrt(sunUpCos) * 0.9 + 0.1));

		vec3 totalCloudColor = (dayTimeColor + nightTimeColor) * sunLightAbsorption;
			 totalCloudColor = mix(totalCloudColor, rainColor, rainStrength);

		vec3 cloudColor = mix(totalCloudColor, ambientlight * (0.25 + rainStrength) * dynamicCloudCoverage, pow4(1.0 - absorption / 2.8)) * 0.5;

		return vec4(cloudColor, cloudAlpha);
	}
}

vec4 getVolumetricClouds(vec3 color){

	vec4 clouds = vec4(pow(color, vec3(2.2)), 0.0);

	float nearPlane = 2.0;			//start to where the ray should march.
	float farPlane = far; 		//End from where the ray should march.

    float increment = far / (13.0 * max(VOLUMETRIC_CLOUDS_QUALITY, 0.000001));		//Max the quality to prevent deviding by 0

	farPlane += dither * increment;

	vec3 fixedWorldPosition = mix(worldPosition2, worldPosition, iswater * (1.0 - isEyeInWater));
	float worldPositionDistance = sqrt(dot(fixedWorldPosition, fixedWorldPosition));

	while (farPlane > nearPlane){

		vec3 wpos = getVolumetricCloudPosition(farPlane);

		float volumetricDistance = length(wpos - cameraPosition.xyz);

		if (worldPositionDistance < volumetricDistance){
			clouds.a = 0.0;
		} else {

			vec4 result = getVolumetricCloudsColor(wpos);
				result.a = clamp(result.a * VOLUMETRIC_CLOUDS_DENSITY, 0.0, 1.0);

			if (length(worldPosition) < volumetricDistance){
				result.rgb = renderGaux2(result.rgb, compositeNormals);
			}

			clouds.rgb = mix(clouds.rgb, result.rgb, min(result.a * VOLUMETRIC_CLOUDS_DENSITY, 1.0));
			clouds.a += result.a * VOLUMETRIC_CLOUDS_DENSITY;
		}

		farPlane -= increment;
	}

	return clouds;
}

#endif

void main()
{
	color = getDesaturation(pow(color, vec3(2.2)), min(emissiveLM, 1.0));

	vec3 sunMult = vec3(0.0);
	vec3 moonMult = vec3(0.0);

	if (land > 0.9) {
		color = getShading(color);	
	}
	else {

		//color = pow(color, vec3(2.2)); // Uncomment this line to get minecraft's default sky. And comment the line under to get minecraft's default sky.
		
		color = pow(getAtmosphericScattering(vec3(0.0), fragpos2.rgb, 1.0, ambientlight, sunVec, moonVec, upVec, sunMult, moonMult), vec3(2.2));

		#ifdef STARS
			color = getStars(color, fragpos2.rgb, land);
		#endif
		
		#ifdef CLOUD_PLANE_2D
			color = getClouds(color, fragpos2.rgb, land);
		#endif
	}

	if (land2 > 0.9){
		color = renderGaux2(color, compositeNormals);

		#ifdef WATER_DEPTH_FOG
			if (isEyeInWater < 0.9) color = getWaterDepthFog(color, fragpos, fragpos2);
		#endif
	}

	color = pow(color, vec3(0.4545));

	#ifdef VOLUMETRIC_CLOUDS
		vec4 VolumetricClouds = getVolumetricClouds(color);
			 VolumetricClouds /= MAX_COLOR_RANGE;
	#endif
	
/* DRAWBUFFERS:015 */
	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE, getVolumetricRays());
	gl_FragData[1] = vec4(vec3(forWardAlbedo.a, aux2.gb), shadowsForward);

	#ifdef VOLUMETRIC_CLOUDS
		gl_FragData[2] = VolumetricClouds;
	#endif
}
