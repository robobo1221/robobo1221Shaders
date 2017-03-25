const float pi = 3.141592653589793238462643383279502884197169;
#define c max(cosViewSunAngle, 0.0)

float RayleighPhase(float cosViewSunAngle)
{
	/*
	Rayleigh phase function.
			   3
	p(θ) =	________   [1 + cos(θ)^2]
			   16π
	*/

	return (3.0 / (16.0 * pi)) * (c*c + 1.0);
}

#undef c

float hgPhase(float cosViewSunAngle, float g)
{

	/*
	Henyey-Greenstein phase function.
			   1		 		1 − g^2 
	p(θ) =	________   ____________________________
			   4π		[1 + g^2 − 2g cos(θ)]^(3/2)
	*/


	return (1.0 / (4.0 * pi)) * ((1.0 - g*g) / (1.0 + g*g) - 2.0*g * cosViewSunAngle, 1.5);
}

vec3 totalMie(vec3 lambda, vec3 K, float T, float v)
{
	float c = (0.2 * T ) * 10E-18;
	return 0.4343 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
}

vec3 totalRayleigh(vec3 lambda, float n, float N, float pn){
	return (24.0 * pow(pi, 3.0) * ((n*n - 1.0) * (n*n - 1.0)) * (6.0 + 3.0 * pn))
	/ (N * pow(lambda, vec3(4.0)) * ((n*n + 2.0) * (n*n + 2.0)) * (6.0 - 7.0 * pn));
}

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

vec3 ToneMap(vec3 color, vec3 sunPos) {
    vec3 toneMappedColor;

    toneMappedColor = color * 0.04;
    toneMappedColor = Uncharted2Tonemap(toneMappedColor);

    float sunfade = 1.0-clamp(1.0-exp(-(sunPos.z/500.0)),0.0,1.0);
    toneMappedColor = pow(toneMappedColor,vec3(1.0/(1.2+(1.2*sunfade))));

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

/*
float fakeMie(vec3 fragpos){
	return pow(dot(normalize(fragpos), sunVec) * 0.5 + 0.5, pi * 10.0);
}

vec3 getFakeRayLeigh(vec3 fragpos){
	vec3 fogColor = vec3(0.3, 0.5, 1.0);
		fogColor = mix(fogColor, vec3(dot(fogColor, vec3(0.33333))), 0.2);
		
	vec3 uVec = normalize(fragpos);
		
	float horizon = 0.4 / max(dot(uVec, upVec), 0.0);
	
	horizon = clamp(horizon, 0.0, 100.0);

	vec3 color = fogColor * horizon;
	
	color = mix(color, color / 0.5 + color, -0.3);
	vec3 rayleigh = pow(color, 1.0 - color);
	
	color = mix(rayleigh / (0.5 + rayleigh), color / (0.5 + color), clamp(dot(sunVec, upVec) * 0.95 + 0.05, 0.0, 1.0));
	color = mix(color, vec3(0.0), 1.0 - clamp(dot(sunVec, upVec) * 0.8 + 0.2, 0.0, 1.0));
	
	color *= 1.0 + pow(dot(uVec, sunVec) * 0.5 + 0.5, 2.0);
	color += sunlight * fakeMie(fragpos) * clamp(dot(sunVec, upVec) * 0.95 + 0.05, 0.0, 1.0);
	
	color = color / (0.5 + color);
	
	return clamp(color, 0.0, 1.0);
	
}
*/

vec3 getAtmosphericScattering(vec3 color, vec3 fragpos, float sunMoonMult, vec3 fogColor, out vec3 sunMax, out float moonMax){

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	float turbidity = 1.5;
	float rayleighCoefficient = 2.0;

	// constants for mie scattering
	const float mieCoefficient = 0.005;
	const float mieDirectionalG = 0.75;
	const float v = 4.0;

	// Wavelength of the primary colors RGB in nanometers.
	const vec3 primaryWavelengths = vec3(650, 550, 450) * 1.0E-9;
	
	float n = 1.00029; // refractive index of air
	float N = 2.54743E25; // number of molecules per unit volume for air at 288.15K and 1013mb (sea level -45 celsius)
	float pn = 0.03;	// depolarization factor for standard air

	// optical length at zenith for molecules
	float rayleighZenithLength = 8.4E3 ;
	float mieZenithLength = 1.25E3;
	
	const vec3 K = vec3(0.686, 0.678, 0.666);

	float sunIntensity = 1000.0;

	// earth shadow hack
	float cutoffAngle = pi * 0.5128205128205128;
	float steepness = 1.5;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Cos Angles
	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float cosSunUpAngle = dot(sunVec, upVec) * 0.95 + 0.05; //Has a lower offset making it scatter when sun is below the horizon.
	float cosUpViewAngle = dot(upVec, normalize(fragpos.rgb));

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness);  // Get sun intensity based on how high in the sky it is
	
	vec3 totalRayleigh = totalRayleigh(primaryWavelengths, n, N, pn);

	vec3 rayleighAtX = totalRayleigh * rayleighCoefficient;

	vec3 mieAtX = totalMie(primaryWavelengths, K, turbidity, v) * mieCoefficient;

	float zenithAngle = max(0.0, cosUpViewAngle);

	float rayleighOpticalLength = rayleighZenithLength / zenithAngle;
	float mieOpticalLength = mieZenithLength / zenithAngle;

	vec3 Fex = exp(-(rayleighAtX * rayleighOpticalLength + mieAtX * mieOpticalLength));
	vec3 Fexsun = vec3(exp(-(rayleighCoefficient * 0.00002853075 * rayleighOpticalLength + mieAtX * mieOpticalLength)));

	vec3 rayleighXtoEye = rayleighAtX * RayleighPhase(cosViewSunAngle);
	vec3 mieXtoEye = mieAtX * hgPhase(cosViewSunAngle , mieDirectionalG);

	vec3 totalLightAtX = rayleighAtX + mieAtX;
	vec3 lightFromXtoEye = rayleighXtoEye + mieXtoEye;

	vec3 scattering = sunE * (lightFromXtoEye / totalLightAtX);

	vec3 sky = scattering * (1.0 - Fex);
	sky *= mix(vec3(1.0),sqrt(scattering * Fex),clamp(pow(1.0-cosSunUpAngle,5.0),0.0,1.0));

	vec3 sun = K * calcSun(fragpos, sunVec);
	vec3 moon = pow(moonlight, vec3(0.4545)) * calcMoon(fragpos, moonVec);

	sunMax = sunE * pow(mix(Fexsun, Fex, clamp(pow(1.0-cosUpViewAngle,4.0),0.0,1.0)), vec3(0.4545))
	* mix(0.000005, 0.00003, clamp(pow(1.0-cosSunUpAngle,3.0),0.0,1.0)) * (1.0 - rainStrength);

	moonMax = pow(clamp(cosUpViewAngle,0.0,1.0), 0.8) * (1.0 - rainStrength);

	sky = max(ToneMap(sky, sunVec), 0.0) + (sun * sunMax + moon * moonMax) * sunMoonMult;

	float nightLightScattering = pow(max(1.0 - max(cosUpViewAngle, 0.0 ),0.0), 2.0);

	sky += pow(fogColor * 0.5, vec3(0.4545)) * ((nightLightScattering + 0.5 * (1.0 - nightLightScattering)) * clamp(pow(1.0-cosSunUpAngle,35.0),0.0,1.0));

	color = mix(sky, pow(fogColor, vec3(0.4545)), rainStrength);
	
	//color = getFakeRayLeigh(fragpos) + (sun * sunMax + moon * moonMax) * sunMoonMult;

	return color;
}
