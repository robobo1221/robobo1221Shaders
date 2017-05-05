#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

uniform sampler2D texture;

void main(){

	vec4 albedo = texture2D(texture, texcoord.st) * color;
	
	#include "lib/lmCoord.glsl"

/* DRAWBUFFERS:042 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(lightmaps.x, 1.0, lightmaps.y, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	
}