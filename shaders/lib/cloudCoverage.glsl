#ifdef DYNAMIC_WEATHER
#endif

float rand(float n){return fract(sin(n) * 43758.5453123);}

float noise1D(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

float getCloudCoverage(){
    #if defined VOLUMETRIC_CLOUDS && defined DYNAMIC_WEATHER
        return mix((1.0f - noise1D(frameTimeCounter * 0.002)) * 0.4f + 0.6f, 1.0f, rainStrength);
    #else
        return 1.0f;
    #endif
}

float dynamicCloudCoverage = getCloudCoverage();