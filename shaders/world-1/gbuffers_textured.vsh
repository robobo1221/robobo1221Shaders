#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

void main(){

	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	color = gl_Color;
}