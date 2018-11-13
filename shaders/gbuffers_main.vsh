varying vec2 texcoord;
varying vec4 color;

flat varying mat3 tbn;
flat varying vec3 tangentVec;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

varying vec3 worldPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

#include "/lib/utilities.glsl"
#include "/lib/uniform/TemporalJitter.glsl"

void main() {
	vec3 viewSpacePosition = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	gl_Position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
	gl_Position.xy += calculateTemporalJitter() * gl_Position.w;

	worldPosition = transMAD(gbufferModelViewInverse, viewSpacePosition);

	material = mc_Entity.x;

	texcoord = gl_MultiTexCoord0.xy;
	lightmaps = gl_MultiTexCoord1.xy * (1.0 / 255.0) * vec2(1.0, gl_Color.a * 0.5 + 0.5);
	color = vec4(gl_Color.rgb, 1.0);

	#if defined program_gbuffers_terrain
	    // lit block fix
		lightmaps.x = material == 89.0 || material == 169.0 || material == 124.0
		|| material == 51.0 || material == 10.0 || material == 11.0 ? 1.0 : lightmaps.x;
	#endif

	#if defined program_gbuffers_water || defined program_gbuffers_terrain
		matFlag = 1.0;

		//Plants/ Vegitation : 1.0
			matFlag = (
			material == 18 ||
			material == 161 ||
			material == 175 ||
			material == 31 ||
			material == 106 ||
			material == 37 ||
			material == 38 ||
			material == 39 ||
			material == 40 ||
			material == 59 ||
			material == 104 ||
			material == 105 ||
			material == 83 ||
			material == 115
		) ? 2.0 : matFlag;

		//Water : 3.0
			matFlag	= (
			material == 8 ||
			material == 9
		) ? 3.0 : matFlag;

		matFlag = floor(matFlag) * (1.0 / 32.0);
	#endif

	vec3 tangent = at_tangent.xyz / at_tangent.w;
	vec3 normal = gl_Normal;

	#if !defined program_gbuffers_terrain && !defined program_gbuffers_water && !defined program_gbuffers_hand
		normal = (gl_NormalMatrix * normal) * mat3(gbufferModelView);
		tangent = (gl_NormalMatrix * tangent) * mat3(gbufferModelView);
	#endif

	tbn = mat3(tangent, cross(tangent, normal), normal);

	tangentVec = -normalize((viewSpacePosition * gl_NormalMatrix) * tbn);
}
