#version 120
#define program_final
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex0;

#include "/lib/utilities.glsl"

void main() {
	vec4 colorSample = texture2D(colortex0, texcoord);
	vec3 color = colorSample.rgb;
		 
	gl_FragColor = vec4(color, 1.0);
}
