float sky_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) * rPI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float sky_miePhase(float cosTheta, const float g) {
	const float gg = g * g;
	return (gg * -0.25 + 0.25) * rPI * pow(-2.0 * (g * cosTheta) + (gg + 1.0), -1.5);
}

vec2 sky_phase(float cosTheta, const float g) {
	return vec2(sky_rayleighPhase(cosTheta), sky_miePhase(cosTheta, g));
}

vec3 sky_density(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -sky_inverseScaleHeights + sky_scaledPlanetRadius);

	// Ozone distribution curve by Sergeant Sarcasm - https://www.desmos.com/calculator/j0wozszdwa
	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - sky_planetRadius) * (1.0 / 5000.0))
	            * exp(-max(0.0, (centerDistance - 35000.0) - sky_planetRadius) * (1.0 / 15000.0));
	return vec3(rayleighMie, ozone);
}

vec3 sky_airmass(vec3 position, vec3 direction, float rayLength, const float steps) {
	float stepSize  = rayLength * (1.0 / steps);
	vec3  increment = direction * stepSize;
	position += increment * 0.5;

	vec3 airmass = vec3(0.0);
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += sky_density(length(position));
	}

	return airmass * stepSize;
}
vec3 sky_airmass(vec3 position, vec3 direction, const float steps) {
	float rayLength = dot(position, direction);
	      rayLength = rayLength * rayLength + sky_atmosphereRadiusSquared - dot(position, position);
		  if (rayLength < 0.0) return vec3(0.0);
	      rayLength = sqrt(rayLength) - dot(position, direction);

	return sky_airmass(position, direction, rayLength, steps);
}

vec3 sky_opticalDepth(vec3 position, vec3 direction, float rayLength, const float steps) {
	return sky_coefficientsAttenuation * sky_airmass(position, direction, rayLength, steps);
}
vec3 sky_opticalDepth(vec3 position, vec3 direction, const float steps) {
	return sky_coefficientsAttenuation * sky_airmass(position, direction, steps);
}

vec3 sky_transmittance(vec3 position, vec3 direction, const float steps) {
	return exp2(-sky_opticalDepth(position, direction, steps) * rLOG2);
}

float calculateSunSpot(float VdotL) {
    const float sunRadius = radians(sunAngularSize);
    const float cosSunRadius = cos(sunRadius);
    const float sunLuminance = 1.0 / ((1.0 - cosSunRadius) * TAU);

	return fstep(cosSunRadius, VdotL) * sunLuminance;
}

float calculateMoonSpot(float VdotL) {
    const float moonRadius = radians(moonAngularSize);
    const float cosMoonRadius = cos(moonRadius);
	const float moonLuminance = 1.0 / ((1.0 - cosMoonRadius) * TAU);

	return fstep(cosMoonRadius, VdotL) * moonLuminance;
}

float calculateStars(vec3 worldVector, vec3 moonVector){
	const int res = 256;

	worldVector = getRotMat(moonVector, vec3(0.0, 1.0, 0.0)) * worldVector;

	vec3 p = worldVector * res;
	vec3 flr = floor(p);
	vec3 fr = (p - flr) - 0.5;

	float intensity = hash13(flr);
		  intensity = fstep(intensity, 0.0025);
	float stars = smoothstep(0.5, 0.0, length(fr)) * intensity;

	return stars * 5.0;
}

vec3 calculateAtmosphere(vec3 background, vec3 viewVector, vec3 upVector, vec3 sunVector, vec3 moonVector, out vec2 pid, out vec3 transmittance, const int iSteps) {
	const int jSteps = 3;

	vec3 viewPosition = (sky_planetRadius + eyeAltitude) * upVector;

	vec2 aid = rsi(viewPosition, viewVector, sky_atmosphereRadius);
	if (aid.y < 0.0) {transmittance = vec3(1.0); return background;}
	
	pid = rsi(viewPosition, viewVector, sky_planetRadius * 0.9994);
	bool planetIntersected = pid.y >= 0.0;

	vec2 sd = vec2((planetIntersected && pid.x < 0.0) ? pid.y : max(aid.x, 0.0), (planetIntersected && pid.x > 0.0) ? pid.x : aid.y);

	float stepSize  = (sd.y - sd.x) * (1.0 / iSteps);
	vec3  increment = viewVector * stepSize;
	vec3  position  = viewVector * sd.x + (increment * 0.3 + viewPosition);

	vec2 phaseSun  = sky_phase(dot(viewVector, sunVector ), sky_mieg);
	vec2 phaseMoon = sky_phase(dot(viewVector, moonVector), sky_mieg);

	vec3 scatteringSun     = vec3(0.0);
	vec3 scatteringMoon    = vec3(0.0);
	vec3 scatteringAmbient = vec3(0.0);
	transmittance = vec3(1.0);

	for (int i = 0; i < iSteps; ++i, position += increment) {
		vec3 density          = sky_density(length(position));
		if (density.y > 1e35) break;
		vec3 stepAirmass      = density * stepSize;
		vec3 stepOpticalDepth = sky_coefficientsAttenuation * stepAirmass;

		vec3 stepTransmittance       = exp2(-stepOpticalDepth * rLOG2);
		vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
		vec3 stepScatteringVisible   = transmittance * stepTransmittedFraction;

		scatteringSun  += sky_coefficientsScattering * (stepAirmass.xy * phaseSun ) * stepScatteringVisible * sky_transmittance(position, sunVector,  jSteps);
		scatteringMoon += sky_coefficientsScattering * (stepAirmass.xy * phaseMoon) * stepScatteringVisible * sky_transmittance(position, moonVector, jSteps);

		// Nice way to fake multiple scattering.
		scatteringAmbient += sky_coefficientsScattering * stepAirmass.xy * stepScatteringVisible;

		transmittance *= stepTransmittance;
	}

	vec3 scattering = scatteringSun * baseSunColor + scatteringMoon * baseMoonColor + scatteringAmbient * skyColor;

	transmittance = planetIntersected ? vec3(0.0) : transmittance;

	return background * transmittance + scattering;
}
