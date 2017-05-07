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

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;
varying vec4 vtexcoordam;
varying vec4 vtexcoord;

varying vec3 normal;
varying vec3 viewVector;
varying mat3 tbnMatrix;

varying vec3 wpos;

varying float mat;
varying float dist;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

const float PI = 3.1415927;

void main(){
	mat = 1.0;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	vec2 midcoord = (mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.st-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
	vtexcoordam.st  = min(texcoord.st,midcoord-texcoordminusmid);
	vtexcoord.st    = sign(texcoordminusmid) * 0.5 + 0.5;
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;
	
	wpos = worldpos;
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	color = gl_Color;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, normal));

    tbnMatrix = transpose(mat3(tangent, binormal, normal));
	
	if (mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_COBWEB || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_DEAD_BUSH || mc_Entity.x == ENTITY_FIRE || mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2
	 || mc_Entity.x == ENTITY_LILYPAD || mc_Entity.x == ENTITY_NETHER_WART || mc_Entity.x == ENTITY_NEWFLOWERS || mc_Entity.x == ENTITY_POTATO || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == ENTITY_TALLGRASS || mc_Entity.x == ENTITY_VINES
	 || mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == 83.0 || mc_Entity.x == 39.0 || mc_Entity.x == 40.0) mat = 0.1;
	 
	if (mc_Entity.x == 50.0 || mc_Entity.x == 62.0 || mc_Entity.x == 91.0 || mc_Entity.x == 89.0 || mc_Entity.x == 124.0 || mc_Entity.x == 138.0  || mc_Entity.x == 169.0
	|| mc_Entity.x == 10.0 || mc_Entity.x == 11.0  || mc_Entity.x == 51.0 || mc_Entity.x == 198.0) mat = 0.35;
	 
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = sqrt(dot(gl_ModelViewMatrix * gl_Vertex,gl_ModelViewMatrix * gl_Vertex));
}