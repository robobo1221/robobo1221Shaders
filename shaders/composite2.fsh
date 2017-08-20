#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "lib/util/fastMath.glsl"

#include "lib/util/colorRange.glsl"
#include "lib/options/options.glsl"

#define WATER_REFRACT
	#define WATER_REFRACT_MULT 1.0 //[0.5 1.0 1.5 2.0]
	#define WATER_REFRACT_DISPERSION //Makes the primary wavelength split up (RGB)
	#define RAINPUDDLE_REFRACTION //Makes rain puddles refract light.

#define REFLECTIONS 														//All the reflections. including water, rain and specular.
	#define REFLECTION_STRENGTH 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define WATER_REFLECTION
#define RAIN_REFLECTION

const bool gcolorMipmapEnabled = true;
const bool gaux2MipmapEnabled = true;
const bool gaux3MipmapEnabled = true;

//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.5;			//size of one step for raytracing algorithm
const float ref = 0.025;		//refinement multiplier
const float inc = 2.2;			//increasement factor at each step

varying vec4 texcoord;

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
uniform int moonPhase;

uniform float far;
uniform float near;

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

//Unpack textures.
#ifdef SPECULAR_MAPPING
vec3 specular = 		texture2D(gaux3, texcoord.st).rgb;
#else
vec3 specular = 		vec3(0.0);
#endif

vec3 color = 			texture2D(gcolor, texcoord.st).rgb;
vec3 normals = 			texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3 compositeNormals = texture2D(composite, texcoord.st).rgb * 2.0 - 1.0;
vec4 aux = 				texture2D(gaux1, texcoord.st);
vec4 aux2 = 			texture2D(gdepth, texcoord.st);

float pixeldepth = 		texture2D(gdepthtex, texcoord.st).x;
float pixeldepth2 = 	texture2D(depthtex1, texcoord.st).x;

float emissive = 		float(aux.g > 0.34 && aux.g < 0.36);

float iswater =			float(aux2.g > 0.12 && aux2.g < 0.28);
float istransparent = 	float(aux2.g > 0.28 && aux2.g < 0.32);
float hand = 			float(aux2.g > 0.85 && aux2.g < 0.87);
float translucent = 	0.0;

float land =			float(pixeldepth < comp);
float land2 = 			float(pixeldepth2 < comp);

vec3 normal = 			mix(normals, compositeNormals, iswater + istransparent + hand);

float getEyeBrightnessSmooth = 1.0 - pow3(clamp(eyeBrightnessSmooth.y / 220.0f,0.0,1.0));

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

#include "lib/util/spaceConversions.glsl"

vec3 fragpos = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, pixeldepth));
vec3 uPos = fNormalize(fragpos.rgb);

vec3 fragpos2 = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, pixeldepth));

vec3 worldPosition = toWorldSpace(gbufferModelViewInverse, fragpos).rgb;

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

vec3 shadowsForward = vec3(aux2.a);

#include "lib/util/noise.glsl"
#include "lib/displacement/normalDisplacement/waterBump.glsl"
#include "lib/util/phases.glsl"
#include "lib/util/etc/cloudCoverage.glsl"
#include "lib/lightColor.glsl"
#include "lib/fragment/sky/skyGradient.glsl"
#include "lib/fragment/sky/calcClouds.glsl"
#include "lib/fragment/sky/calcStars.glsl"
#include "lib/fragment/waterFog.glsl"

#ifdef RAIN_PUDDLES
	#include "lib/fragment/rainPuddles.glsl"
	float puddles = getRainPuddles(worldPosition + cameraPosition) * (1.0 - clamp(iswater + istransparent, 0.0 ,1.0));
#else
	float puddles = 1.0;
#endif

