#version 120
vec4 waterColor = vec4(1.0,1.0,1.0,0.11);

#define PRALLAX_WATER //Makes waves on water look 3D
	#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
	#define PW_POINTS 16 //[8 12 16 32]

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;

varying vec4 verts;

varying vec3 wpos;

varying float mat;

uniform sampler2D texture;

uniform float frameTimeCounter;

#include "lib/noise.glsl"
#include "lib/waterBump.glsl"

#ifdef PRALLAX_WATER
	vec2 paralaxCoords(vec3 pos, vec3 tangentVector, float iswater) {
		float waveZ = mix(2.0,0.25,iswater);
		float waveM = mix(0.0,2.0,iswater);
		float waveS = mix(0.0,1.0,iswater) * PW_DEPTH;

		float waterHeight = getWaterBump(pos.xz - pos.y, waveM, waveZ, iswater) * 2.0;
		
		vec3 paralaxCoord = vec3(0.0, 0.0, 1.0);
		vec3 stepSize = vec3(waveS, waveS, 1.0);
		vec3 step = tangentVector * stepSize;
		
		const int steps = int(PW_POINTS);
		
		for (int i = 0; waterHeight < paralaxCoord.z && i < steps; i++) {
			paralaxCoord.xy = paralaxCoord.xy + step.xy * clamp((paralaxCoord.z - waterHeight) / (stepSize.z * 0.2f / (-tangentVector.z + 0.05f)), 0.0, 1.0);
			paralaxCoord.z += step.z;
			vec3 paralaxPosition = pos + vec3(paralaxCoord.x, 0.0f, paralaxCoord.y);
			waterHeight = getWaterBump(paralaxPosition.xz - paralaxPosition.y, waveM, waveZ, iswater) * 2.0;
		}
		pos += vec3(paralaxCoord.x, 0.0f, paralaxCoord.y);
		return pos.xz - pos.y;
	}
#endif

void main(){
	float iswater = float(mat > 0.1 && mat < 0.29);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
	  tangent.y, binormal.y, normal.y,
	  tangent.z, binormal.z, normal.z);
	
	vec3 posxz = wpos.xyz;
	
	vec4 modelView = gl_ModelViewMatrix * verts;
		vec3 tangentVector = normalize(tbnMatrix * modelView.xyz);
	
	#ifdef PRALLAX_WATER	
		posxz.xz = paralaxCoords(posxz, tangentVector, iswater);
	#endif

	vec4 albedo = texture2D(texture, texcoord.st);
	albedo = mix(albedo * color, waterColor, iswater);
	
	vec3 bump;
		bump = getWaveHeight(posxz.xz - posxz.y,iswater);
	
	const float bumpmult = 0.1;
	
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
						  
	vec4 normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
	#include "lib/lmCoord.glsl"
	
/* DRAWBUFFERS:531 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = normalTangentSpace;
	gl_FragData[2] = vec4(lightmaps.x, mat, lightmaps.y, 1.0);
	
}