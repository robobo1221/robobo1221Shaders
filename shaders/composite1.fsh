#version 120
#define program_composite1
#define FRAGMENT

varying vec2 texcoord;
flat varying vec2 jitter;

uniform sampler2D colortex5;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float frameTime;

#include "/lib/utilities.glsl"

const bool colortex5MipmapEnabled = true;

float calculateAverageLuminance(){
	vec3 avg = max0(decodeColor(texture2DLod(colortex5, vec2(0.5), 10).rgb));

	float lum = dot(avg, lumCoeff);
	float prevLum = decodeColor(texture2D(colortex5, vec2(0.5)).a);

	return mix(lum, prevLum, clamp(1.0 - frameTime, 0.0, 0.99));
}

vec3 calculateBloomTile(vec2 coord, const float lod, vec2 pixelSize){
	const int iSteps = 10;
	const int jSteps = 2;
	const float rISteps = 1.0 / iSteps;
	const float rJSteps = 1.0 / jSteps;

	const float lodScale = exp2(lod);
	const float offset = exp2(-lod) * 1.5;

	vec2 bloomCoord = (coord - offset) * lodScale;
	vec2 scale = pixelSize * lodScale;

    if (any(greaterThanEqual(abs(bloomCoord - 0.7), scale + 0.7)))
    	return vec3(0.0);

	vec3 totalBloom = vec3(0.0);
	float totalWeight = 0.0;

	const float rotateAmountI = rISteps * TAU;
	const float rotateAmountJ = PI * 0.5;

	vec2 pixelOffset = vec2(aspectRatio, 1.0);

	for (int i = 0; i < iSteps; ++i){
		vec2 rotatedCoordOffset = rotate(pixelOffset, rotateAmountI * float(i));
		
		for (int j = 0; j < jSteps; ++j){
			vec2 coordOffset = rotate(rotatedCoordOffset * rJSteps * (float(j) + rJSteps), rotateAmountJ * float(j));

			float sampleLength = (1.0 - float(j) * rJSteps);
			float weight = pow3(sampleLength);

			totalBloom += texture2D(colortex5, bloomCoord - coordOffset * scale).rgb * weight;

			totalWeight += weight;
		}
	}
	return totalBloom / totalWeight;
}

vec3 calculateBloomTiles(vec2 coord){
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec3 bloomTiles = vec3(0.0);

	const float lods[7] = float[7](
		2.0,
		3.0,
		4.0,
		5.0,
		6.0,
		7.0,
		8.0
	);

	float lodcorrection = pixelSize.x * (0.5 / lods.length);

	for (int i = 0; i < lods.length; i++){
		coord += vec2(lodcorrection, 0.0);
		bloomTiles += calculateBloomTile(coord, lods[i], pixelSize);
	}

	return bloomTiles;
}

/* DRAWBUFFERS:235 */
void main() {

	vec3 color = texture2D(colortex5, texcoord + jitter).rgb;
	vec3 bloomTiles = calculateBloomTiles(texcoord);

	gl_FragData[0] = encodeRGBE8(color);
	gl_FragData[1] = encodeRGBE8(bloomTiles);
	gl_FragData[2] = vec4(color, encodeColor(calculateAverageLuminance()));
}
