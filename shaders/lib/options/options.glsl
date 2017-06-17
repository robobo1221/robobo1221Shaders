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
	//#define DYNAMIC_WEATHER 																						//Makes volumetric cloud's coverage different over time. Also effects other shaders such as lighting, fog, etc.
	#define VOLUMETRIC_CLOUDS_DENSITY 50.0 //[10.0 20.0 40.0 50.0 80.0 100.0 150.0 200.0 250.0]						//Density of the volumetric clouds
	#define VOLUMETRIC_CLOUDS_COVERAGE 1.0 //[0.5 0.75 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.5 1.75 2.0]		//Coverage of volumetric clouds. Higher values result in a more clouded day.
	#define VOLUMETRIC_CLOUDS_QUALITY 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0]										//The quality of the volumetric clouds. Higher this value up to get better quality volumetric clouds. FPS intensive!
	#define VOLUMETRIC_CLOUDS_HEIGHT 150.0 //[100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0]	//Height of the volumetric clouds in blocks.
	#define VOLUMETRIC_CLOUDS_THICKNESS 100.0 //[25.0 50.0 75.0 100.0 125.0 150.0 175.0 200.0]						//Thickness of the volumetric clouds in blocks.
	
#define GLOBAL_ILLUMINATION
	#define GI_MULT 1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0] Simple multiplier. Does not effect performace.
	#define GI_RADIUS 4.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0] Simple radius multiplier. Does not effect performace. Lowering this might fix under-sampling.
	#define GI_QUALITY 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0 6.0] Highering this will improve the GI quality. TOO HIGH NUMBERS CAUSES BAD FPS ISSUES! 

#define WATER_DEPTH_FOG
	#define DEPTH_FOG_DENSITY 0.2 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
	#define UNDERWATER_FOG
