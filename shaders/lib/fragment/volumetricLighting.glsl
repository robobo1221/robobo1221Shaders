vec2 calculateVolumetricLightOD(vec3 position){
    vec3 adjustedPosition = position + cameraPosition;
    float height = adjustedPosition.y;
    vec2 od = vec2(0.0);

    vec2 rayleighMie = exp2(-height * sky_inverseScaleHeights * rLOG2);

    od += rayleighMie;
    //od.xy += exp2(-(height - 69.0) * 0.25) * vec2(500.0, 2500.0);

    return od;
}

vec3 calculateVolumeLightTransmittance(vec3 position, vec3 direction, float shadows, const int steps){
    if (shadows <= 0.0) return vec3(1.0);
    float rayLength = (25.0 / steps) / abs(direction.y);

    vec3 increment = direction * rayLength;
    position += 0.5 * increment;

    vec2 od = vec2(0.0);

    for (int i = 0; i < steps; ++i, position += increment){
        od += calculateVolumetricLightOD(position);
    }
    return exp2(-mat2x3(sky_coefficientsAttenuation) * od * rLOG2 * rayLength);
}

vec3 calculateWaterTransmittance(float depth0, float depth1){
    depth0 = depth0 * 2.0 - 1.0;
    depth1 = depth1 * 2.0 - 1.0;

    depth0 = depth0 * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
    depth1 = depth1 * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

    float propagateDepth = (depth0 - depth1) * 1e10;
    
    return exp2(-waterTransmittanceCoefficient * propagateDepth * rLOG2);
}

#if defined program_composite0
    void calculateVolumetricLightScattering(vec3 position, vec3 shadowPosition, vec3 wLightVector, mat2x3 scatterCoeffs, vec2 phase, vec3 transmittance, inout vec3 directScattering, inout vec3 indirectScattering){
        shadowPosition = remapShadowMap(shadowPosition);

        float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;
        float volumetricShadow = calculateHardShadows(shadowDepth1, shadowPosition, 0.0);

        directScattering += (scatterCoeffs * phase) * volumetricShadow * calculateVolumeLightTransmittance(position, wLightVector, volumetricShadow, 8) * transmittance;
        indirectScattering += (scatterCoeffs * vec2(0.25)) * transmittance;
    }


    void calculateVolumetricLightScatteringWater(vec3 position, vec3 shadowPosition, vec3 wLightVector, vec3 scatterCoeff, float phase, vec3 transmittance, inout vec3 directScattering, inout vec3 indirectScattering){
        shadowPosition = remapShadowMap(shadowPosition);

        float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;
        float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;

        float volumetricShadow = calculateHardShadows(shadowDepth1, shadowPosition, 0.0);
        //vec3 waterTransmittance = calculateWaterTransmittance(shadowDepth0, shadowDepth1);

        directScattering += scatterCoeff * phase * volumetricShadow * transmittance;
        indirectScattering += scatterCoeff * 0.25 * transmittance;
    }

    vec3 calculateVolumetricLight(vec3 backGround, vec3 startPosition, vec3 endPosition, vec3 wLightVector, vec3 worldVector, float dither, float ambientOcclusion, float vDotL){
        const int steps = 8;
        const float rSteps = 1.0 / steps;

        vec3 increment = (endPosition - startPosition) * rSteps;
        vec3 rayPosition = increment * dither + startPosition;

        vec3 shadowEndPosition = transMAD(shadowMatrix, endPosition);
        vec3 shadowStartPosition = transMAD(shadowMatrix, startPosition);

        vec3 shadowIncrement = (shadowEndPosition - shadowStartPosition) * rSteps;
        vec3 shadowPosition = shadowIncrement * dither + shadowStartPosition;

        float rayLength = length(increment);

        vec3 transmittance = vec3(1.0);
        vec3 directScattering = vec3(0.0);
        vec3 indirectScattering = vec3(0.0);

        vec2 phase = vec2(phaseRayleigh(vDotL), phaseG(vDotL, sky_mieg));

        for (int i = 0; i < steps; ++i, rayPosition += increment, shadowPosition += shadowIncrement){
            vec2 od = calculateVolumetricLightOD(rayPosition) * rayLength;

            mat2x3 scatterCoeffs = mat2x3(
                sky_coefficientsScattering[0] * calculateScatterIntergral(od.x, sky_coefficientsAttenuation[0]),
                sky_coefficientsScattering[1] * calculateScatterIntergral(od.y, sky_coefficientsAttenuation[1])
            );

            calculateVolumetricLightScattering(rayPosition, shadowPosition, wLightVector, scatterCoeffs, phase, transmittance, directScattering, indirectScattering);
            transmittance *= exp2(-(mat2x3(sky_coefficientsAttenuation) * od) * rLOG2);
        }

        vec3 directLighting = directScattering * (sunColor + moonColor) * transitionFading;
        vec3 indirectLighting = indirectScattering * skyColor * ambientOcclusion;
        vec3 scattering = directLighting + indirectLighting;

        return backGround * transmittance + scattering;
    }

    vec3 calculateVolumetricLightWater(vec3 backGround, vec3 startPosition, vec3 endPosition, vec3 wLightVector, vec3 worldVector, float dither, float ambientOcclusion, float vDotL){
        const int steps = 8;
        const float rSteps = 1.0 / steps;

        vec3 increment = (endPosition - startPosition) * rSteps;
        vec3 rayPosition = increment * dither + startPosition;

        vec3 shadowEndPosition = transMAD(shadowMatrix, endPosition);
        vec3 shadowStartPosition = transMAD(shadowMatrix, startPosition);

        vec3 shadowIncrement = (shadowEndPosition - shadowStartPosition) * rSteps;
        vec3 shadowPosition = shadowIncrement * dither + shadowStartPosition;

        float rayLength = length(increment);

        vec3 transmittance = vec3(1.0);
        vec3 directScattering = vec3(0.0);
        vec3 indirectScattering = vec3(0.0);

        float phase = phaseG(vDotL, 0.5);

        for (int i = 0; i < steps; ++i, rayPosition += increment, shadowPosition += shadowIncrement){
            vec3 scatterCoeff = waterScatterCoefficient * calculateScatterIntergral(rayLength, waterTransmittanceCoefficient);

            calculateVolumetricLightScatteringWater(rayPosition, shadowPosition, wLightVector, scatterCoeff, phase, transmittance, directScattering, indirectScattering);
            transmittance *= exp2(-waterTransmittanceCoefficient * rayLength * rLOG2);
        }

        vec3 directLighting = directScattering * (sunColor + moonColor) * transitionFading;
        vec3 indirectLighting = indirectScattering * skyColor * ambientOcclusion;
        vec3 scattering = directLighting + indirectLighting;

        return backGround * transmittance + scattering;
    }
#endif