#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;
varying vec2 midcoord;
varying vec2 tileSize;
varying vec4 color;

varying float pomDepth;

varying mat3 tbn;

varying vec3 tangentVec;
varying vec3 tangentVecView;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

varying vec3 worldPosition;

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

#if defined program_gbuffers_water
	uniform sampler2D noisetex;
#endif

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform int isEyeInWater;

#if defined program_gbuffers_entities
    uniform vec4 entityColor;
#endif

#include "/lib/utilities.glsl"

#if defined program_gbuffers_water
	#include "/lib/fragment/waterWaves.glsl"
#endif

float calculateOldf0(float metalness) {
	float f0 = 1.0;

	switch(int(material)) {
		case 147:
		case 41: f0 = 0.97; break; // Gold
		case 142:
		case 48: f0 = 0.46; break; // Iron
		default: break;
	}

	return f0 * metalness;
}

float calculateGrayscalef0(float roughness){
	return roughness >= 0.99 ? 0.0 : 0.021;
}

vec2 calculateWrapCoord(vec2 coord){
	return (round((midcoord - coord) / tileSize) * tileSize + coord);
}

float calculatePomDepth(vec2 coord, mat2 texD){
	return texture2DGrad(normals, calculateWrapCoord(coord), texD[0], texD[1]).a * pomDepth - pomDepth;
}

vec2 calculatePom(vec2 coord, mat2 texD, inout float shadow){
	vec3 increment = tangentVecView * inversesqrt(dot(tangentVecView.xy,tangentVecView.xy));
		 increment = length(increment.xy * texD) * increment;

	float l = length(increment);
		  l = max(l, 1e-4) * inversesqrt(dot(increment, increment));
	
	increment = increment * l;

	bool limit = increment.z < -1e-5;
	vec3 pomcoord = vec3(coord, 0.0);

	while(calculatePomDepth(pomcoord.xy, texD) < pomcoord.z && limit){
 		pomcoord += increment;
	}

	vec3 shadowIncrement = (shadowLightPosition * mat3(gbufferModelView)) * tbn;
		 shadowIncrement = shadowIncrement * inversesqrt(dot(shadowIncrement.xy, shadowIncrement.xy));
		 shadowIncrement = length(shadowIncrement.xy * texD) * shadowIncrement;

	float lightL = length(shadowIncrement);
		  lightL = max(lightL, 1e-4) * inversesqrt(dot(shadowIncrement, shadowIncrement));

	shadowIncrement = shadowIncrement * lightL;

	bool limitLight = shadowIncrement.z > 1e-5;
	vec3 shadowCoord = vec3(pomcoord.xy, calculatePomDepth(pomcoord.xy, texD));

	while(calculatePomDepth(shadowCoord.xy, texD) <= shadowCoord.z && limitLight && shadowCoord.z < 0.0) {
		shadowCoord += shadowIncrement;
	}

	shadow = shadowCoord.z < -1e-5 ? 0.0 : 1.0;

	return pomcoord.xy;
}

/* DRAWBUFFERS:01 */
void main() {
	#if defined program_gbuffers_water
		if(!gl_FrontFacing) discard;
	#endif

	mat2 texD = mat2(dFdx(texcoord), dFdy(texcoord));

	float pomShadow = 1.0;

	#if defined program_gbuffers_terrain && defined POM
		vec2 pomcoord = calculatePom(texcoord, texD, pomShadow);
		vec2 wrapcoord = calculateWrapCoord(pomcoord);
	#else
		vec2 pomcoord = texcoord;
		vec2 wrapcoord = texcoord;
	#endif

	vec4 albedo = texture2DGrad(tex, wrapcoord, texD[0], texD[1]) * color;
	vec4 specularData = texture2DGrad(specular, wrapcoord, texD[0], texD[1]);

	#if SPECULAR_FORMAT == SPEC_OLD
		float roughness = 1.0 - specularData.x;
		float f0 = calculateOldf0(specularData.y);
	#elif SPECULAR_FORMAT == SPEC_GRAYSCALE
		float roughness = 1.0 - specularData.x;
		float f0 = calculateGrayscalef0(roughness);
	#else
		float roughness = 1.0 - specularData.z;
		float f0 = specularData.x;
	#endif

	#if defined program_gbuffers_entities
		albedo.rgb = mix(albedo.rgb, albedo.rgb * entityColor.rgb, entityColor.a);
	#endif

	#if !defined program_gbuffers_block && !defined program_gbuffers_entities && !defined program_gbuffers_textured
		vec3 normal = texture2DGrad(normals, wrapcoord, texD[0], texD[1]).rgb * 2.0 - 1.0;
	#else
		vec3 normal = vec3(0.0, 0.0, 1.0);
	#endif

	#if defined program_gbuffers_water
		bool isWater = (material == 8 || material == 9);

		albedo = isWater ? vec4(1.0) : albedo;
		roughness = isWater ? 0.0 : roughness;
		f0 = isWater ? 0.021 : f0;

		if (isWater) {
			vec3 waveCoord = worldPosition + cameraPosition;

			#ifdef PARALLAX_WATER
				 waveCoord.xz = calculateParallaxWaterCoord(waveCoord, tangentVec);
			#endif

			normal = calculateWaveNormals(waveCoord);

		#if defined PARALLAX_WATER && defined ADVANCED_PARALLAX_WATER
			vec3 viewSpace = transMAD(gbufferModelView, waveCoord - cameraPosition);
			vec3 clipSpace = (diagonal3(gbufferProjection) * viewSpace + gbufferProjection[3].xyz) / -viewSpace.z * 0.5 + 0.5;
			gl_FragDepth = isEyeInWater == 0 ? clipSpace.z : gl_FragCoord.z;
		} else {
			gl_FragDepth = gl_FragCoord.z;
		#endif
		}
	#endif

	//normal = clampNormal(normal, -tangentVecView);
	normal = tbn * normal;

	#if defined program_gbuffers_textured
		normal = vec3(0.0, 1.0, 0.0);
	#endif

	vec2 ditheredLightmaps = bayer16(gl_FragCoord.xy) * (1.0 / 255.0) + lightmaps;
		 ditheredLightmaps = clamp01(ditheredLightmaps);

	#ifdef WHITE_WORLD
		albedo.rgb = vec3(1.0);
	#endif

	//albedo.rgb = vec3(wrapcoord, 0.0);

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(encodeNormal(normal), encodeVec2(ditheredLightmaps), encodeVec2(roughness, f0), encodeVec2(1.0 - matFlag, clamp01(pomShadow + 0.5)));
}
