#version 120
#define program_composite2
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/utilities.glsl"
#include "/lib/fragment/camera.glsl"

vec3 jodieReinhardTonemap(vec3 c){
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc=c/(c+1.);
    return linearToSRGB(mix(c/(l+1.),tc,tc));
}

vec3 reinhardTonemap(vec3 c){
	return linearToSRGB(c / (c + 1.0));
}

vec3 burgressTonemap(vec3 c){
	vec3 x = c;
	return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

/*
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

vec3 roboboTonemap(vec3 x) {

	const vec3 tonemapCurve = vec3(5.5);

	x = linearToSRGB(x);
	x = pow(x, tonemapCurve);
	x = x / (x + 1.0);
	x = pow(x, 1.0 / tonemapCurve);

	x = mix(x, x * x * (3.0 - 2.0 * x), vec3(0.2));

	return x;
}

#include "/lib/utilities/bicubic.glsl"

vec3 calculateBloomTile(sampler2D textureSample, vec2 coord, const float lod){
	float lodScale = exp2(-lod);
	float offset = lodScale * 1.5;

	return decodeRGBE8(BicubicTexture(textureSample, coord * lodScale + offset));
}

vec3 calculateBloom(vec2 coord, float EV, vec2 pixelSize){
	vec3 bloom = vec3(0.0);

	const float lods[7] = float[7](
		2.0,
		3.0,
		4.0,
		5.0,
		6.0,
		7.0,
		8.0
	);

	for (int i = 0; i < 7; ++i){
		bloom += calculateBloomTile(colortex3, coord, lods[i]);
	}

	return decodeColor(bloom) * (1.0 / 7.) * exp2(EV - 3.0);
}

// https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit( in vec3 v ) {
    vec3 a = v * (v + 0.0245786) /*- 0.000090537*/;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACESFitted( in vec3 color ) {
    color = color * ACESInputMat;
	//color *= 1.5;
    color = RRTAndODTFit(color);
    color = color * ACESOutputMat;
    color = clamp(color, 0.0, 1.0);
	color = linearToSRGB(color);
    return color;
}

/* DRAWBUFFERS:0 */
void main() {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	vec4 colorSample = texture2D(colortex2, texcoord);
	vec3 color = decodeColor(decodeRGBE8(colorSample));

	float avgLum = decodeColor(texture2D(colortex5, texcoord).a);
	float exposureValue = calculateExposure(avgLum);

	vec3 bloom = calculateBloom(texcoord, exposureValue, pixelSize);

	color += bloom;
	color = exposureValue * color;
	color = ACESFitted(color);

	gl_FragData[0] = vec4(color, 1.0);
}
