#version 120
//#extension GL_ARB_gpu_shader5 : enable

#include "lib/colorRange.glsl"

#define SHADOW_BIAS 0.85

#define DYNAMIC_HANDLIGHT

//-------------------------------------------------//

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.
#include "lib/options.glsl"

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
const bool 		gdepthMipmapEnabled			= true;
const bool 		compositeMipmapEnabled		= true;

//----------------------------------------------------------------------------------------------------------------------------------------------------//

Texture Formats

const int 		gcolorFormat				= RGBA16;
const int 		gaux1Format					= RGB10_A2;
const int 		gaux2Format					= RGBA16;
const int 		gaux3Format					= RGB10_A2;
const int 		gaux4Format					= RGB5_A1;
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

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22000.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

#include "lib/cloudCoverage.glsl"
#include "lib/lightColor.glsl"

//Unpack textures.
vec3 color = 			texture2D(gcolor, texcoord.st).rgb;
vec3 normal = 			texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3 normal2 = 			texture2D(composite, texcoord.st).rgb * 2.0 - 1.0;
vec4 aux = 				texture2D(gaux1, texcoord.st);
vec4 aux2 = 			texture2D(gdepth, texcoord.st);
vec4 forWardAlbedo = 	texture2D(gaux2, texcoord.st);

float pixeldepth = texture2D(gdepthtex, texcoord.st).x;
float pixeldepth2 = texture2D(depthtex1, texcoord.st).x;

float land = float(pixeldepth2 < comp);
float land2 = float(pixeldepth < comp);
float translucent = float(aux.g > 0.09 && aux.g < 0.11);
float emissive = float(aux.g > 0.34 && aux.g < 0.36);

float iswater = float(aux2.g > 0.12 && aux2.g < 0.28);
float istransparent = float(aux2.g > 0.28 && aux2.g < 0.32);
float hand = float(aux2.g > 0.85 && aux2.g < 0.87);

float dynamicExposure = mix(1.0,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 3.0f)));

float expDepth(float dist){
	return (far * (dist - near)) / (dist * (far - near));
}

float getDepth(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

#define g(a) (-4.*a.x*a.y+3.*a.x+a.y*2.)

float bayer16x16(vec2 p){

	p *= vec2(viewWidth,viewHeight);
	
    vec2 m0 = vec2(mod(floor(p/8.), 2.));
    vec2 m1 = vec2(mod(floor(p/4.), 2.));
    vec2 m2 = vec2(mod(floor(p/2.), 2.));
    vec2 m3 = vec2(mod(floor(p)   , 2.));

    return (g(m0)+g(m1)*4.0+g(m2)*16.0+g(m3)*64.0)/255.;
}
#undef g

float dither = bayer16x16(texcoord.st);

float getEmissiveLightmap(vec4 aux, bool isForwardRendered){

	float lightmap = aux.r;
	
	lightmap		= pow(lightmap, 2.0 * EMISSIVE_LIGHT_ATTEN);
	lightmap 		= 1.0 / (1.0 - lightmap) - 1.0;
	lightmap 		= clamp(lightmap, 0.0, 100000.0);
	
	lightmap 		*= 0.08 * (1.0 + mix(dynamicExposure,1.0,time[1].y) / 0.08) * 0.23;
	
	lightmap		= isForwardRendered ? lightmap * (1.0 - emissive) + emissive : lightmap; //Prevent glowstone and all emissive stuff to clip with the lightmap
	lightmap		= isForwardRendered ? lightmap * (1.0 - handLightMult * hand) + handLightMult * hand : lightmap; //Also do this to the hand

	return lightmap * EMISSIVE_LIGHT_MULT;
}

float getSkyLightmap(float l){
	return pow(l, skyLightAtten);
}

vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

vec3 toScreenSpace(vec3 p) {
        vec3 p3 = vec3(p) * 2. - 1.;
        vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
        return fragposition.xyz / fragposition.w;
}

vec3 fragpos = toScreenSpace(vec3(texcoord.st, pixeldepth));
vec3 uPos = normalize(fragpos);

vec3 fragpos2 = toScreenSpace(vec3(texcoord.st, pixeldepth2));

vec4 getWorldSpace(vec4 fragpos){

	vec4 wpos = gbufferModelViewInverse * fragpos;

	return wpos;
}

vec3 worldPosition = getWorldSpace(vec4(fragpos, 0.0)).rgb;
vec3 worldPosition2 = getWorldSpace(vec4(fragpos2, 0.0)).rgb;

vec3 getEmessiveGlow(vec3 color, vec3 emissivetColor, vec3 emissiveMap, float emissive){

	emissiveMap += (emissivetColor * ((20.0)) ) * pow(sqrt(dot(color.rgb,color.rgb)), 1.0) * emissive;

	return emissiveMap;
}

#ifdef DYNAMIC_HANDLIGHT
	float getHandItemLightFactor(vec3 fragpos, vec3 normal){
		float handItemLightFactor = length(fragpos.xyz);
			handItemLightFactor = 1.0 - handItemLightFactor / 25.0;
			handItemLightFactor = smoothstep(0.5, 1.1, handItemLightFactor);
		
			handItemLightFactor = getEmissiveLightmap(vec4(handItemLightFactor), true);
			
			handItemLightFactor *= pow(clamp(mix(1.0, max(dot(-fragpos.xyz,normal),0.0), normalize(handItemLightFactor)), 0.0, 1.0), 2.0) * 1.6;
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
    
    float a = .285 / (r+.57) + .5;
    float b = .45 * r / (r+.09);

    return max(0., NdotL) * ( b * c + a);

}

float shadowStep(sampler2D shadow, vec3 sPos) {
	return clamp(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).x, 0.0) * float(shadowMapResolution), 0.0, 1.0);
}

