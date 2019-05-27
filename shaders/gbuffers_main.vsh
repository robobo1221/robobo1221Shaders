#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;
varying vec2 midcoord;
varying vec2 tileSize;
varying vec4 color;

varying float pomDepth;

varying mat3 tbn;

varying vec3 tangentVec;
varying vec3 tangentVecView;

varying vec2 lightmaps;
flat varying float material;
flat varying float matFlag;

varying vec3 worldPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D texture;

uniform float frameTimeCounter;
uniform int frameCounter;

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/lib/utilities.glsl"
#include "/lib/uniform/TemporalJitter.glsl"
#include "/lib/vertex/vertexDisplacement.glsl"

void main() {

	material = mc_Entity.x;

	texcoord = gl_MultiTexCoord0.xy;
	lightmaps = gl_MultiTexCoord1.xy * (1.0 / 255.0);
	midcoord = mc_midTexCoord.xy;
	tileSize = abs(texcoord - midcoord) * 2.0;
	color = gl_Color;

	pomDepth = length(tileSize) * POM_DEPTH;

	vec3 viewSpacePosition = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

	worldPosition = doWavingPlants(transMAD(gbufferModelViewInverse, viewSpacePosition));
	viewSpacePosition = transMAD(gbufferModelView, worldPosition);

	vec4 position = viewSpacePosition.xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		 position.xy += calculateTemporalJitter() * position.w;

	gl_Position = position;

	#if defined program_gbuffers_terrain
	    // lit block fix
		lightmaps.x = material == 89.0 || material == 169.0 || material == 124.0
		|| material == 51.0 || material == 10.0 || material == 11.0 || material == 138.0
		|| material == 198.0 ? 1.0 : lightmaps.x;
	#endif

	#if defined program_gbuffers_water || defined program_gbuffers_terrain
		matFlag = 1.0;

		//Plants/ Vegitation : 2.0
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
			material == 115 ||
			material == 141 ||
			material == 207
		) ? 2.0 : matFlag;

		//Water : 3.0
			matFlag	= (
			material == 8 ||
			material == 9
		) ? 3.0 : matFlag;

		//Lava : 4.0
			matFlag = (
			material == 10 ||
			material == 11
			) ? 4.0 : matFlag;

		matFlag = floor(matFlag) * (1.0 / 32.0);
	#endif

	vec3 tangent = at_tangent.xyz / at_tangent.w;
	vec3 normal = gl_Normal;

	#if !defined program_gbuffers_terrain && !defined program_gbuffers_water
		normal = (gl_NormalMatrix * normal) * mat3(gbufferModelView);
		tangent = (gl_NormalMatrix * tangent) * mat3(gbufferModelView);
	#endif

	tbn = mat3(tangent, cross(tangent, normal), normal);
	mat3 tbnFix = tbn;

	#ifdef POM
		vec2 atlasSize = vec2(textureSize2D(texture, 0));

		tbnFix = mat3(tbn[0] * atlasSize.y / atlasSize.x, tbn[1], tbn[2]);
	#endif

	tangentVec = -normalize((viewSpacePosition * gl_NormalMatrix) * tbnFix);
	tangentVecView = (viewSpacePosition * gl_NormalMatrix) * tbnFix;
}
