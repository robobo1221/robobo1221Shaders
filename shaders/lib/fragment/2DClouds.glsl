#define a 0.5
#define b 0.25
#define c 0.7

float calculateCloudShape2D(vec2 cloudPosition, float wind, const int octaves){

    cloudPosition *= rNoiseTexRes;

    vec2 offsetMult = vec2(-wind) * 0.00002;

    vec2 offsetPos = cloudPosition;
    
    float noise = texture2D(noisetex, cloudPosition).x * 0.5;
          noise += texture2D(noisetex, cloudPosition * 3.0).x * 0.25;
          noise += texture2D(noisetex, cloudPosition * 9.0).x * 0.125;
          noise += texture2D(noisetex, cloudPosition * 27.0).x * 0.0675;
          noise += texture2D(noisetex, cloudPosition * 81.0).x * 0.03375;

    return noise;
}

float calculateCloudOD2D(vec3 position){
    float wind = TIME * 25.0;

    vec2 cloudPosition = (position.xz - wind) * 0.0002;

    float worldHeight = position.y - clouds2D_cloudHeight;
    float normalizedHeight = worldHeight * (1.0 / clouds2D_cloudThickness) + 0.5;
    float heightAttenuation = clamp01(remap(normalizedHeight, 0.0, 0.4, 0.0, 1.0) * remap(normalizedHeight, 0.6, 1.0, 1.0, 0.0));

    float clouds = calculateCloudShape2D(cloudPosition, wind, 8);
          clouds = clamp01(clouds * heightAttenuation * 4.0 - 2.25);

    return clouds * clouds2D_cloudDensity;
}

float calculateTransmittanceDepth2D(vec3 position, vec3 direction, float dither, const int steps){
    float rayLength = 7500.0 / steps;
    vec3 increment = direction * rayLength;

    position += increment * dither;

    float od = 0.0;

    for (int i = 0; i < steps; ++i, position += increment){
        od += calculateCloudOD2D(position);
    }

    return od * rayLength * 1.11 * rLOG2;
}

float calculateCloudTransmittanceDepthSky2D(vec3 position){
    float gradient = min(clouds2D_cloudHeight - position.y, clouds2D_cloudHeight) * volumetric_cloudScale * 0.01;

    return gradient * 1.11 * rLOG2 * 0.11;
}

void calculateCloudScattering2D(vec3 position, float scatterCoeff, float powder, float transmittanceDepth, float transmittanceDepthSky, float phase, float bn, inout float directScattering, inout float skylightScattering){
    directScattering += scatterCoeff * phase * powder * calculateCloudTransmittance(bn, transmittanceDepth);
    skylightScattering += scatterCoeff * calculateCloudTransmittance(bn, transmittanceDepthSky);
}

void calculateCloudScattering2D(vec3 position, vec3 wLightVector, float transmittance, float vDotL, float dither, inout float directScattering, inout float skylightScattering, const int dlSteps){
    float scatterCoeff = calculateScatterIntergral(transmittance, 1.11);

    float transmittanceDepth = calculateTransmittanceDepth2D(position, wLightVector, dither, dlSteps);
    float transmittanceDepthSky = calculateCloudTransmittanceDepthSky2D(position);

    float powder = 1.0;//calculatePowderEffect(transmittanceDepth * (1.0 / 1.11));

    for (int i = 0; i < C2D_MULTISCAT_QUALITY; ++i) {
        float n = float(i);

        float an = pow(a, n);
        float bn = pow(b, n);
        float cn = pow(c, n);

        float phase = calculateCloudPhaseCirrus(vDotL * cn);
        scatterCoeff = scatterCoeff * an;

        calculateCloudScattering2D(position, scatterCoeff, powder, transmittanceDepth, transmittanceDepthSky, phase, bn, directScattering, skylightScattering);
    }
}

vec3 calculateClouds2D(vec3 backGround, vec3 sky, vec3 worldVector, vec3 wLightVector, float dither, float vDotL, const int dlSteps){

    vec2 cloudSphere = rsi(vec3(0.0, 1.0, 0.0) * sky_planetRadius + eyeAltitude, worldVector, sky_planetRadius + clouds2D_cloudHeight);
    vec3 position = worldVector * cloudSphere.y + cameraPosition;
         position = vec3(position.x, length(position + vec3(0.0, sky_planetRadius, 0.0)) - sky_planetRadius, position.z);

    float directScattering = 0.0;
    float skylightScattering = 0.0;

    float od = calculateCloudOD2D(position);
    //if (od <= 0.0) return backGround;

    float transmittance = exp2(-od * 1.11 * rLOG2 * clouds2D_cloudThickness);

    vec3 lightingDir = normalize(wLightVector - wLightVector * dot(wLightVector, worldVector));

    calculateCloudScattering2D(position, lightingDir, transmittance, vDotL, dither, directScattering, skylightScattering, dlSteps);

    vec3 directLighting = directScattering * (sunColorClouds2D + moonColorClouds2D) * transitionFading;
    vec3 skyLighting = skylightScattering * skyColor * 0.25 * rPI;
    vec3 scattering = (directLighting + skyLighting) * PI;

    vec3 result = backGround * transmittance + scattering;

    vec3 totalFogCoeff = sky_coefficientRayleigh + sky_coefficientMie;
    float worldLength = length(position);
    vec3 fogTransmittance = clamp01(exp2(-worldLength * totalFogCoeff));
    float fogDistance = 1.0 - clamp01(exp2(-worldLength * max3(totalFogCoeff)));

    return result * fogTransmittance + sky * fogDistance;
}

#undef a
#undef b
#undef c