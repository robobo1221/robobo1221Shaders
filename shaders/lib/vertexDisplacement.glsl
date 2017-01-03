	
	#define WAVING_TERRAIN
	#define WAVING_LEAVES_TALLFLOWERS
	#define WAVING_PLANTS
	#define WAVING_VINES
	#define WAVING_COBWEB
	
	#ifdef WAVING_TERRAIN
	
		float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
		
		float underCover = lmcoord.t;
			underCover = clamp(pow(underCover, 15.0) * 2.0,0.0,1.0);
		
		float wavyMult = 1.0 - time[1].y * 0.5;
			wavyMult *= 1.0 + rainStrength;
			
			#ifdef WAVING_LEAVES_TALLFLOWERS
				vec3 waving1 = calcMove(worldpos.xyz, 0.0030, 0.0054, 0.0033, 0.0025, 0.0017, 0.0031,vec3(0.75,0.15,0.75), vec3(0.375,0.075,0.375)) * underCover * wavyMult;
			#endif
			
			#if defined WAVING_VINES || defined WAVING_COBWEB || defined WAVING_PLANTS
				vec3 waving2 = calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5)) * underCover * wavyMult;
			#endif
		
			#ifdef WAVING_LEAVES_TALLFLOWERS
				if ( mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2 || mc_Entity.x == ENTITY_NEWFLOWERS ) 
					{
						position.xyz += waving1;
					}
			#endif
			
			#ifdef WAVING_VINES
				if ( mc_Entity.x == ENTITY_VINES )
					{
						position.xyz += waving2;
					}
			#endif

			#ifdef WAVING_COBWEB
				if ( mc_Entity.x == ENTITY_COBWEB ) 
					{
						position.xyz += waving2 * 0.1;
					}
			#endif

			#ifdef WAVING_PLANTS
				if (istopv > 0.9) {

				if ( mc_Entity.x == ENTITY_TALLGRASS || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == ENTITY_FIRE ||
					 mc_Entity.x == ENTITY_NETHER_WART || mc_Entity.x == ENTITY_DEAD_BUSH || mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_POTATO)
					{
						position.xyz += waving2;
					}

				}
			#endif
			
		#endif