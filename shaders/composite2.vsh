#version 120
#define program_composite2
#define VERTEX

varying vec2 texcoord;

#include "/lib/utilities.glsl"

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
