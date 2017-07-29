#version 120
#include "lib/util/fastMath.glsl"

#define BLOOM									//Makes glow effect on bright stuffs.

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

#ifdef BLOOM
	vec3 makeBloom(const float lod, vec2 offset){

		offset = 0.5 * pixelSize + offset;

		const float lodFactor = exp2(lod);

		vec3 bloom = vec3(0.0);
		vec2 scale = lodFactor * pixelSize;

		vec2 coord = (texcoord.xy-offset)*lodFactor;
		float totalWeight = 0.0;

		if (any(greaterThanEqual(abs(coord - 0.5), scale + 0.5)))
			return vec3(0.0);

		for (int i = -5; i < 5; i++) {
			for (int j = -5; j < 5; j++) {
				
				float wg = pow(1.0-fLength(vec2(i,j)) * 0.125,12.0);

				bloom = pow(texture2DLod(gcolor,coord + vec2(i,j) * scale + lodFactor * pixelSize, lod).rgb,vec3(4.4))*wg + bloom;
				totalWeight += wg;

			}
		}

		bloom /= totalWeight;

		return bloom;
	}
#endif

void main() {
vec3 blur = vec3(0);
	#ifdef BLOOM
		blur += makeBloom(2.,vec2(0.0,0.0));
		blur += makeBloom(3.,vec2(0.3,0.0));
		blur += makeBloom(4.,vec2(0.0,0.3));
		blur += makeBloom(5.,vec2(0.1,0.3));
		blur += makeBloom(6.,vec2(0.2,0.3));
		blur += makeBloom(7.,vec2(0.3,0.3));
	#endif
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(pow(blur, vec3(1.0 / 4.4)),1.0);
}
