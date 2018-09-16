#version 120
#define program_shadow
#define VERTEX

varying vec2 texcoord;
varying vec4 color;

flat varying vec3 normals;
flat varying float material;

uniform mat4 shadowModelView;

attribute vec3 mc_Entity;

#include "/lib/utilities.glsl"
#include "/lib/uniform/shadowDistortion.glsl"

void main(){
	vec3 viewSpacePosition = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

	gl_Position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	gl_Position.xyz = distortShadowMap(gl_Position.xyz);

	texcoord = gl_MultiTexCoord0.xy;
	color = gl_Color;

	material = mc_Entity.x;

	normals = (gl_NormalMatrix * gl_Normal) * mat3(shadowModelView);
}
