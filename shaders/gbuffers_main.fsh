#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;
flat varying vec3 tangentVec;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

varying vec3 worldPosition;

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

#if defined program_gbuffers_water
	uniform sampler2D noisetex;
#endif

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

#include "/lib/utilities.glsl"

#if defined program_gbuffers_water
	#include "/lib/fragment/waterWaves.glsl"
#endif

/* DRAWBUFFERS:01 */
void main() {
	vec4 albedo = texture2D(tex, texcoord) * color;
	vec3 normal = texture2D(normals, texcoord).rgb * 2.0 - 1.0;
	vec4 specularData = texture2D(specular, texcoord);

	float roughness = 1.0 - specularData.z;
	float f0 = specularData.x;

	#if defined program_gbuffers_water
		bool isWater = (material == 8 || material == 9);

		albedo = isWater ? vec4(1.0) : albedo;
		roughness = isWater ? 0.075 : roughness;
		f0 = isWater ? 0.021 : f0;
		if (isWater) normal = calculateWaveNormals(worldPosition.xz + cameraPosition.xz);
	#endif

	normal = dot(normal, normal) <= 0.0 ? vec3(0.0, 0.0, 1.0) : normal;

	normal = tbn * normal;

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(encodeNormal(normal), encodeVec2(lightmaps), encodeVec2(roughness, f0), encodeVec2(1.0, 1.0 - matFlag));
}
