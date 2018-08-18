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
    return linearToSRGB(mix(c/(l+1.),tc,tc));
}

/*
vec3 burgressTonemap(vec3 c){
	vec3 x = max0(c - 0.004);
	return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec3 ACESFilmTonemap(vec3 x )
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return linearToSRGB(clamp01((x*(a*x+b))/(x*(c*x+d)+e)));
}

vec3 hableTonemapInjector(vec3 x){
	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.02;
	const float F = 0.30;

	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 hableTonemap(vec3 x){
	const float W = 11.2;

	const float exposureBias = 2.0;
	vec3 curr = hableTonemapInjector(x);

	vec3 whiteScale = 1.0 / hableTonemapInjector(vec3(W));
	vec3 color = curr * whiteScale;

	return linearToSRGB(color);
}
*/

/* DRAWBUFFERS:0 */
void main() {
	vec4 colorSample = texture2D(colortex2, texcoord);
	vec3 color = decodeColor(decodeRGBE8(colorSample));

	float avgLum = decodeColor(texture2D(colortex5, texcoord).a);

	color = calculateExposure(avgLum) * color;
	color = jodieReinhardTonemap(color);

	gl_FragData[0] = vec4(color, 1.0);
}
