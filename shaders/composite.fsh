#version 120

#include "lib/colorRange.glsl"

#define SHADOW_BIAS 0.85

#define DYNAMIC_HANDLIGHT

//-------------------------------------------------//

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.
#include "lib/options.glsl"

const float 	wetnessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]
const float 	drynessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]

const int 		noiseTextureResolution  	= 1024;

const bool 		shadowHardwareFiltering 	= true;
const float		sunPathRotation				= -40.0; //[-50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0]

const float 	ambientOcclusionLevel 		= 0.5; //[0.0 0.25 0.5 0.75 1.0]

const float		eyeBrightnessHalflife		= 7.0; //[1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0]

const int 		R11F_G11F_B10F				= 0;
const int 		RGBA16						= 0;
const int 		RGBA8						= 0;

const int 		gcolorFormat				= RGBA16;
const int 		gaux1Format					= RGBA16;
const int 		gaux2Format					= RGBA8;
const int 		gaux3Format					= R11F_G11F_B10F;
const int 		gaux4Format					= RGBA8;
const int 		gnormalFormat				= RGBA16;
const int 		compositeFormat				= RGBA16;

//-------------------------------------------------//

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 ambientColor;

varying vec3 moonlight;

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

uniform sampler2DShadow shadowtex1;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowcolor0;

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


vec3 ambientlight = mix(ambientColor, vec3(0.2) * (1.0 - time[1].y * 0.97), rainStrength);

float pixeldepth = texture2D(gdepthtex, texcoord.st).x;
float pixeldepth2 = texture2D(depthtex1, texcoord.st).x;

vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3 normal2 = texture2D(composite, texcoord.st).rgb * 2.0 - 1.0;

vec4 aux = texture2D(gaux1, texcoord.st);
vec4 aux2 = texture2D(gdepth, texcoord.st);

float land = float(pixeldepth2 < comp);
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
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
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

float getEmissiveLightmap(vec4 aux, bool isForwardRendered){

	float lightmap = aux.r;
	
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.5f;
	lightmap 		= 1.0 / pow((lightmap + 0.8f), 2.0);
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap		= (lightmap / 1.0) / (1.0 - lightmap);
	lightmap 		-= 0.03435f;
	lightmap 		= max(0.0f, lightmap);
	
	lightmap 		*= 0.08 * (1.0 + mix(dynamicExposure,1.0,time[1].y) / 0.08) * 0.23;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap , 4.0f) * 5.0 + lightmap;
	lightmap 		= pow(lightmap, emissiveLightAtten) * emissiveLightMult;
	
	lightmap		= isForwardRendered ? lightmap * (1.0 - emissive) + emissive : lightmap; //Prevent glowstone and all emissive stuff to clip with the lightmap
	lightmap		= isForwardRendered ? lightmap * (1.0 - handLightMult * hand) + handLightMult * hand : lightmap; //Also do this to the hand

	return lightmap;
}

float getSkyLightmap(){

	return pow(aux.z, skyLightAtten);
}

