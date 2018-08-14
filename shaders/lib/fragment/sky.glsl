// Constants used to set ozone coefficient
const float airNumberDensity       = 2.5035422e25; // m^3
const float ozoneConcentrationPeak = 8e-6;
const float ozoneNumberDensity     = airNumberDensity * ozoneConcentrationPeak;
const vec3  ozoneCrossSection      = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22); // cm^2 | single-wavelength values.

const float atmosphere_planetRadius = 6731e3; // Should probably move this to somewhere else.

const float atmosphere_atmosphereHeight = 110e3;
const vec2  atmosphere_scaleHeights     = vec2(8.0e3, 1.2e3);

const float atmosphere_mieg = 0.77;

const vec3 atmosphere_coefficientRayleigh = vec3(5.8000e-6, 1.3500e-5, 3.3100e-5); // Want to calculate this myself at some point.
const vec3 atmosphere_coefficientOzone    = ozoneCrossSection * (ozoneNumberDensity * 1e-6); // ozone cross section * (ozone number density * (cm ^ 3))
const vec3 atmosphere_coefficientMie      = vec3(3.0000e-6, 3.0000e-6, 3.0000e-6); // Should be >= 2e-6

// The rest of these constants are set based on the above constants
const vec2  atmosphere_inverseScaleHeights     = 1.0 / atmosphere_scaleHeights;
const vec2  atmosphere_scaledPlanetRadius      = atmosphere_planetRadius * atmosphere_inverseScaleHeights;
const float atmosphere_atmosphereRadius        = atmosphere_planetRadius + atmosphere_atmosphereHeight;
const float atmosphere_atmosphereRadiusSquared = atmosphere_atmosphereRadius * atmosphere_atmosphereRadius;

const mat2x3 atmosphere_coefficientsScattering  = mat2x3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie);
const mat3   atmosphere_coefficientsAttenuation = mat3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie * 1.11, atmosphere_coefficientOzone); // commonly called the extinction coefficient

float atmosphere_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) * rPI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float atmosphere_miePhase(float cosTheta, const float g) {
	const float gg = g * g;
	return (0.25 * rPI) * (1.0 - gg) * pow((1.0 + gg) - g * 2.0 * cosTheta, -1.5);
}

vec2 atmosphere_phase(float cosTheta, const float g) {
	return vec2(atmosphere_rayleighPhase(cosTheta), atmosphere_miePhase(cosTheta, g));
}

// No intersection if returned y component is < 0.0
vec2 rsi(vec3 position, vec3 direction, float radius) {
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	      delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}

vec3 atmosphere_density(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -atmosphere_inverseScaleHeights + atmosphere_scaledPlanetRadius);

	// Ozone distribution curve by Sergeant Sarcasm - https://www.desmos.com/calculator/j0wozszdwa
	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - atmosphere_planetRadius) * (1.0 / 5000.0))
	            * exp(-max(0.0, (centerDistance - 35000.0) - atmosphere_planetRadius) * (1.0 / 15000.0));
	return vec3(rayleighMie, ozone);
}

vec3 atmosphere_airmass(vec3 position, vec3 direction, float rayLength, const float steps) {
	float stepSize  = rayLength / steps;
	vec3  increment = direction * stepSize;
	position += increment * 0.5;

	vec3 airmass = vec3(0.0);
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += atmosphere_density(length(position));
	}

	return airmass * stepSize;
}
vec3 atmosphere_airmass(vec3 position, vec3 direction, const float steps) {
	float PoD = dot(position, direction);
	float rayLength = sqrt(PoD * PoD + atmosphere_atmosphereRadiusSquared - dot(position, position)) - PoD;

	return atmosphere_airmass(position, direction, rayLength, steps);
}

vec3 atmosphere_opticalDepth(vec3 position, vec3 direction, float rayLength, const float steps) {
	return atmosphere_coefficientsAttenuation * atmosphere_airmass(position, direction, rayLength, steps);
}
vec3 atmosphere_opticalDepth(vec3 position, vec3 direction, const float steps) {
	return atmosphere_coefficientsAttenuation * atmosphere_airmass(position, direction, steps);
}

