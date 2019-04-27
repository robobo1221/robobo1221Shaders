const int shadowMapResolution = 2048; //[512 1024 2048 4096 8192 16384]
const float rShadowMapResolution = 1.0 / float(shadowMapResolution);
const float shadowDistance = 120.0;

#define sun_illuminance 128000.0
#define moon_illuminance 5.0

#define sunColorBase (blackbody(5778.0) * sun_illuminance)
#define moonColorBase (vec3(0.36333, 0.56333, 0.92333) * moon_illuminance )    //Fake Purkinje effect

#define torchIlluminance 300.0
#define torchColor (blackbody(2600.0) * torchIlluminance)

//#define COLOURED_SHADOWS
#define SHADOW_PENUMBRA

//#define GI
#define GI_RADIUS 50.0          //[25.0 50.0 75.0 100.0 125.0 150.0 175.0 200.0]        // How far will the bounced light reach.
#define GI_STEPS 12             //[2 4 6 8 10 12 14 16 18 20 24 28 32 48 64]      // The quality of Global Illumination

#define PARALLAX_WATER              // Parallax water
//#define ADVANCED_PARALLAX_WATER     // Makes the geometry have actual deformations by the wave. HAS SOME BUGS!
#define PARALLAX_WATER_QUALITY 4 //[2 4 8 16 32 64]

#define REFRACTION

//#define WHITE_WORLD

#define SPEC_NEW 0
#define SPEC_OLD 1
#define SPEC_GRAYSCALE 2

#define SPECULAR_FORMAT SPEC_NEW //[SPEC_NEW SPEC_OLD SPEC_GRAYSCALE]
