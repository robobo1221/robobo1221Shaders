vec2 calculateVolumetricLightOD(vec3 position){
    vec3 adjustedPosition = position + cameraPosition;
    float height = adjustedPosition.y;
    vec2 od = vec2(0.0);

    vec2 rayleighMie = exp2(-height * sky_inverseScaleHeights * rLOG2);

    od += rayleighMie;

    return od;
}

vec3 calculateVolumeLightTransmittance(vec3 position, vec3 direction, const int steps){
    float rayLength = (100.0 / steps) / abs(direction.y);

    vec3 increment = direction * rayLength;
    position += 0.5 * increment;

    vec2 od = vec2(0.0);

    for (int i = 0; i < steps; i++, position += increment){
        od += calculateVolumetricLightOD(position);
    }
    return exp2(-mat2x3(sky_coefficientsAttenuation) * od * rLOG2 * rayLength);
}

#if defined program_composite0
    vec3 calculateVolumetricLightLighting(vec3 position, vec3 wLightVector, vec2 od, vec2 phase, mat2x3 scatterCoeffs){
        vec3 shadowPosition = transMAD(shadowMatrix, position);
            shadowPosition = remapShadowMap(shadowPosition);

        float volumetricShadow = calculateHardShadows(shadowtex0, shadowPosition, 0.0);

        vec3 directLighting = (sunColor + moonColor) * volumetricShadow * calculateVolumeLightTransmittance(position, wLightVector, 8) * TAU;
            directLighting = (scatterCoeffs * phase) * directLighting;
        vec3 skyLighting = skyColor * (scatterCoeffs * vec2(0.25)) * hPI;

        return (directLighting + skyLighting);
    }

    vec3 calculateVolumetricLight(vec3 backGround, vec3 worldPosition, vec3 wLightVector, vec3 worldVector, float dither){
        const int steps = 16;
        const float rSteps = 1.0 / steps;

        float vDotL = dot(worldVector, wLightVector);

        vec3 startPosition = gbufferModelViewInverse[3].xyz;
        vec3 endPosition = worldPosition;

        vec3 increment = (endPosition - startPosition) * rSteps;
        vec3 rayPosition = increment * dither + startPosition;

        float rayLength = length(increment);

        vec3 scattering = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        vec2 phase = vec2(phaseRayleigh(vDotL), phaseG(vDotL, sky_mieg));

        for (int i = 0; i < steps; i++, rayPosition += increment){
            vec2 od = calculateVolumetricLightOD(rayPosition) * rayLength;

            mat2x3 scatterCoeffs = mat2x3(
                sky_coefficientsScattering[0] * calculateScatterIntergral(od.x, sky_coefficientsAttenuation[0]),
                sky_coefficientsScattering[1] * calculateScatterIntergral(od.y, sky_coefficientsAttenuation[1])
            );

            scattering += calculateVolumetricLightLighting(rayPosition, wLightVector, od, phase, scatterCoeffs) * transmittance;
            transmittance *= exp2(-(mat2x3(sky_coefficientsAttenuation) * od) * rLOG2);
        }
        return backGround * transmittance + scattering;
    }
#endif