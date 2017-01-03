#version 120

#include "lib/options.glsl"

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;

varying float mat;

uniform vec4 entityColor;

uniform sampler2D texture;

void main(){

	vec4 albedo = texture2D(texture, texcoord.st) * color;
	albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
	
	#include "lib/lmCoord.glsl"

/* DRAWBUFFERS:0246 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(normal,1.0) * 0.5 + 0.5;
	gl_FragData[2] = vec4(lightmaps.x, mat, lightmaps.y, 1.0);
	#ifdef SPECULAR_MAPPING
		gl_FragData[3] = vec4(vec3(0.0), 1.0);
	#endif
	
}