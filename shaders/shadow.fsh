#version 120
#define program_shadow
#define FRAGMENT

varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;

varying vec2 lightmaps;

flat varying float material;
flat varying vec3 normals;

varying vec3 worldPosition;

uniform sampler2D tex;
//uniform sampler2D noisetex;

//uniform vec3 cameraPosition;
//uniform float frameTimeCounter;

#include "/lib/utilities.glsl"
//#include "/lib/fragment/waterWaves.glsl"

/* DRAWBUFFERS:01 */
void main()
{
	//if(!gl_FrontFacing) discard;

	vec4 albedo = texture2D(tex, texcoord) * color;

	if (albedo.a == 0.0) discard;
	
	bool isWater = material == 8 || material == 9;

	vec3 normal = vec3(0.0, 0.0, 1.0);
	albedo = isWater ? vec4(1.0, 1.0, 1.0, 0.0) : albedo;
	
	/*if (isWater) {
		vec3 waveCoord = worldPosition + cameraPosition;
			
		normal = calculateWaveNormals(waveCoord);
	}*/

	#ifdef WHITE_WORLD
		albedo.rgb = vec3(1.0);
	#endif

	gl_FragData[0] = vec4(albedo.rgb * (albedo.a < 1.0 ? (1.0 - albedo.a) : 1.0), lightmaps.y * 0.5 + 0.5);
	gl_FragData[1] = vec4((tbn * normal) * 0.5 + 0.5, float(isWater) * 0.5 + 0.5);
}
