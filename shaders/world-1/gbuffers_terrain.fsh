#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "lib/options.glsl"

const vec3 intervalMult = vec3(1.0, 1.0, 1.0/(POM_DEPTH / 8.0))/POM_MAP_RES * 64 / OCCLUSION_POINTS;
const float MAX_OCCLUSION_DISTANCE = 22.0;
const float MIX_OCCLUSION_DISTANCE = 18.0;
const int   MAX_OCCLUSION_POINTS   = OCCLUSION_POINTS;

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

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform vec3 upPosition;

uniform float wetness;
uniform float frameTimeCounter;

const float mincoord = 1.0/4096.0;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);

vec4 readTexture(vec2 coord)
{
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

vec4 readNormal(vec2 coord)
{
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

void main(){

	vec2 adjustedTexCoord = texcoord.st;

	vec3 viewVector = normalize(tbnMatrix * viewVector);

	#ifdef POM
	if (dist < MAX_OCCLUSION_DISTANCE) {
		float heightMap = readNormal(vtexcoord.st).a;

		if ( viewVector.z < 0.0 && heightMap < 0.99 && heightMap > 0.01)
	{
		vec3 interval = viewVector.xyz * intervalMult;
		vec3 coord = vec3(vtexcoord.st, 1.0);
		for (int loopCount = 0; (loopCount < int(MAX_OCCLUSION_POINTS)) && (readNormal(coord.st).a < coord.p); ++loopCount) {
			coord = coord+interval;
		}
		if (coord.t < mincoord) {
			if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
				coord.t = mincoord;
				discard;
			}
		}
		adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));
	}

	}
	#endif


	#include "lib/lmCoord.glsl"

	vec2 posxz = wpos.xz - wpos.y;
	

	vec4 albedo = texture2D(texture, adjustedTexCoord.st) * color;
	vec3 bump = texture2D(normals, adjustedTexCoord.st).rgb * 2.0 - 1.0;
	
	#ifdef SPECULAR_MAPPING
		vec3 specularity = texture2DGradARB(specular, adjustedTexCoord, dcdx, dcdy).rgb;
	#else 
		vec3 specularity = vec3(0.0);
	#endif
	float atten = 1.0-(specularity.g);
	
	float bumpmult = 0.75 * atten;

	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
						  
	vec4 normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

/* DRAWBUFFERS:0246 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = normalTangentSpace;
	gl_FragData[2] = vec4(lightmaps.x, mat, lightmaps.y, 1.0);
	#ifdef SPECULAR_MAPPING
		gl_FragData[3] = vec4(specularity, 1.0);
	#endif
	
}