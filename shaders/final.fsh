#version 120
#include "lib/colorRange.glsl"

#define BLOOM
	#define BLOOM_MULT 5.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0 8.0] basic multiplier

#define VIGNETTE
	#define VIGNETTE_MULT 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0 8.0] basic multiplier
	
#define SCREEN_REFRACTION //Refracts the sceen underwater and when rain is hitting the camera.
	#define SCREEN_REFRACTION_MULT 1.0 //[0.5 1.0 1.5 2.0]

//#define LENS_FLARE
	#define LENS_FLARE_MULT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
	
#define BRIGHTNESS 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define GAMMA 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define CONTRAST 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define LIFT 0.0 //[0.05 0.1 0.15 0.2]
#define INVERSE_LIFT 0.0 //[0.025 0.05 0.075 0.1]

#define RED_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define GREEN_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define BLUE_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D depthtex1;
uniform sampler2D composite;
uniform sampler2D noisetex;

uniform vec3 sunPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform mat4 gbufferProjection;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float near;

uniform int isEyeInWater;
uniform int worldTime;

float transition_fading = 1.0-(clamp((worldTime-12000.0)/300.0,0.0,1.0)-clamp((worldTime-13000.0)/300.0,0.0,1.0) + clamp((worldTime-22000.0)/200.0,0.0,1.0)-clamp((worldTime-23400.0)/200.0,0.0,1.0));

float dynamicExposure = mix(1.0,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 3.0f)));

