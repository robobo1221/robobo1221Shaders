float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
	return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

float calculatePowderEffect(float od, float vDotL){
    float powder = 1.0 - exp2(-od * 2.0);
    return mix(powder, 1.0, vDotL * 0.5 + 0.5);
}

float calculateCloudShape(vec3 position, float wind, const int octaves){
    const float d = 0.5;
    const float m = 3.0;
    const float h = (d / m) / octaves;

    float noise = fbm(position, d, m, octaves);
          noise += h;
    
    return noise;
}

float calculateCloudOD(vec3 position, const int octaves){
    if (position.y > volumetric_cloudMaxHeight || position.y < volumetric_cloudHeight) return 0.0;

    float wind = TIME * 0.025;

    vec3 cloudPos = position * 0.0005 + vec3(wind, 0.0, wind);

    float worldHeight = position.y - volumetric_cloudHeight;
    float normalizedHeight = worldHeight * (1.0 / volumetric_cloudThickness);

    float remappedHeight0 = clamp01(remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0));
    float remappedHeight1 = clamp01(remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0));
    float heightAttenuation = remappedHeight0 * remappedHeight1;

    float clouds = calculateCloudShape(cloudPos, wind, octaves);

    clouds = clamp01(clouds * heightAttenuation * 3.0 - (1.75 * remappedHeight1));

    return clouds * volumetric_cloudDensity;
}

float calculateCloudTransmittance(vec3 position, vec3 direction, const int steps){
    const float rSteps = volumetric_cloudThickness / steps;

    vec3 increment = direction * rSteps;
    position += 0.5 * increment;

    float transmittance = 0.0;

    for (int i = 0; i < steps; ++i, position += increment){
        transmittance += calculateCloudOD(position, 3);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * rSteps);
}

float calculateCloudTransmittanceSkyLight(vec3 position, const vec3 direction, const int steps){
    const float rSteps = volumetric_cloudThickness / steps;

    const vec3 increment = direction * rSteps;
    position += 0.5 * increment;

    float transmittance = 0.0;

    for (int i = 0; i < steps; ++i, position += increment){
        transmittance += calculateCloudOD(position, 2);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * rSteps * 0.25);
}

vec3 calculateCloudLighting(vec3 position, vec3 wLightVector, float scatterCoeff, float od, float phase, float vDotL){

    vec3 directLighting = (sunColorClouds + moonColorClouds) * transitionFading * calculateCloudTransmittance(position, wLightVector, 5) * 
                          phase * calculatePowderEffect(od, vDotL) * TAU;
    vec3 skyLighting = skyColor * calculateCloudTransmittanceSkyLight(position, vec3(0.0, 1.0, 0.0), 3) * 0.25 * PI;

    return scatterCoeff * ( skyLighting + directLighting);
}

#define CLOUD_MULTI_SCATTER

vec3 calculateVolumetricClouds(vec3 backGround, vec3 worldVector, vec3 wLightVector, vec3 worldPosition, float dither){
    if (worldVector.y < 0.0) return backGround;
    const int steps = 20;
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

    for (int i = 0; i < steps; ++i, cloudPosition += increment){
        vec3 curvedPosition = vec3(cloudPosition.x, length(cloudPosition + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, cloudPosition.z);
        float od = calculateCloudOD(curvedPosition, 4) * rayLength;
        if (od <= 0.0) continue;

        float scatterCoeff = calculateScatterIntergral(od, 1.11);

        scattering += calculateCloudLighting(curvedPosition, wLightVector, scatterCoeff, od, phase, vDotL) * transmittance;
        transmittance *= exp2(-od * 1.11 * rLOG2);
    }

    float fogDistance = clamp01(length(startPosition) * 0.00001);

    return mix(backGround * transmittance + scattering, backGround, fogDistance);
}
