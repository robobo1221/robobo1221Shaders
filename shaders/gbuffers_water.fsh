#version 120
vec4 waterColor = vec4(1.0,1.0,1.0,0.11);

#define PRALLAX_WATER //Makes waves on water look 3D
	#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
	#define PW_POINTS 6 //[4 6 8 16 32]

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;

varying vec3 viewVector;
varying vec3 wpos;

varying float dist;
varying float mat;

uniform sampler2D texture;

uniform float frameTimeCounter;
#include "lib/noise.glsl"
#include "lib/waterBump.glsl"

#ifdef PRALLAX_WATER
vec3 getParallaxDisplacement(vec3 posxz, float iswater) {

	float waveZ = mix(2.0,0.25,iswater);
	float waveM = mix(0.0,2.0,iswater);

	const int steps = PW_POINTS;

	vec3 parallaxPos = posxz;
	float waterHeight = getWaterBump(posxz.xz - posxz.y, waveM, waveZ, iswater) * 0.5;
	
	for(int i = 0; i < steps; i++){
		parallaxPos.xz += waterHeight * viewVector.xy / dist * (1.0 / float(steps)) * 22.0 * PW_DEPTH;
		waterHeight = getWaterBump(parallaxPos.xz - parallaxPos.y, waveM, waveZ, iswater) * 0.5;
	}
	return parallaxPos;
}
#endif

void main(){
	float iswater = float(mat > 0.1 && mat < 0.29);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
	  tangent.y, binormal.y, normal.y,
	  tangent.z, binormal.z, normal.z);
	
	vec3 posxz = wpos.xyz;
	
	#ifdef PRALLAX_WATER	
		posxz = getParallaxDisplacement(posxz, iswater);
	#endif

	vec4 albedo = texture2D(texture, texcoord.st);
	albedo = mix(albedo * color, waterColor, iswater);
	
	vec3 bump;
		bump = getWaveHeight(posxz.xz - posxz.y,iswater);
	
	const float bumpmult = 0.13457;
	
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
						  
	vec4 normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
	#include "lib/lmCoord.glsl"
	
/* DRAWBUFFERS:531 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = normalTangentSpace;
	gl_FragData[2] = vec4(lightmaps.x, mat, lightmaps.y, 1.0);
	
}