#include "lib/nightDesat.glsl"
#include "lib/noise.glsl"
#include "lib/shadowPos.glsl"
#include "lib/shadows.glsl"
#include "lib/shadingForward.glsl"
#include "lib/gaux2Forward.glsl"
#include "lib/phases.glsl"
#include "lib/skyGradient.glsl"
#include "lib/calcClouds.glsl"
#include "lib/calcStars.glsl"

float getSubSurfaceScattering(){
	float cosV = pow(clamp(dot(uPos.xyz, lightVector), 0.0, 1.0), 10.0) * 4.0;
		  cosV /= cosV * 0.01 + 1.0;

	return clamp(cosV, 0.0, 90.0);
}

const vec2 biliteralOffets[4] = vec2[4] (
	vec2(1.0, 0.0),
	vec2(0.0, 1.0),
	vec2(-1.0, 0.0),
	vec2(0.0, -1.0)
);

vec3 bilateralUpsampling(vec2 uv){
	const float lod = 1.75;

	vec3 result = vec3(0.0);
	vec2 coord = vec2(0.0);
	float totalWeight = 0.0;

	for (int i = 0; i < 4; i++){
		vec2 offset = biliteralOffets[i] * 5.0;
		coord = uv + offset / viewWidth;

		vec3 offsetNormal = texture2D(gnormal, coord).rgb * 2.0 - 1.0;
		float normalWeight = pow(abs(dot(offsetNormal, normal)), 32.0);

		float offsetDepth = ld(texture2D(depthtex1, coord).r);
		float depthWeight = 1.0 / (0.0001 + abs(ld(pixeldepth2) - offsetDepth));

		float weight = normalWeight * depthWeight;

		float sampleR = texture2D(gcolor, coord, lod).a;
		float sampleG = texture2D(gdepth, coord, lod).a;
		float sampleB = texture2D(composite, coord, lod).a ;

		result += vec3(sampleR, sampleG, sampleB) * weight;

		totalWeight += weight;
	}

	result /= totalWeight;

	return max(result, 0.0);
}

