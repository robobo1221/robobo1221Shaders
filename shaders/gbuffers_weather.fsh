#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

uniform sampler2D texture;

void main(){

	vec4 albedo = texture2D(texture, texcoord.st) * color;

/* DRAWBUFFERS:71 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(lmcoord.x, 1.0, lmcoord.y, 1.0);
	
}