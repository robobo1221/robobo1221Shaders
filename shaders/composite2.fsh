#version 120

	#define BLOOM									//Makes glow effect on bright stuffs.

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;

uniform float aspectRatio;
uniform float viewWidth;

float pw = 1.0/ viewWidth;

vec3 makeBloom(float lod,vec2 offset){

	vec3 bloom = vec3(0.0);
	float scale = pow(2.0,lod);
	vec2 coord = (texcoord.xy-offset)*scale;

	if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
		for (int i = -5; i < 5; i++) {
			for (int j = -5; j < 5; j++) {
			float wg = pow((1.0-length(vec2(i,j))/8.0),5)*pow(0.5,0.5)*20.0;
			vec2 bcoord = (texcoord.xy-offset+vec2(i,j)*pw*vec2(1.0,aspectRatio))*scale;
			if (wg > 0) bloom += pow(texture2D(gcolor,bcoord).rgb,vec3(2.2))*wg;
			}
		}
		bloom /= 49;
	}

	return bloom;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
vec3 blur = vec3(0);
	#ifdef BLOOM
		blur += pow(makeBloom(2,vec2(0,0)), vec3(1.0));
		blur += pow(makeBloom(3,vec2(0.3,0)), vec3(0.9));
		blur += pow(makeBloom(4,vec2(0,0.3)), vec3(0.8));
		blur += pow(makeBloom(5,vec2(0.1,0.3)), vec3(0.7));
		blur += pow(makeBloom(6,vec2(0.2,0.3)), vec3(0.6));
	#endif
	blur = pow(blur,vec3(0.4545));
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(blur,1.0);
}
