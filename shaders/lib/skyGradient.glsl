float SunIntensity(float zenithAngleCos, float sunIntensity, float cutoffAngle, float steepness)
{
	return sunIntensity * max(0.0, 1.0 - exp(-((cutoffAngle - acos(zenithAngleCos))/steepness)));
}

vec3 Uncharted2Tonemap(vec3 x)
{

	float A = 0.40;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.03;
	float F = 0.30;
	float W = 1000.0;

   return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 ToneMap(vec3 color) {
    vec3 toneMappedColor;

    toneMappedColor = color * 0.04;
    toneMappedColor = Uncharted2Tonemap(toneMappedColor);

    toneMappedColor = pow(toneMappedColor,vec3(1.0/2.2));

    return toneMappedColor;
}

float calcSun(vec3 fragpos, vec3 sunVec){

	const float sunAngularDiameterCos = 0.99873194915;

	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float sundisk = smoothstep(sunAngularDiameterCos,sunAngularDiameterCos+0.0001,cosViewSunAngle);

	return 7000.0 * sundisk * (1.0 - rainStrength);

}

float calcMoon(vec3 fragpos, vec3 moonVec){

	const float moonAngularDiameterCos = 0.99833194915;

	float cosViewSunAngle = dot(normalize(fragpos.rgb), moonVec);
	float moondisk = smoothstep(moonAngularDiameterCos,moonAngularDiameterCos+0.001,cosViewSunAngle);

	return clamp(4.0 * moondisk, 0.0, 15.0) * (1.0 - rainStrength);

}

vec3 getAtmosphericScattering(vec3 color, vec3 fragpos, float sunMoonMult, vec3 fogColor, out vec3 sunMax, out vec3 moonMax){

	vec3 uPos = normalize(fragpos.rgb);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	const float turbidity = 1.5;
	const float rayleighCoefficient = 1.7;

	// constants for mie scattering
	const float mieCoefficient = 0.005;
	const float mieDirectionalG = 0.85;
	const float v = 4.0;

	// Wavelength of the primary colors RGB in nanometers.
	const vec3 primaryWavelengths = vec3(650, 550, 450) * 1.0E-9;

	const float n = 1.00029; // refractive index of air
	const float N = 2.54743E25; // number of molecules per unit volume for air at 288.15K and 1013mb (sea level -45 celsius)
	const float pn = 0.03;	// depolarization factor for standard air

	// optical length at zenith for molecules
	const float rayleighZenithLength = 8.4E3 ;
	const float mieZenithLength = 1.25E3;

	const vec3 K = vec3(0.686, 0.678, 0.666);

	const float sunIntensity = 1000.0;

	// earth shadow hack
	float cutoffAngle = pi * 0.5128205128205128;
	const float steepness = 1.5;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Cos Angles

	float cosViewSunAngle = dot(uPos, sunVec);
	float cosSunUpAngle = dot(sunVec, upVec) * 0.9 + 0.1; //Has a lower offset making it scatter when sun is below the horizon.
	float cosUpViewAngle = dot(upVec, uPos);

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness);  // Get sun intensity based on how high in the sky it is

	vec3 rayleighAtX = totalRayleigh(primaryWavelengths, n, N, pn) * rayleighCoefficient;
	vec3 mieAtX = totalMie(primaryWavelengths, K, turbidity, v) * mieCoefficient;

	float zenithAngle = max(0.0, cosUpViewAngle);
	float sunAngle = max(0.0, cosSunUpAngle * 0.95 + 0.05);

	float rayleighOpticalLength = rayleighZenithLength / zenithAngle;
	float mieOpticalLength = mieZenithLength / zenithAngle;

	float rayleighOpticalLengthSun = rayleighZenithLength / sunAngle;
	float mieOpticalLengthSun = mieZenithLength / sunAngle;

	vec3 Fex = exp(-(rayleighAtX * rayleighOpticalLength + mieAtX * mieOpticalLength));
	vec3 Fex2 = vec3(exp(-(rayleighCoefficient * 0.00002853075 * rayleighOpticalLength + mieAtX * mieOpticalLength)));
	vec3 FexSun = exp(-(rayleighAtX * rayleighOpticalLengthSun + mieAtX * mieOpticalLengthSun)) * 2.0;

	vec3 rayleighXtoEye = rayleighAtX * RayleighPhase(cosViewSunAngle);
	vec3 mieXtoEye = mieAtX * hgPhase(cosViewSunAngle , mieDirectionalG) * FexSun;

	vec3 totalLightAtX = rayleighAtX + mieAtX;
	vec3 lightFromXtoEye = rayleighXtoEye + mieXtoEye;

	vec3 scattering = sunE * (lightFromXtoEye / totalLightAtX);

	vec3 sky = scattering * (1.0 - Fex);
		 sky *= mix(vec3(1.0),sqrt(scattering * Fex),clamp(pow(1.0-cosSunUpAngle,5.0),0.0,1.0));

	vec3 sun = K * calcSun(fragpos, sunVec);
	vec3 moon = pow(moonlight, vec3(0.4545)) * calcMoon(fragpos, moonVec);

	sunMax = sunE * pow(mix(Fex2, Fex, clamp(pow(1.0-cosUpViewAngle,4.0),0.0,1.0)), vec3(0.4545))
	* mix(0.000005, 0.00003, clamp(pow(1.0-cosSunUpAngle,3.0),0.0,1.0)) * (1.0 - rainStrength);

	moonMax += pow(clamp(cosUpViewAngle,0.0,1.0), 0.8) * (1.0 - rainStrength);

	sky = max(ToneMap(sky), 0.0) + (sun * sunMax + moon * moonMax) * sunMoonMult;

	float nightLightScattering = pow(max(1.0 - max(cosUpViewAngle, 0.0 ),0.0), 2.0);

	sky += pow(fogColor * 0.5, vec3(0.4545)) * ((nightLightScattering + 0.5 * (1.0 - nightLightScattering)) * clamp(pow(1.0-cosSunUpAngle,35.0),0.0,1.0));
	sky = mix(sky, pow(fogColor, vec3(0.4545)), rainStrength);

	return mix(color, vec3(1.0), sky);
}
