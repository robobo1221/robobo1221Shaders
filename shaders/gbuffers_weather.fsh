#version 120

varying vec4 texcoord;
uniform sampler2D texture;

void main(){

/* DRAWBUFFERS:7 */

	gl_FragData[0] = vec4(vec3(1.0), texture2D(texture, texcoord.st).a);
}