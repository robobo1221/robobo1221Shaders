const int shadowMapResolution = 2048; //[512 1024 2048 4096 8192 16384]
const float rShadowMapResolution = 1.0 / float(shadowMapResolution);
const float shadowDistance = 120.0;

#define sun_illuminance 128000.0
#define moon_illuminance 2.0

#define sunColorBase (blackbody(5778.0) * sun_illuminance)
#define moonColorBase (vec3(0.36333, 0.56333, 0.92333) * moon_illuminance )    //Fake Purkinje effect

#define torchIlluminance 300.0
#define torchColor (blackbody(2600.0) * torchIlluminance)

//#define COLOURED_SHADOWS
#define SHADOW_PENUMBRA

//#define GI        //HIGHLY WIP
#define GI_RADIUS 50.0          //[25.0 50.0 75.0 100.0 125.0 150.0 175.0 200.0]        // How far will the bounced light reach.
#define GI_QUALITY_RADIAL 3 //[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]      // The quality of the radial blur. Higher this for less dithering.
#define GI_QUALITY_OUTWARD 6   //[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]  // The quality of the vertical blur. Higher this for less stepping

#define PARALLAX_WATER              // Parallax water
//#define ADVANCED_PARALLAX_WATER     // Makes the geometry have actual deformations by the wave. HAS SOME BUGS!
#define PARALLAX_WATER_QUALITY 4 //[2 4 8 16 32 64]

#define REFRACTION