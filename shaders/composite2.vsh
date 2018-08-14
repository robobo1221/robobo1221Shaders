#version 120
#define program_composite2
#define VERTEX

varying vec2 texcoord;

#include "/lib/utilities.glsl"

void main() {
	gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
	texcoord = gl_MultiTexCoord0.xy;
}
