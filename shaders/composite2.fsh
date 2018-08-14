#version 120
#define program_composite2
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex2;
uniform sampler2D colortex5;

#include "/lib/utilities.glsl"
#include "/lib/fragment/camera.glsl"

/* DRAWBUBBERS:0 */
void main() {
	vec4 colorSample = texture2D(colortex2, texcoord);
	vec3 color = decodeColor(decodeRGBE8(colorSample));

	float avgLum = decodeColor(texture2D(colortex5, texcoord).a);

	color = calculateExposure(avgLum) * color;
	color /= color + 1.0;

	gl_FragData[0] = vec4(linearToSRGB(color), 1.0);
}
