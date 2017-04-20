#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "lib/colorRange.glsl"
#include "lib/options.glsl"

#define WATER_REFRACT
	#define WATER_REFRACT_MULT 1.0 //[0.5 1.0 1.5 2.0]
	#define WATER_REFRACT_DISPERSION //Makes the primary wavelength split up (RGB)

#define FOG
	#define FOG_DENSITY_DAY		1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
	#define FOG_DENSITY_NIGHT	1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
	#define FOG_DENSITY_STORM	1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
	#define NO_UNDERGROUND_FOG

#define REFLECTIONS 														//All the reflections. including water, rain and specular.
	#define REFLECTION_STRENGTH 0.75 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define WATER_REFLECTION
#define RAIN_REFLECTION

#define WATER_DEPTH_FOG
	#define DEPTH_FOG_DENSITY 0.2 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
	
#define UNDERWATER_FOG
	#define UNDERWATER_DENSITY 0.2 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.

const bool gcolorMipmapEnabled = true;
const bool gaux2MipmapEnabled = true;

//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.5;			//size of one step for raytracing algorithm
const float ref = 0.025;		//refinement multiplier
const float inc = 2.2;			//increasement factor at each step

varying vec4 texcoord;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 moonlight;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D composite;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform float wetness;

uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;
uniform int worldTime;

uniform float far;
uniform float near;

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

vec4 aux = texture2D(gaux1, texcoord.st);
vec4 aux2 = texture2D(gdepth, texcoord.st);

float emissive = float(aux.g > 0.34 && aux.g < 0.36);

float iswater = float(aux2.g > 0.12 && aux2.g < 0.28);
float istransparent = float(aux2.g > 0.28 && aux2.g < 0.32);
float hand = float(aux2.g > 0.85 && aux2.g < 0.87);
float translucent = 0.0;

vec3 normal = mix(texture2D(gnormal, texcoord.st, 2.0).rgb * 2.0 - 1.0, texture2D(composite, texcoord.st).rgb * 2.0 - 1.0, iswater + istransparent + hand);

float getEyeBrightnessSmooth = pow(clamp(eyeBrightnessSmooth.y / 220.0f,0.0,1.0), 3.0f);

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec4 getFragpos(vec2 pos, float depth){

	vec4 fragpos = gbufferProjectionInverse * vec4(vec3(pos.st, depth) * 2.0 - 1.0, 1.0);
	return (fragpos / fragpos.w);
}

vec4 fragpos = getFragpos(texcoord.st, pixeldepth);
vec4 uPos = normalize(fragpos);

vec4 getFragpos2(vec2 pos, float depth){

	vec4 fragpos = gbufferProjectionInverse * vec4(vec3(pos.st, depth) * 2.0 - 1.0, 1.0);
	return (fragpos / fragpos.w);
}

vec4 fragpos2 = getFragpos2(texcoord.st, pixeldepth2);

vec4 getWorldSpace(vec4 fragpos){

	return gbufferModelViewInverse * fragpos;
}

vec3 worldPosition = getWorldSpace(fragpos).rgb;

