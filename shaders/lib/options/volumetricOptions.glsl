//#define VOLUMETRIC_CLOUDS
#define VC_QUALITY 10 //[5 10 15 20 24 32 64 128 256 512]
#define VC_LOCAL_COVERAGE

#define volumetric_cloudDensity 0.0125
#define volumetric_cloudHeight 1600.0   //[100.0 110.0 120.0 130.0 140.0 160.0 180.0 200.0 220.0 240.0 260.0 280.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0 1200.0 1400.0 1600.0 1800.0 2000.0]
#define volumetric_cloudMinHeight volumetric_cloudHeight

const float volumetric_cloudScale =  1600.0 / volumetric_cloudHeight;
const float volumetric_cloudThickness = 1500.0 / volumetric_cloudScale;
const float volumetric_cloudMaxHeight = volumetric_cloudMinHeight + volumetric_cloudThickness;

#define WATER_DENSITY 1.0

const float waterScatterCoefficient = 0.01 * WATER_DENSITY;
const vec3 waterTransmittanceCoefficient = vec3(0.996078, 0.406863, 0.25098) * 0.25 * WATER_DENSITY + waterScatterCoefficient;