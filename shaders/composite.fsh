#version 120
#define program_composite0
#define FRAG

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex5;

#include "/lib/utilities.glsl"

/* DRAWBUBBERS:5 */

void main() {
	vec3 colorSample2 = max0(decodeRGBE8(texture2D(colortex2, texcoord)));
	vec3 color = colorSample2;

	vec4 translucentAlbedo = texture2D(colortex2, texcoord);
	color = mix(color, translucentAlbedo.rgb, translucentAlbedo.a);

	gl_FragData[0] = vec4(encodeColor(color), texture2D(colortex5, texcoord).a);
}
