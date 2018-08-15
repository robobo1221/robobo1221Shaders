const float cloudHeight = 1600.0;
const float cloudThickness = 1000.0;
const float cloudMaxHeight = cloudHeight + cloudThickness;

#define cloudDensity 0.0075

float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
	return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

float calculateMieScatterIntergral(float currentTrans, float totalTrans){
    return -totalTrans * currentTrans + totalTrans;
}

float calculatePowderEffect(float od, float vDotL){
    float powder = 1.0 - exp2(-od * 2.0);
    return mix(powder, 1.0, vDotL * 0.5 + 0.5);
}

float phaseG(float vDotL, const float g){
    const float gg = g * g;
    return 0.25 * (1.0 - gg) * pow(gg + 1.0 - 2.0 * g * vDotL, -1.5);
}

float calculateCloudPhase(float vDotL){
    const float a = 0.7;
    const float mixer = 0.8;

    float g1 = phaseG(vDotL, 0.8 * a);
    float g2 = phaseG(vDotL, -0.5 * a);

    return mix(g2, g1, mixer);
}

float calculateCloudShape(vec3 position, bool isLowQ, float height){
    float lowDetailNoise = 0.0;
    float highDetailNoise = 0.0;

    const float addedLowDetailNoise = (0.75 * inversesqrt(4.0));  //Total multipliers of highdetail noise devided by the squareroot of the total amount of noise

    lowDetailNoise += calculate3DNoise(position * 0.5) * 2.0;
    lowDetailNoise += calculate3DNoise(position * 2.0);

    if (isLowQ)
    {
        lowDetailNoise += addedLowDetailNoise;
        return lowDetailNoise;
    }

    highDetailNoise += calculate3DNoise(position * 8.0) * 0.5;
    highDetailNoise += calculate3DNoise(position * 16.0) * 0.25;
    
    return lowDetailNoise + highDetailNoise;
}

float calculateCloudOD(vec3 position, bool isLowQ){
    if (position.y > cloudMaxHeight || position.y < cloudHeight) return 0.0;

    vec3 cloudPos = position * 0.001;

    float worldHeight = position.y - cloudHeight;
    float normalizedHeight = worldHeight * (1.0 / cloudThickness);

    float remappedHeight0 = remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0);
    float remappedHeight1 = remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0);
    float heightAttenuation = remappedHeight0 * remappedHeight1;

    float clouds = calculateCloudShape(cloudPos, isLowQ, remappedHeight0);

    clouds = clamp01((clouds - 2.3) * heightAttenuation);

    return clouds * cloudDensity;
}

float calculateCloudTransmittance(vec3 position, vec3 direction, const int steps){
    const float rSteps = cloudThickness / steps;

    vec3 increment = direction * rSteps;
    position += 0.5 * increment;

    float transmittance = 0.0;

    for (int i = 0; i < steps; i++, position += increment){
        transmittance += calculateCloudOD(position, true);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * rSteps);
}

vec3 calculateCloudLighting(vec3 position, vec3 wLightVector, float od, float phase, float vDotL){

    vec3 directLighting = (sunColor + moonColor) * calculateCloudTransmittance(position, wLightVector, 10) * 
                          phase * calculatePowderEffect(od, vDotL) * TAU;
    vec3 skyLighting = skyColor * 0.25 * hPI;

    return (directLighting + skyLighting);
}

vec3 calculateVolumetricClouds(vec3 backGround, vec3 worldVector, vec3 wLightVector, vec3 worldPosition, float dither){
    if (worldVector.y < 0.0) return backGround;
    const int steps = 32;
    const float rSteps = 1.0 / steps;

    float vDotL = dot(worldVector, wLightVector);

    float bottomSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + cloudHeight).y;
    float topSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + cloudMaxHeight).y;

    vec3 startPosition = worldVector * bottomSphere;
    vec3 endPosition = worldVector * topSphere;

    vec3 increment = (endPosition - startPosition) * rSteps;
    vec3 cloudPosition = increment * dither + startPosition + cameraPosition;

    float rayLength = length(increment);

    float transmittance = 1.0;
    vec3 scattering = vec3(0.0);

    float phase = calculateCloudPhase(vDotL);

    for (int i = 0; i < steps; i++, cloudPosition += increment){
        vec3 curvedPosition = cloudPosition;
        float od = calculateCloudOD(curvedPosition, false) * rayLength;
        if (od <= 0.0) continue;

        float currentTransmittance = exp2(-od * 1.11 * rLOG2);

        scattering += calculateCloudLighting(curvedPosition, wLightVector, od, phase, vDotL) * calculateMieScatterIntergral(currentTransmittance, transmittance);
        transmittance *= currentTransmittance;
    }

    return backGround * transmittance + scattering;
}
