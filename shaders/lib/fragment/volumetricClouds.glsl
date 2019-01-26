const float a = 0.5;
const float b = 0.15;
const float c = 0.85;

// Maps a range of values to an different range of values.
float remap(float value, const float originalMin, const float originalMax, const float newMin, const float newMax) {
    return (((value - originalMin) / (originalMax - originalMin)) * (newMax - newMin)) + newMin;
}

// Calculate cloud noise using FBM.
float calculateCloudShape(vec3 position, vec3 windDirection, const int octaves){
    const float d = 0.5;
    const float m = 3.0;
    float h = (d / m) / octaves;

    vec3 shiftMult = -windDirection * 0.013;

    float noise = fbm(position, shiftMult, d, m, octaves);
          noise += h;

    return noise;
}

// Calculate cloud optical depth.
float calculateCloudOD(vec3 position, const int octaves){
    // Early out.
    if (position.y > volumetric_cloudMaxHeight || position.y < volumetric_cloudMinHeight) return 0.0;

    float localCoverage = 1.0;

    #ifdef VC_LOCAL_COVERAGE
        localCoverage = texture2D(noisetex, (TIME * 50.0 + position.xz * volumetric_cloudScale) * 0.000001).x;
        localCoverage = clamp01(localCoverage * 3.0 - 0.75) * 0.5 + 0.5;
    #endif

    float wind = TIME * 0.025;
    vec3 windDirection = vec3(-wind, 0.0, -wind);

    vec3 cloudPos = position * 0.00045 * volumetric_cloudScale + windDirection;

    float worldHeight = position.y - volumetric_cloudMinHeight;
    float normalizedHeight = worldHeight * (1.0 / volumetric_cloudThickness);
    float heightAttenuation = clamp01(remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0) * remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0));

    float clouds = calculateCloudShape(cloudPos, windDirection, octaves);

    // Calculate the final cloudshape.
    clouds = clamp01(clouds * heightAttenuation * localCoverage * 2.0 - (0.6 * heightAttenuation + normalizedHeight * 0.5 + 0.4));

    return clouds * (volumetric_cloudDensity * volumetric_cloudScale);
}

