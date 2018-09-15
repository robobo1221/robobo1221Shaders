#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;
flat varying vec3 tangentVec;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:01 */
void main() {
	vec4 albedo = texture2D(tex, texcoord) * color;
	vec3 normal = texture2D(normals, texcoord).rgb;
	vec4 specularData = texture2D(specular, texcoord);

	normal = normal * 2.0 - 1.0;
	normal = normal == vec3(0.0) || normal == vec3(-1.0) ? vec3(0.0, 0.0, 1.0) : normal;

	float roughness = 1.0 - specularData.z;
	float f0 = specularData.x;

	#if defined program_gbuffers_water
		albedo = (material == 8 || material == 9) ? vec4(1.0) : albedo;
		roughness = (material == 8 || material == 9) ? 0.05 : roughness;
		f0 = (material == 8 || material == 9) ? 0.021 : f0;
	#endif

	normal = tbn * normal;

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(encodeNormal(normal), encodeVec2(lightmaps), encodeVec2(roughness, f0), encodeVec2(1.0, 1.0 - matFlag));
}
