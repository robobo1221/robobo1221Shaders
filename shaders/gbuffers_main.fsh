#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;

varying vec3 tangentVec;
varying vec3 tangentVecView;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

varying vec3 worldPosition;

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

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

/* DRAWBUFFERS:01 */
void main() {
	#if defined program_gbuffers_water
		if(!gl_FrontFacing) discard;
	#endif

	vec4 albedo = texture2D(tex, texcoord) * color;
	vec4 specularData = texture2D(specular, texcoord);

	float roughness = 1.0 - specularData.z;
	float f0 = specularData.x;

	#if defined program_gbuffers_entities
		albedo.rgb = mix(albedo.rgb, albedo.rgb * entityColor.rgb, entityColor.a);
	#endif

	#if !defined program_gbuffers_block && !defined program_gbuffers_entities
		vec3 normal = texture2D(normals, texcoord).rgb * 2.0 - 1.0;
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

	normal = clampNormal(normal, -tangentVecView);
	normal = tbn * normal;

	vec2 ditheredLightmaps = bayer16(gl_FragCoord.xy) * (1.0 / 255.0) + (1.0 / 255.0) + lightmaps;
	ditheredLightmaps = clamp01(ditheredLightmaps);

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(encodeNormal(normal), encodeVec2(ditheredLightmaps), encodeVec2(roughness, f0), encodeVec2(1.0, 1.0 - matFlag));
}