float cdist(vec2 coord) {
	return max(abs(coord.x-0.5),abs(coord.y-0.5))*2.0;
}

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float expDepth(float dist){
	return (far * (dist - near)) / (dist * (far - near));
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

#include "lib/noise.glsl"
#include "lib/waterBump.glsl"
#include "lib/skyGradient.glsl"
#include "lib/calcClouds.glsl"
#include "lib/calcStars.glsl"

#ifdef RAIN_PUDDLES
	#include "lib/rainPuddles.glsl"
#endif

vec3 shadows = vec3(aux2.a);

float refractmask(vec2 coord){

	float mask = texture2D(gdepth, coord.st).g;

	if (iswater > 0.9){
		mask = float(mask > 0.12 && mask < 0.28);
	}

	if (istransparent > 0.9){
		mask = float(mask > 0.28 && mask < 0.32);
	}

	return mask;

}

#ifdef WATER_REFRACT

	vec2 clampScreen(vec2 coord) {

		vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

		return clamp(coord, pixel, 1.0 - pixel);
	}

	void getRefractionCoord(vec3 wpos, vec2 texPosition, out vec3 refraction, out vec2 refractCoord0, out vec2 refractCoord1, out vec2 refractCoord2, out vec3 refractMask){
		wpos.rgb += cameraPosition.rgb;

		vec2 posxz = (wpos.xz - wpos.y);
		
		vec2 refractionMult = vec2(0.0); //.x = dispersionMult and ,y = the actual refractionMult

		float normalDotEye = dot(normal, uPos.rgb);
		refractionMult.x = clamp(1.0 + normalDotEye, 0.0, 1.0);
		refractionMult.x *= refractionMult.x;

		#ifdef WATER_REFRACT_DISPERSION
			float dispersion = 0.3 * refractionMult.x;
		#else
			float dispersion = 0.0;
		#endif

		refraction = getWaveHeight(posxz, iswater);

			vec2 depth = vec2(0.0);
			depth.x = getDepth(pixeldepth2);
			depth.y = getDepth(pixeldepth);

			refractionMult.y = clamp(depth.x - depth.y,0.0,1.0);
			refractionMult.y /= depth.y;
			refractionMult.y *= WATER_REFRACT_MULT * 0.2;
			refractionMult.y *= mix(0.3,1.0,iswater);

		dispersion *= refractionMult.y;

		texPosition = (texPosition * 2.0 - 1.0) * 0.5 + 0.5;

		refractCoord0 = texPosition + (refraction.xy * refractionMult.y);
		refractCoord1 = texPosition + (refraction.xy * (refractionMult.y + dispersion));
		refractCoord2 = texPosition + (refraction.xy * (refractionMult.y + dispersion * 2.0));

		refractCoord0 = clampScreen(refractCoord0);
		refractCoord1 = clampScreen(refractCoord1);
		refractCoord2 = clampScreen(refractCoord2);

		refraction.xy *= refractionMult.y;
		
		refractMask = vec3(refractmask(refractCoord0),
						   refractmask(refractCoord1),
						   refractmask(refractCoord2));
	}

#endif

vec2 getRefractionTexcoord(vec3 wpos, vec2 texPosition){

	vec3 refraction = vec3(0.0);

	vec2 refractCoord0 = vec2(0.0);
	vec2 refractCoord1 = vec2(0.0);
	vec2 refractCoord2 = vec2(0.0);

	vec3 refractMask = vec3(0.0);

	vec2 texCoord = texPosition;

	#ifdef WATER_REFRACT
		getRefractionCoord(wpos, texPosition, refraction, refractCoord0, refractCoord1, refractCoord2, refractMask);

		texCoord = mix(texCoord, refractCoord2, refractMask.z);
		texCoord = mix(texCoord, refractCoord1, refractMask.y);
		texCoord = mix(texCoord, refractCoord0, refractMask.x);
	#endif

	return mix(texPosition, texCoord, iswater + istransparent);

}

#ifdef WATER_REFRACT

	vec3 waterRefraction(vec3 color, vec3 wpos, vec2 texPosition) {

		vec3 refraction = vec3(0.0);

		vec2 refractCoord0 = vec2(0.0);
		vec2 refractCoord1 = vec2(0.0);
		vec2 refractCoord2 = vec2(0.0);

		vec3 refractMask = vec3(0.0);

		getRefractionCoord(wpos, texPosition, refraction, refractCoord0, refractCoord1, refractCoord2, refractMask);

		vec3 rA;
			rA.x = texture2D(gcolor, (refractCoord0)).x * MAX_COLOR_RANGE;
			rA.y = texture2D(gcolor, (refractCoord1)).y * MAX_COLOR_RANGE;
			rA.z = texture2D(gcolor, (refractCoord2)).z * MAX_COLOR_RANGE;

		rA = pow(rA, vec3(2.2));

		refraction.r = bool(refractMask.x) ? rA.r : color.r;
		refraction.g = bool(refractMask.y) ? rA.g : color.g;
		refraction.b = bool(refractMask.z) ? rA.b : color.b;

		if (iswater > 0.9 || istransparent > 0.9)	color = refraction;

		return color;
	}

#endif

vec2 refTexC = getRefractionTexcoord(worldPosition, texcoord.st).st;

float pixeldepthRef = texture2D(gdepthtex, refTexC.st).x;
float pixeldepthRef2 = texture2D(depthtex1, refTexC.st).x;

#ifdef SPECULAR_MAPPING
	vec3 specular = texture2D(gaux3, refTexC.st).rgb;
#endif

float land = float(pixeldepthRef < comp);
float land2 = float(pixeldepthRef2 < comp);

vec4 fragposRef = getFragpos(refTexC.st, pixeldepthRef);
vec4 fragposRef2 = getFragpos2(refTexC.st, pixeldepthRef2);

#if defined WATER_CAUSTICS && !defined PROJECTED_CAUSTICS
		#include "lib/caustics.glsl"
#endif

#ifdef FOG
	vec3 getFog(vec3 fogColor, vec3 color, vec2 pos, float land){

		color = pow(color, vec3(2.2));

		vec3 fragposFog = vec3(pos.st, texture2D(gdepthtex, pos.st).r);
		fragposFog = nvec3(gbufferProjectionInverse * nvec4(fragposFog * 2.0 - 1.0));
		
		float cosSunUpAngle = dot(sunVec, upVec) * 0.95 + 0.05; //Has a lower offset making it scatter when sun is below the horizon.
		float cosMoonUpAngle = clamp(pow(1.0-cosSunUpAngle,35.0),0.0,1.0);
		
		#ifdef NO_UNDERGROUND_FOG
			float fogAdaption =  clamp(getEyeBrightnessSmooth, 0.0,1.0);
		#else
			float fogAdaption = 1.0;
		#endif

		float fog = 1.0 - exp(-pow(sqrt(dot(fragposFog,fragposFog))
		* mix(
		mix(1.0 / 1200.0 * FOG_DENSITY_DAY, 1.0 / 120.0 * FOG_DENSITY_NIGHT,1.0 * cosMoonUpAngle),
		1.0 / 200.0 * FOG_DENSITY_STORM, rainStrength) * fogAdaption,2.0));
		
		fog = clamp(fog, 0.0, 1.0);

		vec3 lightCol = mix(sunlight, moonlight, time[1].y * transition_fading);

		float sunMoonScatter = pow(clamp(dot(normalize(fragposFog), lightVector),0.0,1.0),2.0) * transition_fading;

		fogColor *= mix(1.0, 0.5, (1.0 - min(time[1].y + rainStrength + time[0].y, 1.0)));
		fogColor = fogColor * mix(mix(0.5, 1.0, rainStrength), 1.0, cosMoonUpAngle);
		fogColor = mix(fogColor, lightCol * 2.0, sunMoonScatter / 4.0 * (1.0 - rainStrength) * (1.0 - time[1].y));
		fogColor = mix(fogColor, lightCol, 0.05 * (1.0 - rainStrength) * (1.0 - time[1].y));
		
		fogColor = fogColor * mix((1.0 - (1.0 - transition_fading) * (1.0 - rainStrength) * 0.97), 1.0, time[1].y);
		fogColor = pow(fogColor, vec3(2.2));
		fogColor = mix(mix(fogColor * 0.25, fogColor, rainStrength), fogColor, pow(cosMoonUpAngle, 5.0) * time[1].y);
		
		float rawHeight = getWorldSpace(vec4(fragposFog, 1.0)).y + cameraPosition.y;

		float getHeight = clamp(pow(1.0 - (rawHeight - 90.0) / 100.0, 4.4),0.0,1.0) * 3.0 + 0.05;

		color = mix(color, fogColor, clamp(fog * land * rainStrength * (1.0 - isEyeInWater), 0.0, 1.0));
		color = mix(color, fogColor, clamp(fog * land * (1.0 - rainStrength) * getHeight * (1.0 - isEyeInWater) * (1.0 - time[1].y), 0.0, 1.0));

		getHeight = clamp(pow(1.0 - ((rawHeight - 70.0) / 100.0), 4.4),0.0,1.0) + 0.05;

		color = mix(color, fogColor * 0.25, clamp(fog * land * (1.0 - rainStrength) * getHeight * (1.0 - isEyeInWater) * time[1].y * 0.9, 0.0, 1.0));

		return pow(max(color, 0.0), vec3(0.4545));
	}
#endif

#ifdef VOLUMETRIC_LIGHT

	vec3 getVolumetricLight(vec3 color, vec2 pos){

		float volumetricLightSample = 0.0;
		float vlWeight = 0.0;

		float depth = ld(pixeldepth);
		
		float noise = fract(sin(dot(texcoord.xy, vec2(18.9898f, 28.633f))) * 4378.5453f) * 4.0 / VL_QUALITY;
		mat2 noiseM = mat2(cos(noise), -sin(noise),
						   sin(noise), cos(noise));

		for (float i = -1.0; i < 1.0; i++){
			for (float j = -1.0; j < 1.0; j++){

				vec2 offset = vec2(i,j) / vec2(viewWidth, viewHeight) * noiseM;

				float depth2 = ld(texture2D(gdepthtex, pos.st + offset * 8.0).x);

				float weight = pow(1.0 - abs(depth - depth2) * 10.0, 32.0);
					weight = max(0.1e-8, weight);

				volumetricLightSample += texture2DLod(gcolor, pos.xy + offset * 2.0, 1.5).a * weight;

				vlWeight += weight;
			}
		}

		volumetricLightSample /= vlWeight;

		//volumetricLightSample = texture2D(gcolor, pos.xy).a;

		float sunAngleCosine = clamp(dot(uPos.rgb, lightVector), 0.0, 1.0);
		 //Inverse Square Root
		      sunAngleCosine = (0.5 / sqrt(-sunAngleCosine + 1.0)) - 0.5;
		  //Reinhard to prevent over exposure
		      sunAngleCosine /= 1.0 + sunAngleCosine * 0.5; 

		float vlMult = 1.0;
			vlMult = vlMult + (1.0 - getEyeBrightnessSmooth) * 4.0;
			vlMult *= 1.0 + isEyeInWater;
			vlMult *= 0.75 * 0.5;
			
		#if !defined PROJECTED_CAUSTICS || !defined WATER_CAUSTICS
			vlMult *= 1.0 - isEyeInWater;
		#endif

		vec3 lightCol = mix(sunlight, moonlight * 0.75, time[1].y);
			 lightCol = mix(mix(mix(mix(lightCol, ambientlight, 0.7) * 0.5, lightCol * 0.5, clamp(sunAngleCosine, 0.0, 1.0)), lightCol, clamp(time[1].y,0.0,1.0)), lightCol, 1.0 - getEyeBrightnessSmooth);
			 lightCol *= 1.0 + sunAngleCosine * mix(4.0, 2.0, time[1].y);
			 lightCol *= (1.0 + clamp(time[1].y * transition_fading * 0.5 + mix(0.0,1.0 - transition_fading, time[0].x),0.0,1.0)) * 0.5;
			 lightCol = mix(lightCol, vec3(0.1, 0.5, 0.8) * lightCol, isEyeInWater);
			
			 lightCol = lightCol * VL_INTENSITY;
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_SUNRISE, time[0].x);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_NOON, time[0].y);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_SUNSET, time[1].x);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_MIDNIGHT, time[1].y);
			
		volumetricLightSample *= vlMult;
		volumetricLightSample *= mix(0.1 * 0.2, 1.0, clamp(time[1].y,0.0,1.0));

		return pow(mix(pow(color, vec3(2.2)), pow(lightCol, vec3(2.2)), (volumetricLightSample * transition_fading) * (1.0 - rainStrength)), vec3(0.4545));
	}