#ifdef WATER_REFRACT

	vec2 clampScreen(vec2 coord) {

		vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

		return clamp(coord, pixel, 1.0 - pixel);
	}

	float refractmask(vec2 coord){

		float sample = texture2D(gdepth, coord.st).g;

		return mix(float(sample > 0.28 && sample < 0.32), float(sample > 0.12 && sample < 0.28), iswater);

	}

	void getRefractionCoord(vec3 wpos, vec2 texPosition, out vec3 refraction, out vec2 refractCoord0, out vec2 refractCoord1, out vec2 refractCoord2, out vec3 refractMask){
		wpos.rgb += cameraPosition.rgb;

		vec3 posxz = wpos;
		
		vec2 refractionMult = vec2(0.0); //.x = dispersionMult and ,y = the actual refractionMult

		float normalDotEye = dot(normal, uPos.rgb);
		refractionMult.x = clamp(normalDotEye + 1.0, 0.0, 1.0);
		refractionMult.x *= refractionMult.x;

		#ifdef WATER_REFRACT_DISPERSION
			float dispersion = 0.6 * refractionMult.x;
		#else
			float dispersion = 0.0;
		#endif

		refraction = getWaveHeight(posxz.xz - posxz.y, iswater);
		refraction = mix(refraction, vec3(0.0), (1.0 - (iswater + istransparent)));

			vec2 depth = vec2(0.0);
				 depth.x = getDepth(pixeldepth2);
				 depth.y = getDepth(pixeldepth);

			refractionMult.y = clamp(depth.x - depth.y,0.0,1.0);
			refractionMult.y /= depth.y;
			refractionMult.y *= WATER_REFRACT_MULT * 0.2;
			refractionMult.y *= mix(0.3,1.0,iswater);

		dispersion *= refractionMult.y;

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

		refractMask *= iswater + istransparent; 
	}

	vec3 refraction = vec3(0.0);

	vec2 refractCoord0 = vec2(0.0);
	vec2 refractCoord1 = vec2(0.0);
	vec2 refractCoord2 = vec2(0.0);

	vec3 refractMask = vec3(0.0);

#endif

vec2 getRefractionTexcoord(vec3 wpos, vec2 texPosition){

	vec2 texCoord = texPosition;

	#ifdef WATER_REFRACT
		getRefractionCoord(wpos, texPosition, refraction, refractCoord0, refractCoord1, refractCoord2, refractMask);

		texCoord = mix(texCoord, refractCoord2, refractMask.z);
	#endif

	return texCoord;

}

#ifdef WATER_REFRACT

	vec3 waterRefraction(vec3 color, vec3 wpos, vec2 texPosition) {

		getRefractionCoord(wpos, texPosition, refraction, refractCoord0, refractCoord1, refractCoord2, refractMask);

		vec3 rA;
			rA.x = texture2DLod(gcolor, refractCoord0, 0).x;
			rA.y = texture2DLod(gcolor, refractCoord1, 0).y;
			rA.z = texture2DLod(gcolor, refractCoord2, 0).z;

		rA = pow(rA * MAX_COLOR_RANGE, vec3(2.2));

		refraction.r = mix(color.r, rA.r, refractMask.x);
		refraction.g = mix(color.g, rA.g, refractMask.y);
		refraction.b = mix(color.b, rA.b, refractMask.z);

		color = refraction;

		return color;
	}

#endif

vec2 refTexC = getRefractionTexcoord(worldPosition, texcoord.st);

