#version 120
#define program_shadow
#define FRAGMENT

varying vec2 texcoord;
varying vec4 color;

flat varying float material;

uniform sampler2D tex;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:0 */
void main()
{
	vec4 albedo = texture2D(tex, texcoord) * color;
	albedo.rgb = srgbToLinear(albedo.rgb);

	if (material == 8 || material == 9)albedo = vec4(1.0, 1.0, 1.0, 0.0);

	gl_FragData[0] = albedo;
}
