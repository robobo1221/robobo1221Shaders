#ifdef DYNAMIC_WEATHER
#endif

float getMoonphaseBasedTime(){
    return abs(0.5 - float(moonPhase) * 0.125 + float(worldTime) * 0.00000520833333334) * 2.0;
}

float getCloudCoverage(){
    #if defined VOLUMETRIC_CLOUDS && defined DYNAMIC_WEATHER
        float noiseFactor = getMoonphaseBasedTime();

        return mix(clamp(1.75f - noise1D(noiseFactor * 50.0) * 1.75f, 0.0f, 1.0f) * 0.35f + 0.65f, 1.0f, rainStrength);
    #else
        return 1.0f;
    #endif
}

float dynamicCloudCoverageMult = getCloudCoverage() / VOLUMETRIC_CLOUDS_COVERAGE;
float dynamicCloudCoverage = clamp(dynamicCloudCoverageMult, 0.0, 1.0);