#endif

vec3 renderGaux4(vec3 color){
	vec4 albedo = pow(texture2D(gaux4, texcoord.st), vec4(2.2));


	return mix(color, albedo.rgb * sqrt(color), albedo.a);
}

#if defined WATER_DEPTH_FOG && defined UNDERWATER_FOG
	float getWaterDepth(vec3 fragpos, vec3 fragpos2){
		return distance(fragpos, fragpos2);
	}
#endif

float getWaterScattering(float NdotL){
	const float wrap = 0.1;
	const float scatterWidth = 0.5;
	
	float NdotLWrap = (NdotL + wrap) / (1.0 + wrap);
	return smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);
}

#ifdef WATER_DEPTH_FOG

	vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2){

		vec3 lightCol = mix(sunlight, pow(moonlight, vec3(0.4545)), time[1].y);

		float depth = getWaterDepth(fragpos, fragpos2); // Depth of the water volume
			  depth *= iswater;
			  depth *= (1.0 - isEyeInWater);

		float depthFog = 1.0 - clamp(exp2(-depth * DEPTH_FOG_DENSITY), 0.0, 1.0); // Beer's Law

		float sunAngleCosine = pow(clamp(dot(normalize(fragpos.rgb), lightVector), 0.0, 1.0), 8.0);
		float NdotL = dot(normal, lightVector);
		float SSS = pow(getWaterScattering(NdotL), 2.0);

		vec3 fogColor = (ambientlight * lightCol) * 0.0333;
			 fogColor = (fogColor * (pow(aux2.b, skyLightAtten) + 0.25)) * 0.75;
			 fogColor = mix(fogColor, (fogColor * lightCol) * 3.75, SSS * (1.0 - rainStrength) * shadows);
			 fogColor = mix(fogColor, (fogColor * lightCol) * 6.0,(sunAngleCosine * shadows) * (transition_fading * (1.0 - pow(max(NdotL,0.0), 2.0))) * (1.0 - rainStrength));
			 fogColor = mix(fogColor, vec3(fogColor.r, fogColor.g * 1.1, fogColor.b * 1.05), (pow((1.0 - depthFog), 0.75) * (1.0 - rainStrength)) * 20.0);
			 
		color *= pow(vec3(0.1, 0.5, 0.8), vec3(depth) * 0.8);

		return mix(color, fogColor, depthFog);
	}
