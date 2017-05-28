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
const float		sunPathRotation				= -40.0; //[-50.0 -40.0 -30.0 -20.0 -10.0 0.01 10.0 20.0 30.0 40.0 50.0]

const float 	ambientOcclusionLevel 		= 1.0; //[0.0 0.25 0.5 0.75 1.0]

const float		eyeBrightnessHalflife		= 16.0; //[1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 16.0 18.0 20.0 24.0 28.0 32.0 ]

const int 		R11F_G11F_B10F				= 0;
const int 		RGBA16						= 0;
const int 		RGBA8						= 0;

const int 		gcolorFormat				= RGBA16;
const int 		gaux1Format					= RGBA16;
const int 		gaux2Format					= RGBA16;
const int 		gaux3Format					= R11F_G11F_B10F;
const int 		gaux4Format					= RGBA8;
const int 		gnormalFormat				= RGBA16;
const int 		compositeFormat				= RGBA16;

//-------------------------------------------------//

varying vec4 texcoord;

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

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;

uniform int isEyeInWater;
uniform int worldTime;

const float pi = 3.141592653589793238462643383279502884197169;

float comp = 1.0-near/far/far;

float timefract = worldTime;

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22000.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

#include "lib/lightColor.glsl"

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
	
	lightmap		= pow(lightmap, 2.0);
	lightmap 		= 1.0 / (1.0 - lightmap) - 1.0;
	lightmap 		= clamp(lightmap, 0.0, 100000.0) * 0.2484;
	
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

#include "lib/noise.glsl"
#include "lib/shadingForward.glsl"
#include "lib/gaux2Forward.glsl"

vec3 getShading(vec3 color){

	vec3 emissiveLightmap = emissiveLM * emissiveLightColor;
		emissiveLightmap = getEmessiveGlow(color,emissiveLightmap, emissiveLightmap, emissive);

	return MIN_LIGHT * ambientlight + emissiveLightmap;
}


void main()
{
	vec3 color = pow(texture2D(gcolor, texcoord.st).rgb, vec3(2.2));

	vec3 sunMult = vec3(0.0);
	vec3 moonMult = vec3(0.0);

	if (land > 0.9){
		color = getShading(color) * color;
	} else {
		color = vec3(0.0);
	}
	
	color = renderGaux2(color, normal2);

	color = pow(color, vec3(0.4545));
	
/* DRAWBUFFERS:015 */
	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE, 1.0);
	gl_FragData[1] = vec4(aux2.rgb, 1.0);
}
