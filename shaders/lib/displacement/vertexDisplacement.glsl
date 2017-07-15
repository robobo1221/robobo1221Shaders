	
#define WAVING_TERRAIN
	#define WAVING_LEAVES_TALLFLOWERS
	#define WAVING_PLANTS
	#define WAVING_VINES
	#define WAVING_COBWEB
	
	#ifdef WAVING_TERRAIN

	vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
		vec3 ret;
		float magnitude,d0,d1,d2,d3;

		magnitude = sin(pi2wt*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;

		d0 = sin(pi2wt*f0);
		d1 = sin(pi2wt*f1);
		d2 = sin(pi2wt*f2);

		ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
		ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
		ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;

		return ret;
	}

	vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {

		vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
		vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;

		return move1+move2;
	}

	vec3 doVertexDisplacement(vec3 viewpos, vec3 worldpos, vec4 lmcoord){
	
		float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
		
		float underCover = lmcoord.t;
			underCover = clamp(pow15(underCover) * 2.0,0.0,1.0);
		
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
						viewpos.xyz += waving1;
					}
			#endif
			
			#ifdef WAVING_VINES
				if ( mc_Entity.x == ENTITY_VINES )
					{
						viewpos.xyz += waving2;
					}
			#endif

			#ifdef WAVING_COBWEB
				if ( mc_Entity.x == ENTITY_COBWEB ) 
					{
						viewpos.xyz += waving2 * 0.1;
					}
			#endif

			#ifdef WAVING_PLANTS
				if (istopv > 0.9) {

				if ( mc_Entity.x == ENTITY_TALLGRASS || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == ENTITY_FIRE ||
					 mc_Entity.x == ENTITY_NETHER_WART || mc_Entity.x == ENTITY_DEAD_BUSH || mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_POTATO)
					{
						viewpos.xyz += waving2;
					}

				}
			#endif

			return viewpos;
	}
		#endif