#endif

#ifdef UNDERWATER_FOG
	vec3 underwaterFog(vec3 color){

		float depth = getWaterDepth(fragpos.xyz * 0.25, vec3(0.0)) + 0.5; // Depth of the water volume
		float depthFog = 1.0 - clamp(exp2(-depth * UNDERWATER_DENSITY), 0.0, 1.0); // Beer's Law

		vec3 lightCol = mix(sunlight, vec3(1.0), time[1].y);

		vec3 fogColor = (ambientlight * lightCol) * 0.0333;
		     fogColor = mix(fogColor, vec3(fogColor.r, fogColor.g * 1.1, fogColor.b * 1.05), pow((1.0 - depthFog), 0.75) * 8.0 * (1.0 - rainStrength));

		color *= pow(vec3(0.1, 0.5, 0.8), vec3(depth) * 0.8);

		return mix(color,fogColor, depthFog);
	}
#endif

#ifdef REFLECTIONS

	vec3 getSpec(vec3 rvector, vec3 sunMult, vec3 moonMult){
		vec3 spec = calcSun(rvector, sunVec) * sunMult;
			spec += (calcMoon(rvector, moonVec) * moonMult) * pow(moonlight, vec3(0.4545));

		return spec;
	}
	
	vec4 raytrace(vec3 fragpos, vec3 rvector, float fresnel, vec3 fogColor) {
		#define fragdepth texture2D(depthtex1, pos.st).r

		bool land = false;
		float border = 0.0;
		vec3 pos = vec3(0.0);
	
		vec4 color = vec4(0.0);
		vec3 start = fragpos;
		vec3 vector = stp * rvector;
		vec3 oldpos = fragpos;

		fragpos += vector;
		vec3 tvector = vector;
		int sr = 0;


			for(int i=0;i<18;i++){
			pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;

			if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;

			vec3 spos = vec3(pos.st, fragdepth);
			     spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));

			float err = distance(fragpos.xyz, spos.xyz);
			
			if(err < pow(sqrt(dot(vector,vector))*pow(sqrt(dot(vector,vector)),0.11),1.1) * 1.1){

				sr++;
				
				if(sr >= maxf){
					color.a = 1.0;
					break;
				}

				tvector -=vector;
				vector *=ref;

	}
			vector *= inc;
			oldpos = fragpos;
			tvector += vector;
			fragpos = start + tvector;
		}

		border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);

		color.rgb = texture2D(gcolor, pos.st).rgb * MAX_COLOR_RANGE;
		color.rgb = pow(color.rgb, vec3(2.2));

		land = fragdepth < comp;

		#ifdef FOG
			color.rgb = getFog(ambientlight, color.rgb, pos.st, float(land));
		#endif

		color.rgb *= fresnel;
		
		color.rgb = land ? color.rgb : fogColor;
		color.a *= border;

		return color;
	}


	vec3 getSkyReflection(vec3 reflectedVector, out vec3 sunMult, out vec3 moonMult){
		vec3 sky = pow(getAtmosphericScattering(vec3(0.0), reflectedVector, 0.0, ambientlight, sunMult, moonMult), vec3(2.2));

		#ifdef STARS
			sky = getStars(sky, reflectedVector, 1.0 - land);
		#endif

		#ifdef CLOUDS
			sky = getClouds(sky, reflectedVector, 1.0 - land, 1);
		#endif

		return sky;
	}

	vec3 getReflection(vec3 color){

		vec3 uPos = normalize(fragpos.rgb);
		vec3 reflectedVector = reflect(uPos, normal);
		
		#ifdef SPECULAR_MAPPING
			float specMap = mix(specular.r, 0.0, iswater + istransparent + emissive);
		#else
			float specMap = 0.0;
		#endif	

		float iswet = smoothstep(0.8,0.9,aux.b * (1.0 - clamp(iswater + istransparent, 0.0 ,1.0))) * clamp(dot(upVec, normal),0.0,1.0);

		#ifdef RAIN_PUDDLES
			float puddles = getRainPuddles(worldPosition + cameraPosition) * (1.0 - clamp(iswater + istransparent, 0.0 ,1.0));
		#else
			float puddles = 1.0;
		#endif

		float F0 				= 0.05;
		vec3 halfVector = normalize(reflectedVector + normalize(-fragpos.rgb));
		float LdotH			= clamp(dot(reflectedVector, halfVector),0.0,1.0);
		float fresnel 	= F0 + (1.0 - F0) * pow(1.0 - LdotH, 5.0);

		vec3 sunMult = vec3(0.0);
		vec3 moonMult = vec3(0.0);
		
		float reflectionMask = clamp(iswater + istransparent, 0.0 ,1.0);

		vec3 sky = getSkyReflection(reflectedVector, sunMult, moonMult) * fresnel;
		sky += pow(getSpec(reflectedVector, sunMult, moonMult), vec3(2.2)) * shadows;

		vec4 reflection = raytrace(fragpos.rgb, reflectedVector, fresnel, sky);
		reflection.rgb = mix(sky * smoothstep(0.5,0.9,mix(aux.b, aux2.b, clamp(iswater + istransparent + hand, 0.0 ,1.0))), reflection.rgb, reflection.a);
		
		color.rgb += reflection.rgb * specMap * 0.5;
		
		reflection.rgb *= (1.0 - hand);
		
		#ifdef WATER_REFLECTION
			color.rgb += reflection.rgb * reflectionMask * (1.0 - isEyeInWater) * REFLECTION_STRENGTH * (1.0 - specMap);
		#endif
		
		reflection.rgb = reflection.rgb * wetness * 0.75 * iswet;
		
		#if defined RAIN_REFLECTION && defined RAIN_PUDDLES
			color.rgb *= mix(1.0,clamp(max(1.0 - puddles * 2.0,0.0) + 0.4,0.0,1.0), iswet * pow(fresnel, 0.3) * (1.0 - specMap) * wetness * (1.0 - hand));
			reflection.rgb = reflection.rgb * min(pow(puddles, 3.0),1.0);
		#endif

		#ifdef RAIN_REFLECTION
			color += reflection.rgb * (1.0 - reflectionMask);
		#endif

		return color;


	}
