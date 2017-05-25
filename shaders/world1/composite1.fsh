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
	#define REFLECTION_STRENGTH 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define WATER_REFLECTION
#define RAIN_REFLECTION

#define WATER_DEPTH_FOG
	#define DEPTH_FOG_DENSITY 0.2 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
	#define UNDERWATER_FOG

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.

const bool gcolorMipmapEnabled = true;
const bool gaux2MipmapEnabled = true;

//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.5;			//size of one step for raytracing algorithm
const float ref = 0.025;		//refinement multiplier
const float inc = 2.2;			//increasement factor at each step

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D composite;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float isEyeInWater;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;

const float pi = 3.141592653589793238462643383279502884197169;

float comp = 1.0-near/far/far;

#include "lib/lightColor.glsl"

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

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
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
vec3 uPos = normalize(fragpos.rgb);

vec3 fragpos2 = toScreenSpace(vec3(texcoord.st, pixeldepth));

vec4 getWorldSpace(vec4 fragpos){

	vec4 wpos = gbufferModelViewInverse * fragpos;

	return wpos;
}

vec3 worldPosition = getWorldSpace(vec4(fragpos, 0.0)).rgb;

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

#include "lib/noise.glsl"
#include "lib/waterBump.glsl"

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
			float dispersion = 0.6 * refractionMult.x;
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

vec3 fragposRef = toScreenSpace(vec3(texcoord.st, pixeldepthRef));
vec3 fragposRef2 = toScreenSpace(vec3(texcoord.st, pixeldepthRef2));

#ifdef FOG
	vec3 getFog(vec3 fogColor, vec3 color, vec2 pos){

		color = pow(color, vec3(2.2));

		vec3 fragposFog = toScreenSpace(vec3(pos, texture2D(gdepthtex, pos).x));

		float fog = 1.0 - exp(-pow(sqrt(dot(fragposFog,fragposFog)) * 0.001, 4.0));
			  fog = clamp(fog * 500.0, 0.0, 1.0);

		color = mix(color, fogColor, fog);

		return pow(max(color, 0.0), vec3(0.4545));
	}
#endif

#ifdef WATER_DEPTH_FOG

	float getWaterDepth(vec3 fragpos, vec3 fragpos2){
		return distance(fragpos, fragpos2);
	}

	vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2){

		float depth = getWaterDepth(fragpos, fragpos2); // Depth of the water volume
		depth *= mix(iswater, 1.0, isEyeInWater);

		float depthFog = 1.0 - clamp(exp2(-depth * DEPTH_FOG_DENSITY), 0.0, 1.0); // Beer's Law

		vec3 fogColor = ambientlight * 0.0333;
			 if (isEyeInWater < 0.9){
				fogColor = (fogColor * (pow(aux2.b, skyLightAtten) + 0.25)) * 0.75;
				}
			 
		color *= pow(ambientlight, vec3(depth) * 0.5);

		return mix(color, fogColor, depthFog);
	}
#endif

#ifdef REFLECTIONS
	
	vec4 raytrace(vec3 fragpos, vec3 rvector, vec3 fogColor) {
		#define fragdepth texture2D(depthtex1, pos.st).r

		float border = 0.0;
		vec3 pos = vec3(0.0);

		bool land = false;
	
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

		land = fragdepth < comp;

		color.rgb = texture2D(gcolor, pos.st).rgb * MAX_COLOR_RANGE;
		color.rgb = pow(color.rgb, vec3(2.2));

		#ifdef FOG
			color.rgb = getFog(fogColor, color.rgb, pos.st);
		#endif
		color.a *= border;

		return color;
	}

	vec3 getReflection(vec3 color, vec3 fogColor){

		vec3 reflectedVector = reflect(uPos.rgb, normal);
		
		#ifdef SPECULAR_MAPPING
			float specMap = mix(specular.r, 0.0,iswater + istransparent + emissive);
		#else
			float specMap = 0.0;
		#endif	
		
		float F0 				= 0.05;
		vec3 halfVector = normalize(reflectedVector + normalize(-fragpos.rgb));
		float LdotH			= clamp(dot(reflectedVector, halfVector),0.0,1.0);
		float fresnel 	= F0 + (1.0 - F0) * pow(1.0 - LdotH, 5.0);

		vec3 sunMult = vec3(0.0);
		vec3 moonMult = vec3(0.0);
		
		float reflectionMask = clamp(iswater + istransparent, 0.0 ,1.0);

		vec4 reflection = raytrace(fragpos.rgb, reflectedVector, fogColor);
		reflection.rgb = mix(pow(fogColor, vec3(0.4545)), reflection.rgb, reflection.a) * fresnel;
		
		color.rgb = mix(color.rgb, reflection.rgb, fresnel * specMap * 0.5);
		
		reflection.rgb *= (1.0 - hand);
		
		#ifdef WATER_REFLECTION
			color.rgb = mix(color, reflection.rgb, (fresnel * reflectionMask) * REFLECTION_STRENGTH * (1.0 - specMap));
		#endif

		return color;


	}
#endif

void main()
{
	vec3 color = pow(texture2D(gcolor, texcoord.st).rgb * MAX_COLOR_RANGE, vec3(2.2));

	#ifdef WATER_REFRACT
		color = waterRefraction(color, worldPosition, texcoord.st);
	#endif

	#ifdef WATER_DEPTH_FOG
		if (isEyeInWater < 0.9) color = getWaterDepthFog(color, fragposRef.rgb, fragposRef2.rgb);
	#endif

	vec3 fogColor = ambientlight * 0.001;

	#ifdef REFLECTIONS
		if (land > 0.9) color = getReflection(color, fogColor);
	#endif

	#ifdef FOG
		color = getFog(fogColor, color, texcoord.st);
	#endif

	#if defined UNDERWATER_FOG && defined WATER_DEPTH_FOG
		if (isEyeInWater > 0.9) color = getWaterDepthFog(color, fragposRef.rgb, vec3(0.0));
	#endif
	
	color = pow(color, vec3(0.4545));

/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color / MAX_COLOR_RANGE, 1.0);
}
