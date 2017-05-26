const int 		shadowMapResolution 		= 2048; //[512 1024 2048 4096]	
const float 	shadowDistance 				= 130.0;

#define COLOURED_SHADOWS
#define SHADOW_FILTER

#define shadowDarkness 2.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0] Intensity of ambient color on the shadows
#define sunlightAmount 2.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0] Intensity of the sunlight and the moonlight

vec3 emissiveLightColor = pow(mix(vec3(1.0, 0.22, 0.0), vec3(1.0), 0.03), vec3(0.7));

#define EMISSIVE_LIGHT_ATTEN 1.0 //[0.25 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define EMISSIVE_LIGHT_MULT 1.0 //[0.25 0.5 1.0 2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0]

#define SKY_LIGHT_ATTEN 3.0 //[1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0]
#define MIN_LIGHT 0.004 //[0.0 0.002 0.004 0.008 0.016] Minimum light there is on the surface.

const float emissiveLightAtten = EMISSIVE_LIGHT_ATTEN;
const float emissiveLightMult = EMISSIVE_LIGHT_MULT;

const float skyLightAtten = SKY_LIGHT_ATTEN;
const float minLight = MIN_LIGHT;
