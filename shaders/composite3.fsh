#version 120
#define program_composite3
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex4;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:4 */
void main() {
	vec4 currentColorSample = texture2D(colortex0, texcoord);
	vec4 previousColorSample = texture2D(colortex4, texcoord);

	vec3 color = currentColorSample.rgb;
	color = mix(color, previousColorSample.rgb, 0.8);

	gl_FragData[0] = vec4(color, 1.0);
}
