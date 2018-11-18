const int shadowMapResolution = 2048; //[512 1024 2048 4096]
const float rShadowMapResolution = 1.0 / float(shadowMapResolution);
const float shadowDistance = 120.0;

#define sun_illuminance 100000.0
#define moon_illuminance 0.32

#define sunColorBase (blackbody(5778.0) * sun_illuminance)
#define moonColorBase (blackbody(6000.0) * moon_illuminance)

#define torchIlluminance 800.0
#define torchColor (blackbody(2700.0) * torchIlluminance)

//#define COLOURED_SHADOWS
//#define GI        //HIGHLY WIP

#define PARALLAX_WATER              // Parallax water
//#define ADVANCED_PARALLAX_WATER     // Makes the geometry have actual deformations by the wave. HAS SOME BUGS!

#define REFRACTION