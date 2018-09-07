#version 120
#define program_composite1
#define VERTEX

varying vec2 texcoord;

flat varying vec2 jitter;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

#include "/lib/utilities.glsl"
#include "/lib/uniform/TemporalJitter.glsl"

void main() {
	gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
	texcoord = gl_MultiTexCoord0.xy;

	jitter = calculateTemporalJitter() * 0.5;
}
