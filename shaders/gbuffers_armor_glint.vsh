#version 120

varying vec4 texcoord;
varying vec4 color;

void main(){

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	color = gl_Color;
}