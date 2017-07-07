#version 120
#include "lib/util/fastMath.glsl"

varying vec4 texcoord;

void main(){
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;
}