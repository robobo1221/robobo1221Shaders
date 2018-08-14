#version 120
#define program_composite2
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex2;
uniform sampler2D colortex5;

#include "/lib/utilities.glsl"
#include "/lib/fragment/camera.glsl"

vec3 jodieReinhardTonemap(vec3 c){
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc=c/(c+1.);
    return mix(c/(l+1.),tc,tc);
}

/* DRAWBUBBERS:0 */
void main() {
	vec4 colorSample = texture2D(colortex2, texcoord);
	vec3 color = decodeColor(decodeRGBE8(colorSample));

	float avgLum = decodeColor(texture2D(colortex5, texcoord).a);

	color = calculateExposure(avgLum) * color;
	color = jodieReinhardTonemap(color);

	gl_FragData[0] = vec4(linearToSRGB(color), 1.0);
}
