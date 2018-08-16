float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
	return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

float calculatePowderEffect(float od, float vDotL){
    float powder = 1.0 - exp2(-od * 2.0);
    return mix(powder, 1.0, vDotL * 0.5 + 0.5);
}

float calculateCloudShape(vec3 position, bool isLowQ, float height, float wind){
    float lowDetailNoise = 0.0;
    float highDetailNoise = 0.0;

    const float addedLowDetailNoise = (0.75 * inversesqrt(4.0));  //Total multipliers of highdetail noise devided by the squareroot of the total amount of noise

    lowDetailNoise += calculate3DNoise(position * 0.5) * 2.0;
    lowDetailNoise += calculate3DNoise(position * 2.0 - vec3(wind, 0.0, wind));

    if (isLowQ)
    {
        lowDetailNoise += addedLowDetailNoise;
        return lowDetailNoise;
    }

    highDetailNoise += calculate3DNoise(position * 8.0 - vec3(-wind, 0.0, wind)) * 0.5;
    highDetailNoise += calculate3DNoise(position * 16.0 - vec3(wind, wind * 2.0, wind)) * 0.25;
    
    return lowDetailNoise + highDetailNoise;
}

float calculateCloudOD(vec3 position, bool isLowQ){
    if (position.y > volumetric_cloudMaxHeight || position.y < volumetric_cloudHeight) return 0.0;

    float wind = TIME * 0.025;

    vec3 cloudPos = position * 0.001 + vec3(wind, 0.0, wind);

    float worldHeight = position.y - volumetric_cloudHeight;
    float normalizedHeight = worldHeight * (1.0 / volumetric_cloudThickness);

    float remappedHeight0 = remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0);
    float remappedHeight1 = remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0);
    float heightAttenuation = remappedHeight0 * remappedHeight1;

    float clouds = calculateCloudShape(cloudPos, isLowQ, remappedHeight0, wind);

    clouds = clamp01((clouds - 2.3) * heightAttenuation);

    return clouds * volumetric_cloudDensity;
}

float calculateCloudTransmittance(vec3 position, vec3 direction, const int steps){
    const float rSteps = volumetric_cloudThickness / steps;

    vec3 increment = direction * rSteps;
    position += 0.5 * increment;

    float transmittance = 0.0;

    for (int i = 0; i < steps; i++, position += increment){
        transmittance += calculateCloudOD(position, true);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * rSteps);
}

vec3 calculateCloudLighting(vec3 position, vec3 wLightVector, float od, float phase, float vDotL){

    vec3 directLighting = (sunColorClouds + moonColorClouds) * calculateCloudTransmittance(position, wLightVector, 10) * 
                          phase * calculatePowderEffect(od, vDotL) * TAU;
    vec3 skyLighting = skyColor * 0.25 * hPI;

    return (directLighting + skyLighting);
}

vec3 calculateVolumetricClouds(vec3 backGround, vec3 worldVector, vec3 wLightVector, vec3 worldPosition, float dither){
    if (worldVector.y < 0.0) return backGround;
    const int steps = 32;
    const float rSteps = 1.0 / steps;

    float vDotL = dot(worldVector, wLightVector);

    float bottomSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + volumetric_cloudHeight).y;
    float topSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + volumetric_cloudMaxHeight).y;

    vec3 startPosition = worldVector * bottomSphere;
    vec3 endPosition = worldVector * topSphere;

    vec3 increment = (endPosition - startPosition) * rSteps;
    vec3 cloudPosition = increment * dither + startPosition + cameraPosition;

    float rayLength = length(increment);

    float transmittance = 1.0;
    vec3 scattering = vec3(0.0);

    float phase = calculateCloudPhase(vDotL);

    for (int i = 0; i < steps; i++, cloudPosition += increment){
        vec3 curvedPosition = vec3(cloudPosition.x, length(cloudPosition + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, cloudPosition.z);
        float od = calculateCloudOD(curvedPosition, false) * rayLength;
        if (od <= 0.0) continue;

        float currentTransmittance = exp2(-od * 1.11 * rLOG2);

        scattering += calculateCloudLighting(curvedPosition, wLightVector, od, phase, vDotL) * calculateScatterIntergral(currentTransmittance, transmittance);
        transmittance *= currentTransmittance;
    }

    float fogDistance = clamp01(length(startPosition) * 0.00001);

    return mix(backGround * transmittance + scattering, backGround, fogDistance);
}