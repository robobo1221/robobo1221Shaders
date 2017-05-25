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

uniform float frameTimeCounter;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;

uniform float far;
uniform float near;

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec2 customTexcoord(){
	
	vec2 texCoord = texcoord.st;
	return texCoord.st;
}

vec2 newTexcoord = customTexcoord();

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

vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

vec3 toScreenSpace(vec3 p) {
        vec3 p3 = vec3(p) * 2. - 1.;
        vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
        return fragposition.xyz / fragposition.w;
}


float getFog(vec2 pos){

		vec3 fragposFog = toScreenSpace(vec3(pos, texture2D(depthtex1, pos).x));

		float fog = 1.0 - exp(-pow(sqrt(dot(fragposFog,fragposFog)) * 0.015, 2.0));
			  fog = clamp(fog, 0.0, 1.0);

		return fog;
}

#ifdef BLOOM

	vec3 getBloom(vec2 bCoord){

		vec3 blur = vec3(0.0);

		float fog = getFog(bCoord);

		float bloomPowMult = mix(1.0, 0.8, fog);

		blur += pow(texture2D(composite,bCoord/pow(2.0,2.0) + vec2(0.0,0.0)).rgb,vec3(2.2) * bloomPowMult)*pow(7.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,3.0) + vec2(0.3,0.0)).rgb,vec3(2.2) * bloomPowMult)*pow(6.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,4.0) + vec2(0.0,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(5.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,5.0) + vec2(0.1,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(4.0,1.0);
		blur += pow(texture2D(composite,bCoord/pow(2.0,6.0) + vec2(0.2,0.3)).rgb,vec3(2.2) * bloomPowMult)*pow(3.0,1.0);

		return blur * 0.25 * (1.0 + fog);
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

		float DoFGamma = 4.4;
				//Calculate pixel Circle of Confusion that will be used for bokeh depth of field
				float z = ld(texture2D(depthtex1, vec2(newTexcoord.st)).r)*far;
				float focus = ld(texture2D(depthtex1, vec2(0.5)).r)*far;
				float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,(1.0 / viewWidth)*5.0);
				vec4 sample = vec4(0.0);
				vec3 bcolor = vec3(0.0);
				float nb = 0.0;
				vec2 bcoord = vec2(0.0);

				for ( int i = 0; i < 49; i++) {
					sample = texture2D(gcolor, newTexcoord.xy + dofOffset[i]*pcoc*vec2(1.0,aspectRatio));

					sample.rgb *= MAX_COLOR_RANGE;

					bcolor += pow(sample.rgb, vec3(DoFGamma));
				}
		color.rgb = pow(bcolor/49.0, vec3(1.0/DoFGamma));

	return color;
	}
#endif


void main(){

	vec3 color = pow(texture2D(gcolor, newTexcoord.st).rgb * MAX_COLOR_RANGE, vec3(2.2));

	#ifdef DOF
		if (hand < 0.9) color = pow(getDof(color), vec3(2.2));
	#endif

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

	gl_FragColor = vec4(color, 1.0);
}