float getRainDrops(){

	float noiseTexture = texture2D(noisetex, vec2(texcoord.s, texcoord.t / 5.5) * 0.015 + vec2(0.0,frameTimeCounter) * 0.0005).x;
	noiseTexture += texture2D(noisetex, vec2(texcoord.s, texcoord.t / 5.5) * 0.03 + vec2(0.0,frameTimeCounter) * 0.002).x * 0.5;

	noiseTexture = min(max(noiseTexture - 1.1,0.0) * 10.0, 1.0);
	noiseTexture *= clamp((eyeBrightnessSmooth.y-220)/15.0,0.0,1.0);

	return noiseTexture;
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec2 clampScreen(vec2 coord) {

	vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

    return clamp(coord, pixel, 1.0 - pixel);
}

vec2 customTexcoord(){
	
	vec2 texCoord = texcoord.st;

	float noiseTexture = texture2D(noisetex, texcoord.st * 0.03 + frameTimeCounter * 0.001).x;

	vec2 wavyness = (vec2(noiseTexture, noiseTexture) * 2.0 - 1.0) * mix(getRainDrops() * rainStrength * 2.0,1.0,isEyeInWater) * 0.0075;

	#ifdef SCREEN_REFRACTION
		return texCoord + wavyness * SCREEN_REFRACTION_MULT;
	#else
		return texCoord;
	#endif
}

vec2 newTexcoord = clampScreen(customTexcoord());

vec3 tonemap(vec3 x)
{
	float a = BRIGHTNESS;
	float b = GAMMA;
	float c = CONTRAST;
	float d = LIFT;
	float e = INVERSE_LIFT;
	
	x = mix(x, vec3(0.33333), 1.2 - c);

	x = pow(x, vec3(2.2)) * pow(1.5, 2.2) * a;

	x = max(vec3(0.0),x - INVERSE_LIFT) + LIFT;
	x = pow((x * (6.2 * x + 0.4)) / (x * (6.2 * x + 1.56) + 0.2), vec3(b));
	return x;
}

vec3 reinhardTonemap(vec3 color)
{
	return color / (1.0 + color);
}


#ifdef BLOOM

	vec3 getBloom(in vec2 bCoord){

		vec3 blur = vec3(0.0);

		float bloomPowMult = mix(1.0, 0.8, float(isEyeInWater));
		bloomPowMult = mix(bloomPowMult, 0.8, rainStrength * (1.0 - float(isEyeInWater)) * (1.0 - dynamicExposure));

		blur += pow(texture2D(composite,bCoord/pow(2.0,2.0) + vec2(0.0,0.0)).rgb,vec3(2.2) * bloomPowMult)*pow(7.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,3.0) + vec2(0.3,0.0)).rgb,vec3(2.2) * bloomPowMult)*pow(6.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,4.0) + vec2(0.0,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(5.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,5.0) + vec2(0.1,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(4.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,6.0) + vec2(0.2,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(3.0,1.0);

		return blur * 0.25;
	}

#endif

#ifdef VIGNETTE
	vec3 getVignette(vec3 color, vec2 pos){
		float factor = distance(pos, vec2(0.5));

		factor = pow(factor, 4.4);
		factor *= VIGNETTE_MULT;

		factor = clamp(1.0 - factor, 0.0, 1.0);

		return color * factor;
	}
#endif

/*

	//hexagon pattern
	const vec2 hex_offsets[61] = vec2[61] (	vec2(  0.2165,  0.1250 ),
											vec2(  0.0000,  0.2500 ),
											vec2( -0.2165,  0.1250 ),
											vec2( -0.2165, -0.1250 ),
											vec2( -0.0000, -0.2500 ),
											vec2(  0.2165, -0.1250 ),
											vec2(  0.4330,  0.2500 ),
											vec2(  0.0000,  0.5000 ),
											vec2( -0.4330,  0.2500 ),
											vec2( -0.4330, -0.2500 ),
											vec2( -0.0000, -0.5000 ),
											vec2(  0.4330, -0.2500 ),
											vec2(  0.6495,  0.3750 ),
											vec2(  0.0000,  0.7500 ),
											vec2( -0.6495,  0.3750 ),
											vec2( -0.6495, -0.3750 ),
											vec2( -0.0000, -0.7500 ),
											vec2(  0.6495, -0.3750 ),
											vec2(  0.8660,  0.5000 ),
											vec2(  0.0000,  1.0000 ),
											vec2( -0.8660,  0.5000 ),
											vec2( -0.8660, -0.5000 ),
											vec2( -0.0000, -1.0000 ),
											vec2(  0.8660, -0.5000 ),
											vec2(  0.2163,  0.3754 ),
											vec2( -0.2170,  0.3750 ),
											vec2( -0.4333, -0.0004 ),
											vec2( -0.2163, -0.3754 ),
											vec2(  0.2170, -0.3750 ),
											vec2(  0.4333,  0.0004 ),
											vec2(  0.4328,  0.5004 ),
											vec2( -0.2170,  0.6250 ),
											vec2( -0.6498,  0.1246 ),
											vec2( -0.4328, -0.5004 ),
											vec2(  0.2170, -0.6250 ),
											vec2(  0.6498, -0.1246 ),
											vec2(  0.6493,  0.6254 ),
											vec2( -0.2170,  0.8750 ),
											vec2( -0.8663,  0.2496 ),
											vec2( -0.6493, -0.6254 ),
											vec2(  0.2170, -0.8750 ),
											vec2(  0.8663, -0.2496 ),
											vec2(  0.2160,  0.6259 ),
											vec2( -0.4340,  0.5000 ),
											vec2( -0.6500, -0.1259 ),
											vec2( -0.2160, -0.6259 ),
											vec2(  0.4340, -0.5000 ),
											vec2(  0.6500,  0.1259 ),
											vec2(  0.4325,  0.7509 ),
											vec2( -0.4340,  0.7500 ),
											vec2( -0.8665, -0.0009 ),
											vec2( -0.4325, -0.7509 ),
											vec2(  0.4340, -0.7500 ),
											vec2(  0.8665,  0.0009 ),
											vec2(  0.2158,  0.8763 ),
											vec2( -0.6510,  0.6250 ),
											vec2( -0.8668, -0.2513 ),
											vec2( -0.2158, -0.8763 ),
											vec2(  0.6510, -0.6250 ),
											vec2(  0.8668,  0.2513 ),
											vec2(  0.0000,  0.0000));

	vec3 getDof(vec3 color){

	const float focal = 0.05;
	float aperture = 0.002;
	const float sizemult = 50.0;

		float DoFGamma = 4.4;
				//Calculate pixel Circle of Confusion that will be used for bokeh depth of field
				float z = ld(texture2D(depthtex1, vec2(newTexcoord.st)).r)*far;
				float focus = ld(texture2D(depthtex1, vec2(0.5)).r)*far;
				float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,(1.0 / viewWidth)*10.0);
				vec4 sample = vec4(0.0);
				vec3 bcolor = vec3(0.0);
				float nb = 0.0;
				vec2 bcoord = vec2(0.0);

				for ( int i = 0; i < 61; i++) {
					sample = texture2D(gcolor, newTexcoord.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio),abs(pcoc * 200.0));

					sample.rgb *= MAX_COLOR_RANGE;

					bcolor += pow(sample.rgb, vec3(DoFGamma));
				}
		color.rgb = pow(bcolor/61.0, vec3(1.0/DoFGamma));

	return color;
	}
*/

vec3 toClipSpace(vec3 p)
{
	vec4 clipSpace = gbufferProjection * vec4(p, 1.0);
		 clipSpace /= clipSpace.w;
		 clipSpace = 0.5 * clipSpace + 0.5;

	return clipSpace.rgb;
}

#ifdef LENS_FLARE

vec3 getflare(vec2 uv, vec2 lPos, vec3 col, float d, float r, float h, bool ring){

	vec2 lVec = mix(lPos, vec2(0.5) / vec2(1.0,aspectRatio), d);

	float lens = clamp(1.0 - distance(uv, lVec), 0.0, 1.0);
		  lens = ring ? max(pow(lens, r) - pow(lens, r * 5.0), 0.0) : pow(lens, r);
		  lens = clamp((lens * h * 2.0) - 1.0*h, 0.0, 1.0);

		  //Cubic filtering
		  lens = lens*lens * (3.0 - (2.0 * lens));

	return col * lens;
}

vec3 getLensFlare(vec2 uv){

	const float lensFlareMult = 2.0f;

	float nightTime = 1.0 - float(worldTime < 12700 || worldTime > 23250);

	vec3 lVecVP = mix(normalize(sunPosition), normalize(-sunPosition), nightTime);
	float positionTreshHold = 1.0 - clamp(lVecVP.z/abs(lVecVP.z),0.0,1.0);

	vec2 screenCorrection = vec2(1.0,aspectRatio);
	uv /= screenCorrection;

	vec3 clipSpaceSunPosition = toClipSpace(sunPosition);
	vec2 lPos = clipSpaceSunPosition.xy / clipSpaceSunPosition.z;

	float lensFlareMask = 1.0 - float(texture2D(depthtex1, lPos).x < 1.0);

	float fading = 1.0 - distance(vec2(0.5), lPos);
		  fading = clamp((fading * 10.0) - 5.0, 0.0, 1.0);

	lPos /= screenCorrection;

	vec3 lens = vec3(0.0);

	///////////////////////////////////LensFlares////////////////////////////////////////

	if (nightTime < 0.9) {

		vec3 shapeColorA = vec3(1.0, 0.5, 0.0);
		vec3 shapeColorB = vec3(0.0, 0.25, 1.0);

		vec3 a0 = getflare(uv, lPos, shapeColorA, 1.9, 5.5, 0.7, false);
		vec3 a1 = getflare(uv, lPos, shapeColorA, 1.75, 5.5, 1.0, false);
		lens += max(a0 - a1, 0.0);

		vec3 b0 = getflare(uv, lPos, shapeColorB * 0.5, 1.5, 8.0, 20.0, false);
		vec3 b1 = getflare(uv, lPos, shapeColorB * 0.5, 1.45, 7.0, 20.0, false);

		lens += max(b0 - b1, 0.0);

		lens += getflare(uv, lPos, vec3(1.0, 0.0, 1.0) * 0.2, 1.6, 5.0, 1.0, false);
		lens += getflare(uv, lPos, vec3(0.1, 0.0, 1.0), 1.5, 50.0, 2.0, false);
		lens += getflare(uv, lPos, vec3(1.0, 0.25, 0.0) * 0.5, 1.45, 100.0, 2.0, false);
		lens += getflare(uv, lPos, vec3(0.0, 0.25, 1.0) * 0.5, 1.4, 200.0, 2.0, false);

		vec3 ring = getflare(uv, lPos, vec3(1.0, 0.0, 0.0), 0.0, 2.5, 1.0, true);
			ring += getflare(uv, lPos, vec3(0.0, 1.0, 0.0), 0.0, 2.5 * sqrt(0.75), 1.0, true);
			ring += getflare(uv, lPos, vec3(0.0, 0.0, 1.0), 0.0, 2.5 * sqrt(0.5), 1.0, true);
		lens += ring * 4.0;
	}

	//////////////////////////////////////////////////////////////////////////////////////

	lens *= (positionTreshHold * fading) * (lensFlareMask * lensFlareMult) * LENS_FLARE_MULT;

	return lens / (lens + 1.0);
}

#endif

void main(){

	vec3 color = pow(texture2D(gcolor, newTexcoord.st).rgb * MAX_COLOR_RANGE, vec3(2.2));

	//color = pow(getDof(color), vec3(2.2));

	#ifdef BLOOM
		color += pow(reinhardTonemap(getBloom(newTexcoord.st)) * MAX_COLOR_RANGE * 0.025 * BLOOM_MULT / reinhardTonemap(vec3(1.0)), vec3(2.2)) * 3.0;
	#endif
	
	color.r *= RED_MULT;
	color.g *= GREEN_MULT;
	color.b *= BLUE_MULT;
	
	color.rgb = pow(tonemap(pow(color.rgb, vec3(0.454545))), vec3(2.2));

	#ifdef VIGNETTE
		color = pow(getVignette(pow(color, vec3(0.4545)), texcoord.st), vec3(2.2));
	#endif

	color = pow(color, vec3(0.4545));

	#ifdef LENS_FLARE
		color += getLensFlare(newTexcoord);
	#endif

	gl_FragColor = vec4(color, 1.0);
}
