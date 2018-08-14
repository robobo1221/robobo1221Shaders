#version 120
#define program_composite0
#define FRAG

varying vec2 texcoord;

uniform sampler2D colortex2;
uniform sampler2D colortex5;

#include "/lib/utilities.glsl"

/* DRAWBUBBERS:5 */

void main() {
	vec3 colorSample2 = max0(decodeRGBE8(texture2D(colortex2, texcoord)));
	vec3 color = colorSample2;

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
