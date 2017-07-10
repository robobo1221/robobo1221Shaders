#version 120
#include "lib/util/fastMath.glsl"
#include "lib/util/spaceConversions.glsl"

#include "lib/util/colorRange.glsl"

#define BLOOM
	#define BLOOM_MULT 5.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0 8.0] basic multiplier

#define VIGNETTE
	#define VIGNETTE_MULT 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0 8.0] basic multiplier
	
#define SCREEN_REFRACTION //Refracts the sceen underwater and when rain is hitting the camera.
	#define SCREEN_REFRACTION_MULT 1.0 //[0.5 1.0 1.5 2.0]

//#define LENS_FLARE
	#define LENS_FLARE_MULT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]

//#define DIRTY_LENS
	#define DIRTY_LENS_MULT 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]

#define BRIGHTNESS 1.0 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define GAMMA 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define CONTRAST 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define LIFT 0.0 //[0.05 0.1 0.15 0.2]
#define INVERSE_LIFT 0.0 //[0.025 0.05 0.075 0.1]

#define RED_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define GREEN_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define BLUE_MULT 1.0 		//[0.0 0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]

//#define DOF
	#define DOF_FOCAL_LENGTH 0.05 //[0.01 0.02 0.05 0.1 0.15 0.2 0.3]
	#define DOF_APERTURE 0.002 //[0.001 0.002 0.004 0.008 0.016 0.032 0.064 0.128 0.256]
	#define DOF_SIZE_MULT 50.0 //[10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0]

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
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

const float pi = 3.141592653589793238462643383279502884197169;

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

vec3 burgress(vec3 x){

	vec3 a = vec3(BRIGHTNESS);
	vec3 b = vec3(GAMMA);
	vec3 c = vec3(CONTRAST);
	vec3 d = vec3(LIFT);
	vec3 e = vec3(INVERSE_LIFT);
	
	x = mix(x, vec3(0.33333), 1.0 - c);

	x *= a;

	x = max(vec3(0.0),x - e) + d;
	x = pow((x * (6.2 * x + 0.03)) / (x * (6.2 * x + 0.8)), b * 2.2);
	return x;
}

vec3 reinhardTonemap(vec3 color)
{
	return color / (color + 1.0);
}

#ifdef DIRTY_LENS
	float shape(vec2 p, vec2 cp){
		float result = 0.0;

		const float points = 6.0;

		float r = 2.0 * pi / points;
		mat2 rotationMatrix = mat2(cos(r), -sin(r), sin(r), cos(r));

		vec2 refPos = vec2(0.0, 1.0);

		p.y = 1.0 - p.y;
		p *= vec2(aspectRatio, 1.0);

		for (float i = 0; i < points; i++){
			refPos = rotationMatrix * refPos;

			result = max(result, dot(p - cp, normalize(refPos)));
		}

		result = 1.0 - result;
		result = 1.0 - smoothstep(0.7, 0.68, result);
		
		return result;
	}

	float rand(float n){return fract(sin(n) * 43758.5453123);}

	float noise1D(float p){
		float fl = floor(p);
	float fc = fract(p);
		return mix(rand(fl), rand(fl + 1.0), fc);
	}

	float generateDirtyLens(vec2 p){
		float lens = 0.0;
		const int itter = 32;

		const float scale = 8.0;
		float increment = 1.0 / float(itter) * scale ;

		if (p.x > 0.0 && p.y > 0.0 && p.x < 1.0 && p.y < 1.0){
			for (int i = 0; i < itter; i++){
				lens += shape(p * scale, vec2(float(i) * 1.8, -noise1D(float(i)) * float(itter) + 5.0) * increment) * 0.5;
			}
		}

		return lens;
	}
#endif

#ifdef BLOOM

	vec3 getBloom(vec2 bCoord){

		vec3 blur = vec3(0.0);
		
		#ifdef DIRTY_LENS
		float dirt = (1.0 + generateDirtyLens(bCoord) * 3.0 * DIRTY_LENS_MULT);
		#else
		const float dirt = 1.0;
		#endif

		float bloomPowMult = 1.0 - 0.2 * float(isEyeInWater);
			  bloomPowMult *= 1.0 - 0.2 * rainStrength * (1.0 - float(isEyeInWater)) * (1.0 - dynamicExposure);

		blur += pow(texture2D(composite,bCoord * 0.25).rgb,vec3(2.2) * bloomPowMult) * 1.75;
		blur += pow(texture2D(composite,bCoord * 0.125 + vec2(0.3,0.0)).rgb,vec3(2.2) * bloomPowMult) * 1.5;
		blur += pow(texture2D(composite,bCoord * 0.0625 + vec2(0.0,0.3)).rgb,vec3(2.2) * bloomPowMult) * 1.25;
		blur += pow(texture2D(composite,bCoord * 0.03125 + vec2(0.1,0.3)).rgb,vec3(2.2) * bloomPowMult) * dirt;
		blur += pow(texture2D(composite,bCoord * 0.015625 + vec2(0.2,0.3)).rgb,vec3(2.2) * bloomPowMult) * 0.75;

		return blur;
	}

#endif