vec3 atmosphere_transmittance(vec3 position, vec3 direction, const float steps) {
	return exp2(-atmosphere_opticalDepth(position, direction, steps) * rLOG2);
}

float CalculateSunSpot(float VdotL) {
	const float sunAngularSize = 0.533333;
    const float sunRadius = radians(sunAngularSize);
    const float cosSunRadius = cos(sunRadius);
    const float sunLuminance = 1.0 / ((1.0 - cosSunRadius) * PI);

	return fstep(cosSunRadius, VdotL) * sunLuminance;
}

float CalculateMoonSpot(float VdotL) {
	const float moonAngularSize = 0.516667;
    const float moonRadius = radians(moonAngularSize);
    const float cosMoonRadius = cos(moonRadius);
	const float moonLuminance = 1.0 / ((1.0 - cosMoonRadius) * PI);

	return fstep(cosMoonRadius, VdotL) * moonLuminance;
}

vec3 calculateAtmosphere(vec3 background, vec3 viewVector, vec3 upVector, vec3 sunVector, vec3 moonVector, const int iSteps) {
	const int jSteps = 3;

	const float phaseIsotropic = 0.25 * rPI;

	vec3 viewPosition = (atmosphere_planetRadius + eyeAltitude) * upVector;

	vec2 aid = rsi(viewPosition, viewVector, atmosphere_atmosphereRadius);
	if (aid.y < 0.0) return background;
	vec2 pid = rsi(viewPosition, viewVector, atmosphere_planetRadius * 0.998);
	bool planetIntersected = pid.y >= 0.0;

	vec2 sd = vec2((planetIntersected && pid.x < 0.0) ? pid.y : max(aid.x, 0.0), (planetIntersected && pid.x > 0.0) ? pid.x : aid.y);

	float stepSize  = (sd.y - sd.x) * (1.0 / iSteps);
	vec3  increment = viewVector * stepSize;
	vec3  position  = viewVector * sd.x + (increment * 0.3 + viewPosition);

	vec2 phaseSun  = atmosphere_phase(dot(viewVector, sunVector ), atmosphere_mieg);
	vec2 phaseMoon = atmosphere_phase(dot(viewVector, moonVector), atmosphere_mieg);

	vec3 scatteringSun     = vec3(0.0);
	vec3 scatteringMoon    = vec3(0.0);
	vec3 scatteringAmbient = vec3(0.0);
	vec3 transmittance     = vec3(1.0);

	for (int i = 0; i < iSteps; ++i, position += increment) {
		vec3 density          = atmosphere_density(length(position));
		if (density.y > 1e35) break;
		vec3 stepAirmass      = density * stepSize;
		vec3 stepOpticalDepth = atmosphere_coefficientsAttenuation * stepAirmass;

		vec3 stepTransmittance       = exp2(-stepOpticalDepth * rLOG2);
		vec3 stepTransmittedFraction = clamp((stepTransmittance - 1.0) / -stepOpticalDepth, 0.0, 1.0);
		vec3 stepScatteringVisible   = transmittance * stepTransmittedFraction;

		scatteringSun  += atmosphere_coefficientsScattering * (stepAirmass.xy * phaseSun ) * stepScatteringVisible * atmosphere_transmittance(position, sunVector,  jSteps);
		scatteringMoon += atmosphere_coefficientsScattering * (stepAirmass.xy * phaseMoon) * stepScatteringVisible * atmosphere_transmittance(position, moonVector, jSteps);

		// Nice way to fake multiple scattering.
		scatteringAmbient += atmosphere_coefficientsScattering * (stepAirmass.xy * phaseIsotropic) * stepScatteringVisible;

		transmittance *= stepTransmittance;
	}

	vec3 scattering = scatteringSun * sunColorBase + scatteringMoon * moonColorBase + scatteringAmbient * skyColor;

	return background * transmittance + scattering * TAU;
}
