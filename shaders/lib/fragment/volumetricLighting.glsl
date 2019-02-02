vec2 calculateVolumetricLightOD(vec3 position){
    vec3 adjustedPosition = position + cameraPosition;
    float height = adjustedPosition.y;
    vec2 od = vec2(0.0);

    vec2 rayleighMie = exp2(-max0(height - 63.0) * sky_inverseScaleHeights * rLOG2 * vec2(ATMOSPHERE_SCALE, 1.0)) * ATMOSPHERE_SCALE;

    od += rayleighMie;
    //od.xy += exp2(-(height - 62.0) * 0.2) * vec2(500.0, 2500.0) * 3.0;

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

vec3 calculateWaterTransmittance(vec3 worldPosition, float shadowWaterMask, float depth0, float depth1){
    float waterDepth = (depth0 * 8.0 - 4.0);
          waterDepth = waterDepth * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;
		  waterDepth = (waterDepth - transMAD(shadowModelView, worldPosition).z);

    if (waterDepth < 0.0) return vec3(1.0);

          waterDepth = mix(0.0, waterDepth, shadowWaterMask);
    
    return exp2(-waterTransmittanceCoefficient * waterDepth * rLOG2);
}

#if defined program_composite0
    void calculateVolumetricLightScattering(vec3 position, vec3 shadowPosition, vec3 wLightVector, mat2x3 scatterCoeffs, vec2 phase, vec3 transmittance, inout vec3 directScattering, inout vec3 indirectScattering){
        shadowPosition = remapShadowMap(shadowPosition);

        float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;
        float volumetricShadow = calculateHardShadows(shadowDepth1, shadowPosition, 0.0);

        directScattering += (scatterCoeffs * phase) * volumetricShadow * calculateVolumeLightTransmittance(position, wLightVector, volumetricShadow, 8) * transmittance;
        indirectScattering += (scatterCoeffs * vec2(0.25)) * transmittance;
    }

    void calculateVolumetricLightScatteringWater(vec3 position, vec3 shadowPosition, vec3 wLightVector, vec3 transmittance, inout vec3 directScattering, inout vec3 indirectScattering){
        shadowPosition = remapShadowMap(shadowPosition);

        float shadowDepth0 = texture2D(shadowtex0, shadowPosition.xy).x;
        float shadowDepth1 = texture2D(shadowtex1, shadowPosition.xy).x;
        vec4 shadowColor1 = texture2D(shadowcolor1, shadowPosition.xy);

        float shadowWaterMask = shadowColor1.a * 2.0 - 1.0;

        float volumetricShadow = calculateHardShadows(shadowDepth1, shadowPosition, 0.0);
        vec3 waterTransmittance = calculateWaterTransmittance(position, shadowWaterMask, shadowDepth0, shadowDepth1);

        directScattering += volumetricShadow * transmittance * waterTransmittance;
        indirectScattering += transmittance;
    }

    vec3 calculateVolumetricLight(vec3 backGround, vec3 startPosition, vec3 endPosition, vec3 wLightVector, vec3 worldVector, float dither, float ambientOcclusion, float vDotL){
        #ifndef VOLUMETRIC_LIGHT
            return backGround;
        #endif

        const int steps = VL_QUALITY;
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
        vec3 indirectLighting = indirectScattering * skyColor * ambientOcclusion * hPI;
        vec3 scattering = directLighting + indirectLighting;

        return backGround * transmittance + scattering;
    }

    vec3 calculateVolumetricLightWater(vec3 backGround, vec3 startPosition, vec3 endPosition, vec3 wLightVector, vec3 worldVector, float dither, float ambientOcclusion, float vDotL){
        #ifndef VOLUMETRIC_LIGHT_WATER
            return backGround * exp2(-waterTransmittanceCoefficient * length(endPosition - startPosition) * rLOG2);
        #endif

        const int steps = VL_WATER_QUALITY;
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

        vec3 scatterCoeff = waterScatterCoefficient * calculateScatterIntergral(rayLength, waterTransmittanceCoefficient);
        vec3 stepTransmittance = exp2(-waterTransmittanceCoefficient * rayLength * rLOG2);

        for (int i = 0; i < steps; ++i, rayPosition += increment, shadowPosition += shadowIncrement){

            calculateVolumetricLightScatteringWater(rayPosition, shadowPosition, wLightVector, transmittance, directScattering, indirectScattering);
            transmittance *= stepTransmittance;
        }

        vec3 directLighting = phase * directScattering * (sunColor + moonColor) * transitionFading;
        vec3 indirectLighting = 0.25 * indirectScattering * skyColor * ambientOcclusion * hPI;
        vec3 scattering = (directLighting + indirectLighting) * scatterCoeff;

        return backGround * transmittance + scattering;
    }
#endif