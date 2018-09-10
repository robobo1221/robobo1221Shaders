#version 120
#define program_shadow
#define FRAGMENT

varying vec2 texcoord;
varying vec4 color;

flat varying float material;
flat varying vec3 normals;

uniform sampler2D tex;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:01 */
void main()
{
	vec4 albedo = texture2D(tex, texcoord) * color;
	albedo.rgb = srgbToLinear(albedo.rgb);
	
	bool isWater = material == 8 || material == 9;

	albedo = isWater ? vec4(1.0, 1.0, 1.0, 1.0) : albedo;

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(normals, float(isWater) * 0.5 + 0.5);
}
