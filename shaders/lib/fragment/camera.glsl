//https://docs.unrealengine.com/en-us/Engine/Rendering/PostProcessEffects/AutomaticExposure

float calculateEV100(const float apertureSquared, const float shutterSpeed, const float ISO) {
    return log2(apertureSquared / shutterSpeed * 100.0 / ISO);
}

float calculateEV100AutoExposure(float avg) {
    return log2(avg * 8.0);
}

float EV100toExposure(float EV100) {
    return (1.0 / 1.2) * exp2(-EV100);
}

float calculateExposure(float avg) {
    const float aperture = CAM_APERTURE;
    const float apertureSquared = aperture * aperture;
    const float shutterSpeed = 1.0 / CAM_SHUTTER_SPEED;
    const float exposureOffset = CAM_EXPOFFSET;
    const float iso = CAM_ISO;

    avg = clamp(avg, 2.0, 4096.0);

    #ifdef CAM_MANUAL
        float exposureValue = calculateEV100(apertureSquared, shutterSpeed, iso);
    #else
        float exposureValue = calculateEV100AutoExposure(avg);
    #endif


    return EV100toExposure(exposureValue - exposureOffset);
}