#endif

vec3 getVolumetricClouds(vec3 color, vec2 uv){

	float lod = 1.75;
	vec4 sample = texture2DLod(gaux2, uv, lod);

	return pow(mix(pow(color, vec3(2.2)), pow(sample.rgb, vec3(2.2)), sample.a), vec3(0.4545));

	//return vec3(sampleError);
}

void main()
{
	vec3 color = pow(texture2D(gcolor, texcoord.st).rgb * MAX_COLOR_RANGE, vec3(2.2));

	#ifdef WATER_REFRACT
		color = waterRefraction(color, worldPosition, texcoord.st);
	#endif
	
	#if defined WATER_CAUSTICS && !defined PROJECTED_CAUSTICS
			color = waterCaustics(color, fragposRef2);
	#endif

	#ifdef WATER_DEPTH_FOG
		color = getWaterDepthFog(color, fragposRef.rgb, fragposRef2.rgb);
	#endif

	#ifdef REFLECTIONS
		if (land > 0.9) color = getReflection(color);
	#endif

	#ifdef FOG
		if (land > 0.9) color = getFog(ambientlight, color, texcoord.st, land);
	#endif

	color = getVolumetricClouds(color, texcoord.st);

	#ifdef UNDERWATER_FOG
		if (isEyeInWater > 0.9) color = underwaterFog(color);
	#endif

	color = renderGaux4(color);

	#ifdef VOLUMETRIC_LIGHT
		color = getVolumetricLight(color, texcoord.st);
	#endif
	
	//color *= mix(vec3(1.0), vec3(100.0), pow(dot(color, vec3(0.33333)), 2.2));

	/*
		const vec2 Offsets[8] = vec2[8](
								vec2(1.0, 0.0),
								vec2(0.0, 1.0),
								vec2(-1.0, 0.0),
								vec2(0.0,-1.0),
								vec2(0.5, 0.5),
								vec2(-0.5, 0.5),
								vec2(0.5, -0.5),
								vec2(-0.5, -0.5));

	float ofsetDepth = 0.0;
	
	for (int i = 0; i < 8; i++){
		ofsetDepth += texture2D(gdepthtex, texcoord.st + vec2(Offsets[i].x / viewWidth, Offsets[i].y / viewHeight) * 50.0 * (1.0 - ld(pixeldepth))).x / 8.0;
	}

		float errorCheck = pow(pixeldepth, 1.0) - pow(ofsetDepth, 1.0);

		float aoMask = clamp(1.0 - clamp(abs(errorCheck * 2.0 - 1.0),0.0,1.0) * 1.0 - 0.005 * (1.0 - clamp(ld(pixeldepth) * 10000.0,0.0,1.0)), 0.0, 1.0);

		color *= 1.0 - clamp(vec3(errorCheck * 100.0 * (1.0 - min(aoMask * 10.0, 1.0))), 0.0, 1.0);
	*/
	
	color = pow(color, vec3(0.4545));

/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color / MAX_COLOR_RANGE, 1.0);
}
