#include "/lib/options/TAAOptions.glsl"

#if defined program_composite2 || defined program_composite3
    #include "/lib/options/cameraOptions.glsl"
    #include "/lib/options/postProcessOptions.glsl"
#endif

#if defined program_composite0 || defined program_deferred
    #include "/lib/options/skyOptions.glsl"
    #include "/lib/options/lightingOptions.glsl"
    #include "/lib/options/volumetricOptions.glsl"
#endif