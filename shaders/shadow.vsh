#version 120

#define ENTITY_LEAVES        18.0
#define ENTITY_VINES        106.0
#define ENTITY_TALLGRASS     31.0
#define ENTITY_DANDELION     37.0
#define ENTITY_ROSE          38.0
#define ENTITY_WHEAT         59.0
#define ENTITY_LILYPAD      111.0
#define ENTITY_FIRE          51.0
#define ENTITY_LAVAFLOWING   10.0
#define ENTITY_LAVASTILL     11.0
#define ENTITY_LEAVES2		161.0
#define ENTITY_NEWFLOWERS	175.0
#define ENTITY_NETHER_WART	115.0
#define ENTITY_DEAD_BUSH	 32.0
#define ENTITY_CARROT		141.0
#define ENTITY_POTATO		142.0
#define ENTITY_COBWEB		 30.0

#define SHADOW_BIAS 0.85

varying vec4 texcoord;
varying vec4 color;

varying vec2 lmcoord;

varying float iswater;
varying float translucentBlocks;

varying vec3 worldpos;
varying vec3 normal;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform int worldTime;

#include "lib/options.glsl"

float timefract = worldTime;

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f)),
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),
				
				vec2(
				
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and mindight.

const float PI = 3.1415927;

float pi2wt = PI*2*(frameTimeCounter*24);

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


vec4 BiasShadowProjection(vec4 position) {

	vec2 pos = abs(position.xy * 1.2);
	float dist = pow(pow(pos.x, 8.) + pow(pos.y, 8.), 1.0 / 8.0);

	float distortFactor = (1.0 - SHADOW_BIAS) + dist * SHADOW_BIAS;
	
	position.xy /= distortFactor;
	
	position.z /= 2.5;

	
	return position;
}

void main(){
	float bockID = mc_Entity.x;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	
	vec4 position = ftransform();
	
	position = shadowProjectionInverse * position;
	position = shadowModelViewInverse * position;
	
	worldpos = position.xyz + cameraPosition;
	
	#include "lib/vertexDisplacement.glsl"
	
	position = shadowModelView * position;
	position = shadowProjection * position;
	
	gl_Position = BiasShadowProjection(position);
	
	color = gl_Color;
		
	iswater = 0.0;
	translucentBlocks = 0.0;
	
	iswater = float(bockID == 8.0 || bockID == 9.0);
	translucentBlocks = float(bockID == 95.0 || bockID == 165.0 || bockID == 160.0);
		
	#if !defined PROJECTED_CAUSTICS || !defined WATER_CAUSTICS
		gl_Position *= 1.0 - iswater;
	#endif

	normal = normalize(gl_NormalMatrix * gl_Normal);
}