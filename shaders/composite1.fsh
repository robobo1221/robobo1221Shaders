#version 120
#define program_composite1
#define FRAG

varying vec2 texcoord;

uniform sampler2D colortex5;

uniform float frameTime; 

#include "/lib/utilities.glsl"

const bool colortex5MipmapEnabled = true;

float calculateAverageLuminance(){
	vec3 avg = max0(decodeColor(texture2DLod(colortex5, vec2(0.5), 10).rgb));

	float lum = dot(avg, lumCoeff);
	float prevLum = texture2D(colortex5, vec2(0.5)).a;

	return mix(lum, prevLum, clamp(1.0 - frameTime, 0.0, 0.99));
}

/* DRAWBUBBERS:25 */
void main() {

	vec3 color = texture2D(colortex5, texcoord).rgb;

	gl_FragData[0] = encodeRGBE8(color);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, calculateAverageLuminance());
}
