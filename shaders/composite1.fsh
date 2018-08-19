#version 120
#define program_composite1
#define FRAGMENT

varying vec2 texcoord;

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

vec3 calculateBloomTile(const float lod, vec2 pixelSize){
	const int iSteps = 10;
	const int jSteps = 2;
	const float rISteps = 1.0 / iSteps;
	const float rJSteps = 1.0 / jSteps;
	const float rSteps = 1.0 / (jSteps * iSteps);

	const float lodScale = exp2(lod);
	const float offset = exp2(-lod);

	vec2 bloomCoord = (texcoord - offset) * lodScale;
	vec2 scale = pixelSize * lodScale;

    if (any(greaterThanEqual(abs(bloomCoord - 0.5), scale + 0.5)))
    	return vec3(0.0);

	vec3 totalBloom = vec3(0.0);
	float totalWeight = 0.0;

	const float rotateAmountI = rISteps * TAU;
	const float rotateAmountJ = PI * 0.5;

	const vec2 pixelOffset = vec2(2.0);
	const float pixelLength = 1.0 / length(pixelOffset);

	for (int i = 0; i < iSteps; ++i){
		vec2 rotatedCoordOffset = rotate(pixelOffset, rotateAmountI * float(i));
		
		for (int j = 0; j < jSteps; ++j){
			vec2 coordOffset = rotate(rotatedCoordOffset * rJSteps * (float(j) + 0.5), rotateAmountJ * float(j));

			float sampleLength = 1.0 - length(coordOffset) * pixelLength;
			float weight = pow2(sampleLength);

			totalBloom += texture2DLod(colortex5, bloomCoord - coordOffset * scale, lod).rgb * weight;

			totalWeight += weight;
		}
	}
	return totalBloom / totalWeight;
}

vec3 calculateBloomTiles(){
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec3 bloomTiles = vec3(0.0);

	const float lods[6] = float[6](
		2.0,
		3.0,
		4.0,
		5.0,
		6.0,
		7.0
	);

	for (int i = 0; i < 5; i++){
		bloomTiles += calculateBloomTile(lods[i], pixelSize);
	}

	return bloomTiles;
}

/* DRAWBUFFERS:235 */
void main() {

	vec3 color = texture2D(colortex5, texcoord).rgb;
	vec3 bloomTiles = calculateBloomTiles();

	gl_FragData[0] = encodeRGBE8(color);
	gl_FragData[1] = encodeRGBE8(bloomTiles);
	gl_FragData[2] = vec4(color, encodeColor(calculateAverageLuminance()));
}
