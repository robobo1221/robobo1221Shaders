#define sun_illuminance 100000.0
#define moon_illuminance 0.32

#define sunColorBase (blackbody(5778.0) * sun_illuminance)
#define moonColorBase (blackbody(6000.0) * moon_illuminance)

//Sky coefficients and heights

const float airNumberDensity = 2.5035422e25; // m^3
const float ozoneConcentrationPeak = 8e-6;
const float ozoneNumberDensity = airNumberDensity * ozoneConcentrationPeak;
const vec3 ozoneCrossSection = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22); // cm^2 | single-wavelength values.

const float sky_planetRadius = 6731e3; // Should probably move this to somewhere else.

const float sky_atmosphereHeight = 110e3;
const vec2 sky_scaleHeights = vec2(8.0e3, 1.2e3);

const float sky_mieg = 0.77;

const vec3 sky_coefficientRayleigh = vec3(5.8000e-6, 1.3500e-5, 3.3100e-5);
const vec3 sky_coefficientOzone = (ozoneCrossSection * (ozoneNumberDensity * 1e-6)); // ozone cross section * (ozone number density * (cm ^ 3))
const vec3 sky_coefficientMie = vec3(3.0000e-6, 3.0000e-6, 3.0000e-6); // Should be >= 2e-6

const vec2 sky_inverseScaleHeights = 1.0 / sky_scaleHeights;
const vec2 sky_scaledPlanetRadius = sky_planetRadius * sky_inverseScaleHeights;
const float sky_atmosphereRadius = sky_planetRadius + sky_atmosphereHeight;
const float sky_atmosphereRadiusSquared = sky_atmosphereRadius * sky_atmosphereRadius;

const mat2x3 sky_coefficientsScattering  = mat2x3(sky_coefficientRayleigh, sky_coefficientMie);
const mat3   sky_coefficientsAttenuation = mat3(sky_coefficientRayleigh, sky_coefficientMie * 1.11, sky_coefficientOzone); // commonly called the extinction coefficient

const float volumetric_cloudHeight = 1600.0;
const float volumetric_cloudThickness = 2000.0;
const float volumetric_cloudMaxHeight = volumetric_cloudHeight + volumetric_cloudThickness;

//#define VOLUMETRIC_CLOUDS
#define volumetric_cloudDensity 0.0125