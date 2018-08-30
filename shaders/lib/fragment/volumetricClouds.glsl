float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
    return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

float calculateCloudShape(vec3 position, vec3 windDirection, const int octaves){
    const float d = 0.5;
    const float m = 3.0;
    const float h = (d / m) / octaves;

    vec3 shiftMult = -windDirection * 0.013;

    float noise = fbm(position, shiftMult, d, m, octaves);
        noise += h;
    
    return noise;
}

float calculateCloudOD(vec3 position, const int octaves){
    if (position.y > volumetric_cloudMaxHeight || position.y < volumetric_cloudMinHeight) return 0.0;

    float wind = TIME * 0.05;
    vec3 windDirection = vec3(wind, 0.0, wind);

    vec3 cloudPos = position * 0.00045 * volumetric_cloudScale + windDirection;

    float worldHeight = position.y - volumetric_cloudMinHeight;
    float normalizedHeight = worldHeight * (1.0 / volumetric_cloudThickness);
    float heightAttenuation = clamp01(remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0) * remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0));

    float localCoverage = 1.0;

    #ifdef VC_LOCAL_COVERAGE
        localCoverage = texture2D(noisetex, (TIME * 50.0 + position.xz * volumetric_cloudScale) * 0.000001).x;
        localCoverage = clamp01(localCoverage * 5.0 - 2.0);
    #endif

    float clouds = calculateCloudShape(cloudPos, windDirection, octaves);

    clouds = clamp01(clouds * heightAttenuation * localCoverage * 2.0 - (heightAttenuation + 0.3));

    return clouds * (volumetric_cloudDensity * volumetric_cloudScale);
}

#if defined program_composite0
    float calculatePowderEffect(float od, float vDotL){
        float powder = 1.0 - exp2(-od * 2.0);
        return mix(powder, 1.0, vDotL * 0.5 + 0.5);
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

    void calculateCloudScattering(vec3 position, vec3 wLightVector, float scatterCoeff, float od, float vDotL, float transmittance, inout float directScattering, inout float indirectScattering){
        
        directScattering += scatterCoeff * calculateCloudTransmittance(position, wLightVector, 5) * calculatePowderEffect(od, vDotL) * transmittance;
        indirectScattering += scatterCoeff * calculateCloudTransmittanceSkyLight(position, vec3(0.0, 1.0, 0.0), 3) * transmittance;
    }

    vec3 calculateVolumetricClouds(vec3 backGround, vec3 worldVector, vec3 wLightVector, vec3 worldPosition, float depth, float dither){
        if ((cameraPosition.y < volumetric_cloudMinHeight && worldVector.y < 0.0) ||
            (cameraPosition.y > volumetric_cloudMaxHeight && worldVector.y > 0.0)) return backGround;

        const int steps = VC_QUALITY;
        const float rSteps = 1.0 / steps;

        vec2 bottomSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + volumetric_cloudMinHeight);
        vec2 topSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + cameraPosition.y, worldVector, sky_planetRadius + volumetric_cloudMaxHeight);

        float startDistance = max0(cameraPosition.y > volumetric_cloudMaxHeight ? topSphere.x : bottomSphere.y);
        float endDistance = max0(cameraPosition.y > volumetric_cloudMaxHeight ? bottomSphere.x : topSphere.y);

        vec3 startPosition = worldVector * startDistance;
        vec3 endPosition = worldVector * endDistance;

        float marchRange = (1.0 - clamp01((cameraPosition.y - volumetric_cloudMaxHeight) * 0.1)) * (1.0 - clamp01((volumetric_cloudMinHeight - cameraPosition.y) * 0.1));
            marchRange = mix(1.0, marchRange, float(depth >= 1.0));

        startPosition = mix(startPosition, gbufferModelViewInverse[3].xyz, marchRange);
        endPosition = mix(endPosition, worldPosition * (depth >= 1.0 ? (volumetric_cloudHeight / 160.0) * 2.0 : 1.0), marchRange);

        vec3 increment = (endPosition - startPosition) * rSteps;
        vec3 cloudPosition = increment * dither + startPosition + cameraPosition;

        float rayLength = length(increment);

        float transmittance = 1.0;
        float directScattering = 0.0;
        float indirectScattering = 0.0;

        float vDotL = dot(worldVector, wLightVector);
        float phase = calculateCloudPhase(vDotL);

        for (int i = 0; i < steps; ++i, cloudPosition += increment){
            vec3 curvedPosition = vec3(cloudPosition.x, length(cloudPosition + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, cloudPosition.z);
            float od = calculateCloudOD(curvedPosition, 4) * rayLength;
            if (od <= 0.0) continue;

            float scatterCoeff = calculateScatterIntergral(od, 1.11);

            calculateCloudScattering(curvedPosition, wLightVector, scatterCoeff, od, vDotL, transmittance, directScattering, indirectScattering);
            transmittance *= exp2(-od * 1.11 * rLOG2);
        }

        float fogDistance = clamp01(length(startPosition) * 0.00001 * volumetric_cloudScale);
        
        vec3 directLighting = directScattering * (sunColorClouds + moonColorClouds) * transitionFading * phase * TAU;
        vec3 indirectLighting = indirectScattering * skyColor * 0.25 * PI;
        vec3 scattering = directLighting + indirectLighting;

        return mix(backGround * transmittance + scattering, backGround, fogDistance);
    }
#endif

float calculateCloudShadows(vec3 position, vec3 direction, const int steps){
    const float rSteps = volumetric_cloudThickness / steps;
    float stepSize = rSteps / direction.y;

    vec3 increment = direction * stepSize;
    position += position.y <= volumetric_cloudMinHeight ? direction * (volumetric_cloudMinHeight - position.y) / direction.y : vec3(0.0);

    float transmittance = 0.0;

    for (int i = 0; i < steps; ++i, position += increment){
        transmittance += calculateCloudOD(position, 3);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * stepSize);
}