#ifdef VIGNETTE
	vec3 getVignette(vec3 color, vec2 pos){
		float factor = distance(pos, vec2(0.5));

		factor *= factor*factor*factor * 2.0;
		factor *= VIGNETTE_MULT;

		factor = clamp(1.0 - factor, 0.0, 1.0);

		return color * factor;
	}
#endif

#ifdef DOF

	vec3 aux = texture2D(gdepth, newTexcoord.st).rgb;
	float hand = float(aux.g > 0.85 && aux.g < 0.87);

const vec2 dofOffset[49] = vec2[49] (
		vec2(0.25, 0.0),
		vec2(0.0, 0.25),
		vec2(-0.25, 0.0),
		vec2(0.0, -0.25),
		vec2(0.5, 0.0),
		vec2(0.0, 0.5),
		vec2(-0.5, 0.0),
		vec2(0.0, -0.5),
		vec2(0.75, 0.0),
		vec2(0.0, 0.75),
		vec2(-0.75, 0.0),
		vec2(0.0, -0.75),
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(0.0, -1.0),
		vec2(0.25, 0.25),
		vec2(0.5, 0.25),
		vec2(0.75, 0.25),
		vec2(0.25, 0.5),
		vec2(0.5, 0.5),
		vec2(0.75, 0.5),
		vec2(0.25, 0.75),
		vec2(0.5, 0.75),
		vec2(0.25, -0.25),
		vec2(0.5, -0.25),
		vec2(0.75, -0.25),
		vec2(0.25, -0.5),
		vec2(0.5, -0.5),
		vec2(0.75, -0.5),
		vec2(0.25, -0.75),
		vec2(0.5, -0.75),
		vec2(-0.25, 0.25),
		vec2(-0.5, 0.25),
		vec2(-0.75, 0.25),
		vec2(-0.25, 0.5),
		vec2(-0.5, 0.5),
		vec2(-0.75, 0.5),
		vec2(-0.25, 0.75),
		vec2(-0.5, 0.75),
		vec2(-0.25, -0.25),
		vec2(-0.5, -0.25),
		vec2(-0.75, -0.25),
		vec2(-0.25, -0.5),
		vec2(-0.5, -0.5),
		vec2(-0.75, -0.5),
		vec2(-0.25, -0.75),
		vec2(-0.5, -0.75),
		vec2(0.0, 0.0));

	vec3 getDof(vec3 color){

	float focal = float(DOF_FOCAL_LENGTH);
	float aperture = float(DOF_APERTURE);
	float sizemult = float(DOF_SIZE_MULT);
				//Calculate pixel Circle of Confusion that will be used for bokeh depth of field
				float z = ld(texture2D(depthtex1, vec2(newTexcoord.st)).r)*far;
				float focus = ld(texture2D(depthtex1, vec2(0.5)).r)*far;
				float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,(1.0 / viewWidth)*5.0) * 1.5;
				vec4 sample = vec4(0.0);
				vec3 bcolor = vec3(0.0);
				float nb = 0.0;
				vec2 bcoord = vec2(0.0);

				for ( int i = 0; i < 49; i++) {
					sample = texture2D(gcolor, newTexcoord.xy + dofOffset[i]*pcoc*vec2(1.0,aspectRatio), abs(pcoc * 100.0));

					sample.rgb *= MAX_COLOR_RANGE;

					bcolor += pow(sample.rgb, vec3(4.4));
				}
		color.rgb = pow(bcolor * 0.0204081632653, vec3(0.227272727273));

	return color;
	}
#endif

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

	vec3 clipSpaceSunPosition = toClipSpace(gbufferProjection, sunPosition);
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
			ring += getflare(uv, lPos, vec3(0.0, 1.0, 0.0), 0.0, 2.5 * 0.866025403784, 1.0, true);
			ring += getflare(uv, lPos, vec3(0.0, 0.0, 1.0), 0.0, 2.5 * 0.707106781187, 1.0, true);
		lens += ring * 4.0;
	}

	//////////////////////////////////////////////////////////////////////////////////////

	lens *= (positionTreshHold * fading) * (lensFlareMask * lensFlareMult) * (LENS_FLARE_MULT * (1.0 - rainStrength));

	return lens / (lens + 1.0);
}

#endif

void main(){

	vec3 color = pow(texture2D(gcolor, newTexcoord.st).rgb * MAX_COLOR_RANGE, vec3(2.2));

	#ifdef DOF
		if (hand < 0.9) color = pow(getDof(color), vec3(2.2));
	#endif

	#ifdef BLOOM
		color += pow(reinhardTonemap(getBloom(newTexcoord.st)) * MAX_COLOR_RANGE * 0.055 * BLOOM_MULT, vec3(2.2)) * 3.0;
	#endif
	
	color.r *= RED_MULT;
	color.g *= GREEN_MULT;
	color.b *= BLUE_MULT;
	
	color.rgb = burgress(color);

	#ifdef VIGNETTE
		color = pow(getVignette(pow(color, vec3(0.4545)), texcoord.st), vec3(2.2));
	#endif

	color = pow(color, vec3(0.4545));

	#ifdef LENS_FLARE
		color += getLensFlare(newTexcoord);
	#endif

	gl_FragColor = vec4(color, 1.0);
}
