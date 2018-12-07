#include "/lib/options/TAAOptions.glsl"
#include "/lib/options/surfaceOptions.glsl"

#if defined program_composite2 || defined program_composite3 || defined program_final
    #include "/lib/options/cameraOptions.glsl"
    #include "/lib/options/postProcessOptions.glsl"
#endif

#if defined program_composite0 || defined program_deferred
    #include "/lib/options/skyOptions.glsl"
    #include "/lib/options/volumetricOptions.glsl"
#endif

#ifdef ADVANCED_PARALLAX_WATER
#endif