#ifdef FOG
	vec3 getFog(vec3 fogColor, vec3 color, vec2 uv){

		color = pow(color, vec3(2.2));

		vec3 fragpos = toScreenSpace(gbufferProjectionInverse, vec3(uv, texture2D(gdepthtex, uv).x));
		vec3 wpos = toWorldSpace(gbufferModelViewInverse, fragpos);
		
		float cosSunUpAngle = dot(sunVec, upVec) * 0.9 + 0.1; //Has a lower offset making it scatter when sun is below the horizon.
		float cosMoonUpAngle = clamp(pow35(1.0-cosSunUpAngle),0.0,1.0);
		
		#ifdef NO_UNDERGROUND_FOG
			float fogAdaption = clamp(1.0 - getEyeBrightnessSmooth, 0.0,1.0);
		#else
			float fogAdaption = 1.0;
		#endif

		dynamicCloudCoverage = sqrt(dynamicCloudCoverage);

		float fog = 1.0 - exp(-pow2(sqrt(dot(fragpos, fragpos))
		* mix(
		mix(1.0 / 1000.0 * FOG_DENSITY_DAY, 1.0 / 190.0 * FOG_DENSITY_NIGHT,1.0 * cosMoonUpAngle),
		1.0 / 200.0 * FOG_DENSITY_STORM, rainStrength + (1.0 - dynamicCloudCoverage)) * fogAdaption));
		
		fog = clamp(fog, 0.0, 1.0);

		vec3 lightCol = mix(sunlight, moonlight, time[1].y * transition_fading);

		float sunMoonScatter = pow2(clamp(dot(uPos, lightVector),0.0,1.0)) * transition_fading;

		fogColor *= mix(1.0, 0.5, (1.0 - min(time[1].y + rainStrength + time[0].y, 1.0)));
		fogColor = fogColor * mix(mix(0.5, 1.0, rainStrength), 1.0, cosMoonUpAngle);
		fogColor = mix(fogColor, lightCol * 2.0, sunMoonScatter * 0.25 * (1.0 - rainStrength) * (1.0 - time[1].y));
		fogColor = mix(fogColor, lightCol, 0.025 * (1.0 - rainStrength) * (1.0 - time[1].y));
		
		fogColor = fogColor * mix((1.0 - (1.0 - transition_fading) * (1.0 - rainStrength) * 0.97), 1.0, time[1].y);
		fogColor = pow(fogColor, vec3(2.2));
		fogColor = mix(mix(fogColor * 0.25, fogColor, rainStrength), fogColor, pow5(cosMoonUpAngle) * time[1].y);
		
		float rawHeight = wpos.y + cameraPosition.y;

		float getHeight = clamp(pow4(1.0 - (rawHeight - 90.0) * 0.01),0.0,1.0) * 3.0 + 0.05;

		color = mix(color, fogColor, clamp(fog * land * rainStrength * (1.0 - isEyeInWater), 0.0, 1.0));
		color = mix(color, fogColor, clamp(fog * land * (1.0 - rainStrength) * getHeight * (1.0 - isEyeInWater) * (1.0 - time[1].y), 0.0, 1.0));

		getHeight = clamp(pow4(1.0 - ((rawHeight - 70.0) * 0.01)),0.0,1.0) + 0.05;

		color = mix(color, fogColor * 0.25, clamp(fog * land * (1.0 - rainStrength) * getHeight * (1.0 - isEyeInWater) * time[1].y * 0.9, 0.0, 1.0));

		return pow(max(color, 0.0), vec3(0.4545));
	}
#endif

#ifdef VOLUMETRIC_LIGHT

	vec3 getVolumetricLight(vec3 color, vec2 pos){

		float volumetricLightSample = 0.0;
		float vlWeight = 0.0;

		float depth = ld(pixeldepth);

		for (float i = -1.0; i < 1.0; i++){
			for (float j = -1.0; j < 1.0; j++){

				vec2 offset = vec2(i,j) / vec2(viewWidth, viewHeight);

				float depth2 = ld(texture2D(gdepthtex, pos.st + offset * 8.0).x);

				float weight = pow(1.0 - abs(depth - depth2) * 10.0, 32.0);
					weight = max(0.1e-8, weight);

				volumetricLightSample = texture2DLod(gcolor, pos.xy + offset * 2.0, 1.5).a * weight + volumetricLightSample;

				vlWeight += weight;
			}
		}

		volumetricLightSample /= vlWeight;

		//volumetricLightSample = texture2D(gcolor, pos.xy).a;

		float sunViewCos = dot(lightVector, uPos.xyz) * 0.5 + 0.5;

		float mieFactor = min((0.5 / sqrt(1.0 - sunViewCos)) - 0.5, 100000.0);
			  mieFactor /= 1.0 + mieFactor; 

		float cosSunUpAngle = dot(sunVec, upVec) * 0.85 + 0.15; //Has a lower offset making it scatter when sun is below the horizon.
		float cosMoonUpAngle = clamp(pow35(1.0-cosSunUpAngle),0.0,1.0);

		float vlMult = 1.0;
			vlMult = vlMult + getEyeBrightnessSmooth * 4.0;
			vlMult *= 1.0 + isEyeInWater;
			vlMult *= 0.75 * 0.5;
			
		#if !defined PROJECTED_CAUSTICS || !defined WATER_CAUSTICS
			vlMult *= 1.0 - isEyeInWater;
		#endif

		vec3 lightCol = mix(sunlight, moonlight * 0.75, time[1].y);
			 lightCol = mix(mix(mix(mix(lightCol, ambientlight, 0.7) * 0.5, lightCol, mieFactor), lightCol, clamp(time[1].y,0.0,1.0)), lightCol, getEyeBrightnessSmooth);
			 lightCol *= 1.0 + mieFactor * mix(4.0, 2.0, time[1].y);
			 lightCol *= (1.0 + clamp(time[1].y * transition_fading * 0.5 + mix(0.0,1.0 - transition_fading, time[0].x),0.0,1.0)) * 0.5;
			 lightCol = mix(lightCol, vec3(0.1, 0.5, 0.8) * lightCol, isEyeInWater);
			
			 lightCol = lightCol * VL_INTENSITY;
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_SUNRISE, time[0].x);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_NOON, time[0].y);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_SUNSET, time[1].x);
			 lightCol = lightCol * mix(1.0,VL_INTENSITY_MIDNIGHT, time[1].y);
			 lightCol *= max(dynamicCloudCoverage * 2.4 - 1.4, 0.0);
			
		volumetricLightSample *= vlMult;
		volumetricLightSample *= mix(0.005, 0.125 * cosMoonUpAngle, clamp(time[1].y,0.0,1.0));

		return pow(mix(pow(color, vec3(2.2)), pow(lightCol, vec3(2.2)), (volumetricLightSample * transition_fading) * (1.0 - rainStrength)), vec3(0.4545));
	}

