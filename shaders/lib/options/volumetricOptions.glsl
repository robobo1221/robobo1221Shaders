//#define VOLUMETRIC_CLOUDS
#define VC_QUALITY 10 //[5 10 15 20 24 32 64 128 256 512]
#define VC_LOCAL_COVERAGE

#define volumetric_cloudDensity 0.0125  //[0.005 0.075 0.01 0.0125 0.015 0.0175 0.02 0.025 0.03 0.035 0.04 0.045 0.05]
#define volumetric_cloudHeight 1600.0   //[100.0 110.0 120.0 130.0 140.0 160.0 180.0 200.0 220.0 240.0 260.0 280.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0 1200.0 1400.0 1600.0 1800.0 2000.0]
#define volumetric_cloudMinHeight volumetric_cloudHeight

const float volumetric_cloudScale =  1600.0 / volumetric_cloudHeight;
const float volumetric_cloudThickness = 1500.0 / volumetric_cloudScale;
const float volumetric_cloudMaxHeight = volumetric_cloudMinHeight + volumetric_cloudThickness;

#define VOLUMETRIC_LIGHT
#define VOLUMETRIC_LIGHT_WATER

#define VL_QUALITY 8 //[2 4 6 8 10 12 14 16 18 20 24 28 32 48 64 128]
#define VL_WATER_QUALITY 8 //[2 4 6 8 10 12 14 16 18 20 24 28 32 48 64 128]

#define WATER_DENSITY 1.0   //[0.25 0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0 6.0]

const float waterScatterCoefficient = 0.06 * WATER_DENSITY;
const vec3 waterTransmittanceCoefficient = vec3(0.996078, 0.406863, 0.25098) * 0.25 * WATER_DENSITY + waterScatterCoefficient;

#define ATMOSPHERE_SCALE 14.0   //[1.0 2.0 4.0 6.0 8.0 10.0 12.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0] //Higher numbers result in more thicker atmosphere (VL). Keep at 1.0 for correct result