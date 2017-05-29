#define VOLUMETRIC_LIGHT
	#define VL_QUALITY 	1.0	//[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0]	  		// Quality of the Volumetric Light. 1.0 is default, 10.0 recommended for quality, 20.0 best quality you can get. But eats a lot of FPS
	#define VL_DISTANCE 32.0 //[16.0 32.0 64.0 128.0 256.0 512.0]		// The draw distance of Volumetric Light
	
	#define VL_INTENSITY 1.0 //[0.5 1.0 1.5 2.0 3.0 4.0 5.0]
		#define VL_INTENSITY_SUNRISE 1.0 //[0.5 1.0 1.5 2.0 3.0 4.0 5.0]
		#define VL_INTENSITY_NOON 1.0 //[0.5 1.0 1.5 2.0 3.0 4.0 5.0]
		#define VL_INTENSITY_SUNSET 1.0 //[0.5 1.0 1.5 2.0 3.0 4.0 5.0]
		#define VL_INTENSITY_MIDNIGHT 1.0 //[0.5 1.0 1.5 2.0 3.0 4.0 5.0]
	
#define WATER_CAUSTICS   
	//#define PROJECTED_CAUSTICS //Makes caustics accurate with the shadow its casting from. But makes your game run alot slower!
	#define CAUSTIC_MULT 1.0 //[1.0 2.0 3.0 4.0 5.0]
	
#define SPECULAR_MAPPING	//Only works with specular adjusted resource packs (like chroma hills)!

#define RAIN_PUDDLES

#define POM
	#define POM_MAP_RES 128 //[8 16 32 128 256 512 1024 2048 4096 9192]
	#define POM_DEPTH 3.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
	#define OCCLUSION_POINTS 16 //[8 16 32 64 128]

#define VOLUMETRIC_CLOUDS
	#define VOLUMETRIC_CLOUDS_DENSITY 50.0 //[10.0 20.0 40.0 50.0 80.0 100.0 150.0 200.0 250.0]
	#define VOLUMETRIC_CLOUDS_COVERAGE 1.0 //[0.5 0.75 1.0 1.25 1.5 1.75 2.0]
	
#define GLOBAL_ILLUMINATION
	#define GI_MULT 1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0] Simple multiplier. Does not effect performace.
	#define GI_RADIUS 4.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0] Simple radius multiplier. Does not effect performace. Lowering this might fix under-sampling.
	#define GI_QUALITY 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0 6.0] Highering this will improve the GI quality. TOO HIGH NUMBERS CAUSES BAD FPS ISSUES! 
