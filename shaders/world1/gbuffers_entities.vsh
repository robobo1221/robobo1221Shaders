#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;

varying float mat;

void main(){
	mat = 1.0;

	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	color = gl_Color;

	normal = normalize(gl_NormalMatrix * gl_Normal);
}