#ifdef GLOBAL_ILLUMINATION
	vec3 getGlobalIllumination(vec2 uv){

		vec3 globalIllumination = bilateralUpsampling(uv);
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

	vec3 emissiveLightmap = emissiveLM * emissiveLightColor;
		emissiveLightmap = getEmessiveGlow(color,emissiveLightmap, emissiveLightmap, emissive);

	float lightAbsorption = smoothstep(-0.1, 0.5, dot(upVec, sunVec));

	vec3 lightCol = mix(sunlight * lightAbsorption, moonlight, time[1].y) * max(dynamicCloudCoverage * 2.4 - 1.4, 0.0);

	vec3 sunlightDirect = (lightCol * sunlightAmount);
	vec3 indirectLight = mix(ambientlight, lightCol * lightAbsorption, mix(mix(mix(0.2, 0.0, rainStrength),0.0,time[1].y), 0.0, 1.0 - skyLightMap)) * (0.2 * skyLightMap * shadowDarkness) + (minLight * (1.0 - skyLightMap));
	
	vec3 globalIllumination = vec3(0.0);
	
	#ifdef GLOBAL_ILLUMINATION
		globalIllumination = (getGlobalIllumination(texcoord.st) * GI_MULT * 2.0) * (lightCol * transition_fading) * (1.0 - rainStrength);
	#endif

	return ((sunlightDirect * (shadows * diffuse) * (1.0 + (getSubSurfaceScattering() * translucent))) + indirectLight) + globalIllumination + emissiveLightmap;
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

			float diffthresh = 0.0005;	// Fixes light leakage from walls
			
			vec3 worldposition = vec3(0.0);

			for (minDist; minDist < maxDist; ) {

				//MAKING VL NOT GO THROUGH WALLS
				if (getDepth(pixeldepth) < minDist){
					break;
				}

				//Getting worldpositon
				worldposition = toShadowSpace(toScreenSpace(vec3(texcoord.st, expDepth(minDist))));

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

vec4 mod289(vec4 x){return x - floor(x * 0.003460) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise3D(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.z;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * 0.02439024390243902439024390243902);
    vec4 o2 = fract(k4 * 0.02439024390243902439024390243902);

    vec4 o3 = (o2 * d.z) + (o1 * (1.0 - d.z));
    vec2 o4 = (o3.yw * d.x) + (o3.xz * (1.0 - d.x));

    return (o4.y * d.y) + (o4.x * (1.0 - d.y));
}

float getVolumetricCloudNoise(vec3 p){

	float wind = abs(frameTimeCounter - 0.5);

	p.xz += wind;
	
	p *= 0.02;

	float noise = noise3D(vec3(p.x - wind * 0.01, p.y, p.z - wind * 0.015));
		  noise += noise3D(p * 3.5) * 0.28571428571428571428571428571429;
		  noise += abs(noise3D(p * 6.125) * 2.0 - 1.0) * 0.16326530612244897959183673469388;
		  noise += abs(noise3D(p * 12.25) * 2.0 - 1.0) * 0.08163265306122448979591836734694;

		  noise = noise * (1.0 - rainStrength * 0.5);
		  noise = pow(max(1.0 - noise * 1.5 * dynamicCloudCoverageMult,0.),2.0) * 0.0303030;

	return clamp(noise * 10.0, 0.0, 1.0);
}

vec3 getVolumetricCloudPosition(float depth, float cloudDistance)
{
	vec3 position = toScreenSpace(vec3(texcoord.st, expDepth(depth)));
	     position = getWorldSpace(vec4(position, 0.0)).rgb;

		 position.rgb *= cloudDistance;

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
		float cloudTreshHold = pow(1.0f - clamp(distance(wpos.y, height) / (distRatio / 2.0f), 0.0f, 1.0f), 12.0);

		cloudAlpha *= cloudTreshHold;

		float absorption = clamp((-(minHeight - wpos.y) / distRatio), 0.0f, 1.0f);

		float sunLightAbsorption = pow(absorption, 3.25) * dynamicCloudCoverage;

		vec3 dayTimeColor = sunlight * 16.0 * sunUpCos;
			 dayTimeColor += sunlight*sunlight * sunViewCos * 64.0 * sqrt(sunLightAbsorption) * sunUpCos;

		vec3 nightTimeColor = moonlight * 16.0 * MoonUpCos;
			 nightTimeColor += moonlight * moonViewCos * 8.0 * sqrt(sunLightAbsorption) * MoonUpCos;

		vec3 rainColor = ambientlight;
			 rainColor += (ambientlight * 64.0) * (sunLightAbsorption * (sqrt(sunUpCos) * 0.9 + 0.1));

		vec3 totalCloudColor = (dayTimeColor + nightTimeColor) * sunLightAbsorption;
			 totalCloudColor = mix(totalCloudColor, rainColor, rainStrength);

		vec3 cloudColor = mix(totalCloudColor, ambientlight * (0.25 + rainStrength) * dynamicCloudCoverage, pow(1.0 - absorption / 2.8, 4.0f)) * 0.5;

		return vec4(cloudColor, cloudAlpha);
	}
}

vec4 getVolumetricClouds(vec3 color){

	float cloudDistance = 160.0 / far;

	vec4 clouds = vec4(pow(color, vec3(2.2)), 0.0);

	float nearPlane = 2.0;			//start to where the ray should march.
	float farPlane = far; 		//End from where the ray should march.

    float increment = far / (13.0 * max(VOLUMETRIC_CLOUDS_QUALITY, 0.000001));		//Max the quality to prevent deviding by 0

	farPlane += dither * increment;

	vec3 fixedWorldPosition = mix(worldPosition2, worldPosition, iswater * (1.0 - isEyeInWater));
	float worldPositionDistance = length(fixedWorldPosition);

	while (farPlane > nearPlane){

		vec3 wpos = getVolumetricCloudPosition(farPlane, cloudDistance);

		float volumetricDistance = length(wpos - cameraPosition.xyz);

		if (worldPositionDistance < volumetricDistance && land2 > 0.0){
			clouds.a = 0.0;
		} else {

			vec4 result = getVolumetricCloudsColor(wpos);
				result.a = clamp(result.a * VOLUMETRIC_CLOUDS_DENSITY, 0.0, 1.0);

			if (worldPositionDistance < volumetricDistance){
				result.rgb = renderGaux2(result.rgb, normal2);
			}

			clouds.rgb = mix(clouds.rgb, result.rgb, min(result.a * VOLUMETRIC_CLOUDS_DENSITY, 1.0));
			clouds.a += result.a * VOLUMETRIC_CLOUDS_DENSITY;
		}

		farPlane -= increment;
	}

	return clamp(clouds, 0.0, 1.0);
}

#endif

void main()
{
	color = getDesaturation(pow(color, vec3(2.2)), min(emissiveLM, 1.0));

	vec3 sunMult = vec3(0.0);
	vec3 moonMult = vec3(0.0);

	if (land > 0.9)
		color = getShading(color) * color;
	else {

		//color = pow(color, vec3(2.2)); // Uncomment this line to get minecraft's default sky. And comment the line under to get minecraft's default sky.
		
		color = pow(getAtmosphericScattering(vec3(0.0), fragpos2.rgb, 1.0, ambientlight, sunMult, moonMult), vec3(2.2));

		#ifdef STARS
			color = getStars(color, fragpos2.rgb, land);
		#endif
		
		#ifdef CLOUD_PLANE_2D
			color = getClouds(color, fragpos2.rgb, land);
		#endif
	}
	
	color = renderGaux2(color, normal2);

	color = pow(color, vec3(0.4545));

	#ifdef VOLUMETRIC_CLOUDS
		vec4 VolumetricClouds = getVolumetricClouds(color);
	#endif
	
/* DRAWBUFFERS:015 */
	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE, getVolumetricRays());
	gl_FragData[1] = vec4(vec3(forWardAlbedo.a, aux2.gb), shadowsForward);

	#ifdef VOLUMETRIC_CLOUDS
		gl_FragData[2] = vec4(VolumetricClouds) / MAX_COLOR_RANGE;
	#endif
}
