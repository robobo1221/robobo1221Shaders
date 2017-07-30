#version 120
#include "lib/util/fastMath.glsl"

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

#define SHADOW_DISTORTION 0.85

varying vec4 texcoord;
varying vec4 color;

varying vec4 lmcoord;

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

#include "lib/options/options.glsl"

float timefract = worldTime;

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) * 0.001f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f) * 0.0005)),
				((clamp(timefract, 0.0f, 2000.0f)) * 0.0005) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) * 0.000333333333333)),
				
				vec2(
				
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) * 0.000333333333333) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) * 0.00133333333333),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) * 0.00133333333333) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) * 0.001))
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and mindight.

const float PI = 3.1415927;

float pi2wt = PI*2*(frameTimeCounter*24);

#include "lib/displacement/vertexDisplacement.glsl"

vec3 BiasShadowProjection(vec3 position) {

	vec2 pos = abs(position.xy * 1.2);
	float dist = pow(pow8(pos.x) + pow8(pos.y), 0.125);

	position.xy /= mix(1.0, dist, SHADOW_DISTORTION);
	position.z *= 0.4;

	
	return position;
}

void main(){
	float bockID = mc_Entity.x;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	vec3 viewpos = ftransform().rgb;
	
	viewpos = projMAD3(shadowProjectionInverse, viewpos);
	viewpos = transMAD(shadowModelViewInverse, viewpos);
	
	worldpos = viewpos + cameraPosition;
	viewpos = doVertexDisplacement(viewpos, worldpos, lmcoord);
	
	viewpos = transMAD(shadowModelView, viewpos);
	viewpos = projMAD3(shadowProjection, viewpos);
	
	gl_Position = vec4(BiasShadowProjection(viewpos), 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);
	
	color = gl_Color;
		
	iswater = 0.0;
	translucentBlocks = 0.0;
	
	iswater = float(bockID == 8.0 || bockID == 9.0);
	translucentBlocks = float(bockID == 95.0 || bockID == 165.0 || bockID == 160.0);
}