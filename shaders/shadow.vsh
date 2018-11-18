#version 120
#define program_shadow
#define VERTEX

varying vec2 texcoord;
varying vec4 color;

varying vec2 lightmaps;

flat varying vec3 normals;
flat varying float material;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/vertex/vertexDisplacement.glsl"

void main(){
	texcoord = gl_MultiTexCoord0.xy;
	lightmaps = gl_MultiTexCoord1.xy * (1.0 / 255.0);
	color = gl_Color;

	material = mc_Entity.x;

	normals = (gl_NormalMatrix * gl_Normal) * mat3(shadowModelView);

	vec3 viewSpacePosition = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec3 worldPosition = doWavingPlants(transMAD(shadowModelViewInverse, viewSpacePosition));
	viewSpacePosition = transMAD(shadowModelView, worldPosition);

	gl_Position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	gl_Position.xyz = distortShadowMap(gl_Position.xyz);
}