#if defined program_composite0 || defined program_deferred
    // Approximation for in-scattering probability.
    float calculatePowderEffect(float od, float vDotL){
        float powder = 1.0 - exp2(-od * 2.0);
        return mix(powder, 1.0, vDotL * 0.5 + 0.5);
    }

    float calculateCloudTransmittanceDepth(vec3 position, vec3 direction, const int steps){
        float rayLength = volumetric_cloudThickness / steps;

        vec3 increment = direction * rayLength;
        position += 0.5 * increment;

        float od = 0.0;

        for (int i = 0; i < steps; ++i, position += increment){
            od += calculateCloudOD(position, VC_NOISE_OCTAVES);
        }

        return od * rayLength * 1.11 * rLOG2;
    }

    float calculateCloudTransmittanceDepthSky(vec3 position){
        float gradient = min(volumetric_cloudMinHeight - position.y, volumetric_cloudMinHeight) * volumetric_cloudScale * (1.0 / volumetric_cloudThicknessMult) * 0.01;

        return gradient * 1.11 * rLOG2 * 0.11;
    }


    // Absorb sunlight through the clouds.
    float calculateCloudTransmittance(float bn, float transmittanceDepth){
        return exp2(-transmittanceDepth * bn);
    }

    // Calculate the total energy of the clouds.
    void calculateCloudScattering(vec3 position, vec3 wLightVector, float scatterCoeff, float od, float vDotL, float transmittance, float bn, float transmittanceDepth, float transmittanceDepthSky, float phase, float powder, inout float directScattering, inout float skylightScattering, const int dlSteps){

        directScattering += scatterCoeff * powder * phase * calculateCloudTransmittance(bn, transmittanceDepth) * transmittance;
        skylightScattering += scatterCoeff * calculateCloudTransmittance(bn, transmittanceDepthSky) * transmittance;
    }

    void calculateCloudScattering(vec3 position, vec3 wLightVector, float od, float vDotL, float transmittance, float stepTransmittance, inout float directScattering, inout float skylightScattering, const int dlSteps, const int msSteps){
        // Scattering intergral.
        float scatterCoeff = calculateScatterIntergral(stepTransmittance, 1.11);

        // Approximate inscattering probability
        float powder = calculatePowderEffect(od, vDotL);

        // Depth for directional transmittance
        float transmittanceDepth = calculateCloudTransmittanceDepth(position, wLightVector, dlSteps);
        float transmittanceDepthSky = calculateCloudTransmittanceDepthSky(position);

        #ifdef VC_MULTISCAT
            for (int i = 0; i < msSteps; ++i) {

                float n = float(i);

                float an = pow(a, n);
                float bn = pow(b, n);
                float cn = pow(c, n);

                // Calculate the cloud phase.
                float phase = calculateCloudPhase(vDotL * cn);
                scatterCoeff = scatterCoeff * an;

                calculateCloudScattering(position, wLightVector, scatterCoeff, od, vDotL, transmittance, bn, transmittanceDepth, transmittanceDepthSky, phase, powder, directScattering, skylightScattering, dlSteps);
            }
        #else
            calculateCloudScattering(position, wLightVector, scatterCoeff, od, vDotL, transmittance, 1.0, transmittanceDepth, transmittanceDepthSky, 1.0, powder, directScattering, skylightScattering, dlSteps);
        #endif
    }

    vec3 calculateVolumetricClouds(vec3 backGround, vec3 sky, vec3 worldVector, vec3 wLightVector, vec3 worldPosition, float depth, vec2 planetSphere, float dither, float vDotL, const int steps, const int dlSteps, const int alSteps){

        // Marches per pixel.
        float rSteps = 1.0 / steps;

        const int msSteps = VC_MULTISCAT_QUALITY;

        // Early out when the clouds are behind the horizon or not visible.
        if ((eyeAltitude < volumetric_cloudMinHeight && planetSphere.y > 0.0) ||
            (eyeAltitude > volumetric_cloudMaxHeight && worldVector.y > 0.0)) return backGround;

        // Calculate the cloud spheres.
        vec2 bottomSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + eyeAltitude, worldVector, sky_planetRadius + volumetric_cloudMinHeight);
        vec2 topSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + eyeAltitude, worldVector, sky_planetRadius + volumetric_cloudMaxHeight);

        // Get the distance from the eye to the start and endposition.
        float startDistance = (eyeAltitude > volumetric_cloudMaxHeight ? topSphere.x : bottomSphere.y);
        float endDistance = (eyeAltitude > volumetric_cloudMaxHeight ? bottomSphere.x : topSphere.y);

        // Multiply the direction and distance by eachother to.
        vec3 startPosition = worldVector * startDistance;
        vec3 endPosition = worldVector * endDistance;

        // Calculate the range of when the player is flying through the clouds.
        float marchRange = (1.0 - clamp01((eyeAltitude - volumetric_cloudMaxHeight) * 0.1)) * (1.0 - clamp01((volumetric_cloudMinHeight - eyeAltitude) * 0.1));
              marchRange = mix(1.0, marchRange, float(depth >= 1.0));

        // Change the raymarcher's start and endposition when you fly through them or when geometry is behind it.
        startPosition = mix(startPosition, gbufferModelViewInverse[3].xyz, marchRange);
        endPosition = mix(endPosition, worldPosition * (depth >= 1.0 ? (volumetric_cloudHeight / 32.0) : 1.0), marchRange);

        // Curve the cloud position around the Earth.
        startPosition = vec3(startPosition.x, length(startPosition + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, startPosition.z);
        endPosition = vec3(endPosition.x, length(endPosition + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, endPosition.z);

        // Calculate the ray increment and the ray position.
        vec3 increment = (endPosition - startPosition) * rSteps;
        vec3 cloudPosition = increment * dither + startPosition + cameraPosition;

        float rayLength = length(increment);

        float transmittance = 1.0;
        float directScattering = 0.0;
        float skylightScattering = 0.0;

        // Calculate the cloud phase.
        #ifdef VC_MULTISCAT
            float phase = 1.0;
        #else
            float phase = calculateCloudPhase(vDotL);
        #endif

        float cloudDepth = 0.0;

        // Raymarching.
        for (int i = 0; i < steps; ++i, cloudPosition += increment){
            float od = calculateCloudOD(cloudPosition, VC_NOISE_OCTAVES) * rayLength;
            // Early out.
            if (od <= 0.0) continue;

            //float rayDepth = length(cloudPosition);
            //cloudDepth = cloudDepth < rayDepth - cloudDepth && cloudDepth <= 0.0 ? rayDepth : cloudDepth;

            float stepTransmittance = exp2(-od * 1.11 * rLOG2);
            calculateCloudScattering(cloudPosition, wLightVector, od, vDotL, transmittance, stepTransmittance, directScattering, skylightScattering, dlSteps, msSteps);

            transmittance *= stepTransmittance;
        }

        //if (cloudDepth <= 0.0) return backGround;
        startDistance = mix(startDistance, 0.0, marchRange);

        // Light the scattering and sum them up.
        vec3 directLighting = directScattering * (sunColorClouds + moonColorClouds) * transitionFading;

        #ifndef VC_MULTISCAT
            directLighting *= phase;
        #endif

        vec3 skyLighting = skylightScattering * skyColor * 0.25 * rPI;
        vec3 scattering = (directLighting + skyLighting) * PI;

        // Apply the scattering to the already excisting image. And gamma correct it.
        vec3 endResult = backGround * transmittance + scattering;

		vec3 totalFogCoeff = sky_coefficientRayleigh + sky_coefficientMie;

        vec3 fogTransmittance = clamp01(exp2(-startDistance * totalFogCoeff));
        float fogDistance = 1.0 - clamp01(exp2(-startDistance * max3(totalFogCoeff)));

        // Blend the clouds with the sky based on distance and returning the result.
        return endResult * fogTransmittance + sky * fogDistance;
    }
#endif

// Absorb sunlight through the clouds.
float calculateCloudShadows(vec3 position, vec3 direction, const int steps){
    #ifndef VC_SHADOWS
        return 1.0;
    #endif

    float rSteps = volumetric_cloudThickness / steps;
    float stepSize = rSteps / abs(direction.y);

    vec3 increment = direction * stepSize;

    float fade = smoothstep(0.125, 0.075, abs(direction.y));

    // Make sure the shadows keep on going even after we absorbed through the cloud.
    position += position.y <= volumetric_cloudMinHeight ? direction * (volumetric_cloudMinHeight - position.y) / direction.y : vec3(0.0);

    float transmittance = 0.0;

    for (int i = 0; i < steps; ++i, position += increment){
        transmittance += calculateCloudOD(position, 3);
    }
    return exp2(-transmittance * 1.11 * rLOG2 * stepSize) * (1.0 - fade) + fade;
}
