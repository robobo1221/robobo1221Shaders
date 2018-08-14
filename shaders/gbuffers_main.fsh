varying vec2 texcoord;
varying vec4 color;

varying mat3 tbn;
varying vec3 tangentVec;

varying vec2 lightmaps;

uniform sampler2D tex;
uniform sampler2D normals;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:01 */
void main() {
	vec4 albedo = texture2D(tex, texcoord) * color;
	vec3 normal = texture2D(normals, texcoord).rgb;

	normal = normal * 2.0 - 1.0;

	#if defined program_gbuffers_terrain
		normal = clampNormal(normal, tangentVec);
	#endif

	normal = tbn * normal;

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(encodeNormal(normal), encodeVec2(lightmaps), 0.0, 1.0);
}
