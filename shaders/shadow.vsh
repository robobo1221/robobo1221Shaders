#version 120
#define program_shadow
#define VERTEX

varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;

varying vec2 lightmaps;

flat varying vec3 normals;
flat varying float material;

varying vec3 worldPosition;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/vertex/vertexDisplacement.glsl"

void main(){
	texcoord = gl_MultiTexCoord0.xy;
	lightmaps = gl_MultiTexCoord1.xy * (1.0 / 255.0);
	color = gl_Color;

	vec3 viewSpacePosition = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

	worldPosition = doWavingPlants(transMAD(shadowModelViewInverse, viewSpacePosition));
	viewSpacePosition = transMAD(shadowModelView, worldPosition);

	vec4 position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		 position.xyz = distortShadowMap(position.xyz);

	gl_Position = position;

	material = mc_Entity.x;

	normals = (gl_NormalMatrix * gl_Normal);
	vec3 tangent = gl_NormalMatrix * (at_tangent.xyz / at_tangent.w);

	tbn = mat3(tangent, cross(tangent, normals), normals);
}