#endif

#ifdef VOLUMETRIC_CLOUDS
	vec3 getVolumetricClouds(vec3 color, vec2 uv){
		vec4 sample = texture2DLod(gaux2, uv, 1.7 / max(sqrt(VOLUMETRIC_CLOUDS_QUALITY), 0.000001)) * MAX_COLOR_RANGE;

		return mix(color, sample.rgb, clamp(sample.a, 0.0, 1.0));
	}
#endif

vec3 renderGaux4(vec3 color){
	float albedo = texture2DLod(gaux4, texcoord.st, 0).a;
	vec3 rainColor = vec3(2.0);

	return mix(color, rainColor * color, albedo * rainStrength);
}

#ifdef REFLECTIONS

	vec3 getSpec(vec3 rvector, vec3 sunMult, vec3 moonMult){
		vec3 spec = calcSun(rvector, sunVec) * sunMult * max(dynamicCloudCoverage * 2.4 - 1.4, 0.0);
			spec = (calcMoon(rvector, moonVec) * moonMult) * pow(moonlight, vec3(0.4545)) * max(dynamicCloudCoverage * 2.4 - 1.4, 0.0) + spec;

		return spec * shadowsForward;
	}
	
	vec4 raytrace(vec3 fragpos, vec3 rvector, float fresnel, vec3 fogColor) {
		#define fragdepth texture2D(depthtex1, pos.st).r
		vec3 pos = vec3(0.0);
	
		vec4 color = vec4(0.0);
		vec3 start = fragpos;
		vec3 vector = stp * rvector;
		vec3 oldpos = fragpos;

		fragpos += vector;
		vec3 tvector = vector;
		int sr = 0;


			for(int i=0;i<18;i++){
			pos = toClipSpace(gbufferProjection, fragpos);

			if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;

			vec3 spos = vec3(pos.st, fragdepth);
			     spos = toScreenSpace(gbufferProjectionInverse, spos);

			float err = distance(fragpos.xyz, spos.xyz);

			float vectorLength = sqrt(dot(vector, vector));
			
			if(err < pow(vectorLength * pow(vectorLength, 0.11), 1.1) * 1.1){

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

		float border = clamp(1.0 - pow10(cdist(pos.st)), 0.0, 1.0);

		color.rgb = texture2DLod(gcolor, pos.st, 0).rgb * MAX_COLOR_RANGE;
		color.rgb = pow(color.rgb, vec3(2.2));

		float land = float(fragdepth < comp);

		#ifdef FOG
			color.rgb = getFog(ambientlight, color.rgb, pos.st);
		#endif
		
		color.rgb = mix(fogColor, color.rgb, land);

		#ifdef VOLUMETRIC_CLOUDS
			color.rgb = getVolumetricClouds(color.rgb, pos.st);
		#endif
		
		color.a *= border;

		return color;
	}


	vec3 getSkyReflection(vec3 reflectedVector, out vec3 sunMult, out vec3 moonMult){
		vec3 sky = pow(getAtmosphericScattering(vec3(0.0), reflectedVector, 0.0, ambientlight, sunVec, moonVec, upVec, sunMult, moonMult), vec3(2.2));

		#ifdef STARS
			sky = getStars(sky, reflectedVector, 1.0 - land);
		#endif

		#ifdef CLOUD_PLANE_2D
			sky = getClouds(sky, reflectedVector, 1.0 - land);
		#endif

		return sky;
	}

	vec3 getPbrReflections(vec3 x, vec3 r, float f, vec3 s){	//x = color, r = reflection, f = fresnel, s = specular mask
		vec3 a = x / mix(vec3(1.0), moonlight * 2.0, time[1].y);
		
		float m = 1.0 - (iswater + istransparent);

		float roughness = s.r * 0.5;
		float metal = s.g * m;

		x = mix(x, r, f * m * roughness);

		float fr = mix(f, 1.0, metal * 0.8);
		vec3 ref = mix(r, r * a, metal);

		x = mix(x, vec3(0.0), metal);
		x = mix(x, ref, fr * m * metal);

		return x;
	}

	vec3 getReflection(vec3 color){

		vec3 reflectedVector = reflect(uPos, normal);

		float iswet = smoothstep(0.8,0.9,aux.b * (1.0 - clamp(iswater + istransparent, 0.0 ,1.0))) * clamp(dot(upVec, normal),0.0,1.0);

		float F0 = 0.02 * (isEyeInWater * 25.0 + 1.0); //Default minimum frensel for water.

		vec3 halfVector = fNormalize(reflectedVector + fNormalize(-fragpos.rgb));
		float LdotH	= clamp(dot(reflectedVector, halfVector),0.0,1.0);
		float fresnel = F0 + (1.0 - F0) * pow4(1.0 - LdotH);

		vec3 sunMult = vec3(0.0);
		vec3 moonMult = vec3(0.0);
		
		float reflectionMask = clamp(iswater + istransparent, 0.0 ,1.0);

		vec3 sky = getSkyReflection(reflectedVector, sunMult, moonMult);
		 	 sky = pow(getSpec(reflectedVector, sunMult, moonMult), vec3(2.2)) + sky;
			 sky = mix(sky, color, isEyeInWater);

		vec4 reflection = raytrace(fragpos.rgb, reflectedVector, fresnel, sky);
			 reflection.rgb = mix(sky * smoothstep(0.5,0.9,mix(aux.b, aux2.b, clamp(iswater + istransparent + hand, 0.0 ,1.0))), reflection.rgb, reflection.a);
		
		#ifdef SPECULAR_MAPPING
			color = getPbrReflections(color, reflection.rgb, fresnel, specular);
		#endif
		
		reflection.rgb *= (1.0 - hand);
		
		#ifdef WATER_REFLECTION
			color.rgb = mix(color, reflection.rgb, (fresnel * reflectionMask) * REFLECTION_STRENGTH);
		#endif
		
		#if defined RAIN_REFLECTION && defined RAIN_PUDDLES
			color.rgb *= mix(1.0,clamp(max(1.0 - puddles * 2.0,0.0) + 0.4,0.0,1.0), iswet * sqrt(sqrt(fresnel)) * (1.0 - specular.r) * wetness * (1.0 - hand));
		#endif

		#ifdef RAIN_REFLECTION
			color = mix(color, reflection.rgb, (1.0 - reflectionMask) * (wetness * 0.75) * (iswet * min(pow3(puddles),1.0)) * fresnel);
		#endif

		return color;


	}
#endif

void main()
{
	color = pow(color * MAX_COLOR_RANGE, vec3(2.2));

	#ifdef WATER_REFRACT
		color = waterRefraction(color, worldPosition, texcoord.st);
	#endif

	#ifdef VOLUMETRIC_CLOUDS
		color = getVolumetricClouds(color, refTexC.st);
	#endif

	#ifdef REFLECTIONS
		if (land > 0.9) color = getReflection(color);
	#endif

	#ifdef FOG
		color = getFog(ambientlight, color, texcoord.st);
	#endif

	color = renderGaux4(color);

	#if defined WATER_DEPTH_FOG && defined UNDERWATER_FOG
		if (isEyeInWater > 0.9) color = getWaterDepthFog(color, fragpos, vec3(0.0));
	#endif

	#ifdef VOLUMETRIC_LIGHT
		color = getVolumetricLight(color, texcoord.st);
	#endif

	color = pow(color, vec3(0.4545));

/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color / MAX_COLOR_RANGE, 1.0);
}