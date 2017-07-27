#version 120

	#define BLOOM									//Makes glow effect on bright stuffs.

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;

uniform float aspectRatio;
uniform float viewWidth;

#ifdef BLOOM
	vec3 makeBloom(const float lod,const vec2 offset){

		vec3 bloom = vec3(0.0);
		float scale = pow(2.0,lod);
		vec2 coord = (texcoord.xy-offset)*scale;
		float totalWeight = 0.0;

		if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
			for (int i = -5; i < 5; i++) {
				for (int j = -5; j < 5; j++) {
				
					float wg = pow(1.0-length(vec2(i,j)) * 0.125,12.0);
					vec2 bcoord = (texcoord.xy - offset + vec2(i,j) / viewWidth * vec2(1.0,aspectRatio))*scale;

					if (wg > 0) bloom = pow(texture2D(gcolor,bcoord).rgb,vec3(4.4))*wg + bloom;
					totalWeight += wg;
				}
			}
			bloom /= totalWeight;
		}

		return bloom;
	}
#endif

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
vec3 blur = vec3(0);
	#ifdef BLOOM
		blur += makeBloom(2.,vec2(0,0));
		blur += makeBloom(3.,vec2(0.3,0));
		blur += makeBloom(4.,vec2(0,0.3));
		blur += makeBloom(5.,vec2(0.1,0.3));
		blur += makeBloom(6.,vec2(0.2,0.3));
	#endif
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(pow(blur, vec3(1.0 / 4.4)),1.0);
}
