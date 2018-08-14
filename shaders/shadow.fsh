#version 120
#define program_shadow
#define FRAG

varying vec2 texcoord;
varying vec4 color;

uniform sampler2D tex;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:0 */
void main()
{
	vec4 albedo = texture2D(tex, texcoord) * color;

	gl_FragData[0] = albedo;
}