float getSkyLightmap2(){

	return pow(aux2.z, skyLightAtten);
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec4 getFragpos(){

	vec4 fragpos = gbufferProjectionInverse * vec4(vec3(texcoord.st, pixeldepth) * 2.0 - 1.0, 1.0);
	if (isEyeInWater > 0.9)
		fragpos.xy *= 0.817;

	return (fragpos / fragpos.w);
}

vec4 fragpos = getFragpos();

vec4 getFragpos2(){

	vec4 fragpos = gbufferProjectionInverse * vec4(vec3(texcoord.st, pixeldepth2) * 2.0 - 1.0, 1.0);
	if (isEyeInWater > 0.9)
		fragpos.xy *= 0.817;

	return (fragpos / fragpos.w);
}

vec4 fragpos2 = getFragpos2();

vec4 getWorldSpace(vec4 fragpos){

	return gbufferModelViewInverse * fragpos;
}

vec3 worldPosition = getWorldSpace(fragpos).rgb;

vec3 getEmessiveGlow(vec3 color, vec3 emissivetColor, vec3 emissiveMap, float emissive){

	emissiveMap += (emissivetColor * ((20.0)) ) * pow(sqrt(dot(color.rgb,color.rgb)), 1.0) * emissive;

	return emissiveMap;
}

#ifdef DYNAMIC_HANDLIGHT
	float getHandItemLightFactor(vec4 fragpos, vec3 normal){
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

#include "lib/noise.glsl"
#include "lib/shadowPos.glsl"
#include "lib/shadows.glsl"
#include "lib/nightDesat.glsl"
#include "lib/shadingForward.glsl"
#include "lib/gaux2Forward.glsl"
#include "lib/skyGradient.glsl"
#include "lib/calcClouds.glsl"
#include "lib/calcStars.glsl"

float getSubSurfaceScattering(){
	return (clamp(pow(dot(normalize(fragpos.rgb), lightVector), 12.0),0.0,1.0) * transition_fading) * 3.0;
}

vec3 shadows = getShadow(pixeldepth2, normal, 2.0, true, false);

vec3 getShading(vec3 color){

	float skyLightMap = getSkyLightmap();

	float diffuse = mix(OrenNayar(fragpos.rgb, lightVector, normal, 0.0), 1.0, translucent * 0.5) * ((1.0 - rainStrength) * transition_fading);
		  diffuse = diffuse * mix(1.0, skyLightMap * 0.9 + 0.1, isEyeInWater * (1.0 - iswater));
		  diffuse = clamp(diffuse*1.01-0.01, 0.0, 1.0);

	vec3 emissiveLightmap = emissiveLM * emissiveLightColor;
		emissiveLightmap = getEmessiveGlow(color,emissiveLightmap, emissiveLightmap, emissive);

	float lightAbsorption = smoothstep(-0.1, 0.5, dot(upVec, sunVec));

	vec3 lightCol = mix(sunlight * lightAbsorption, moonlight, time[1].y);

	vec3 sunlightDirect = (lightCol * sunlightAmount);
	vec3 indirectLight = mix(ambientlight, lightCol * lightAbsorption, mix(mix(mix(0.35, 0.0, rainStrength),0.0,time[1].y), 0.25, 1.0 - skyLightMap)) * (0.2 * skyLightMap * shadowDarkness) + (minLight * (1.0 - skyLightMap));

	return ((sunlightDirect * (shadows * diffuse) * (1.0 + (getSubSurfaceScattering() * translucent))) + indirectLight) + emissiveLightmap;
}

#ifdef VOLUMETRIC_LIGHT

	float getVolumetricRays() {

		///////////////////////Setting up functions///////////////////////
			
			vec3 rSD = vec3(0.0);
				rSD.x = 0.0;
				rSD.y = 4.0 / VL_QUALITY;
				rSD.z = bayer16x16(texcoord.st);
				
			
			rSD.z *= rSD.y;

			const int maxDist = int(VL_DISTANCE);
			float minDist = 0.01f;
				minDist += rSD.z;

			float weight = 128.0 / rSD.y;

			float diffthresh = 0.00005;	// Fixes light leakage from walls
			
			vec4 worldposition = vec4(0.0);

			for (minDist; minDist < maxDist; ) {

				//MAKING VL NOT GO THROUGH WALLS
				if (getDepth(pixeldepth) < minDist){
					break;
				}

				//Getting worldpositon
				worldposition = getShadowSpace(expDepth(minDist),texcoord.st);

				//Rescaling ShadowMaps
				worldposition = biasedShadows(worldposition);

				//Projecting shadowmaps on a linear depth plane
				#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
					float shadow0 = shadow2D(shadowtex0, vec3(worldposition.rg, worldposition.b + diffthresh )).z;
					float shadow1 = shadow2D(shadowtex1, vec3(worldposition.rg, worldposition.b + diffthresh )).z;
					float caustics = length(shadow2D(shadowcolor0, vec3(worldposition.rg, worldposition.b + diffthresh )).rgb * 10.0);

				rSD.x += mix(shadow0, shadow1, caustics);
				#else
					rSD.x += shadow2D(shadowtex1, vec3(worldposition.rg, worldposition.b + diffthresh )).z;
				#endif
				
				minDist = minDist + rSD.y;
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


void main()
{
	vec3 color = getDesaturation(pow(texture2D(gcolor, texcoord.st).rgb, vec3(2.2)), min(emissiveLM, 1.0));

	vec3 sunMult = vec3(0.0);
	vec3 moonMult = vec3(0.0);

	if (land > 0.9)
		color = getShading(color) * color;
	else {
		
		color = pow(getAtmosphericScattering(vec3(0.0), fragpos2.rgb, 1.0, ambientlight, sunMult, moonMult), vec3(2.2));

		#ifdef STARS
			color = getStars(color, fragpos2.rgb, land);
		#endif
		
		#ifdef CLOUDS
			color = getClouds(color, fragpos2.rgb, land, 3);
		#endif
	}
	
	color = renderGaux2(color, normal2);
	
	color = pow(color, vec3(0.4545));

/* DRAWBUFFERS:05 */
	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE, getVolumetricRays());
	gl_FragData[1] = vec4(shadowsForward, 1.0);
}
