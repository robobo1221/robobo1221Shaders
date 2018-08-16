#version 120
#define program_deferred
#define FRAGMENT

varying vec2 texcoord;
varying mat4 shadowMatrix;

varying mat3x4 skySH;

varying vec3 sunVector;
varying vec3 moonVector;
varying vec3 upVector;
varying vec3 lightVector;
varying vec3 wLightVector;

varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 skyColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform float eyeAltitude;

#include "/lib/utilities.glsl"

/*
const float sunPathRotation = -45.0;

const int colortex0Format = RGBA8;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA8;
const int colortex5Format = RGBA16F;

const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex5Clear = false;

const float ambientOcclusionLevel = 0.0;

*/

const int shadowMapResolution = 2048;
const float rShadowMapResolution = 1.0 / float(shadowMapResolution);
const float shadowDistance = 120.0;

vec3 getNormal(float data) {
	return decodeNormal(data, gbufferModelView);
}

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateWorldSpacePosition(vec3 coord) {
	return transMAD(gbufferModelViewInverse, coord);
}

vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir) {
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(3.0 * rPI);
    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 sqrtOverPI = vec2(sqrt1OverPI, sqrt3OverPI);
    const vec4 foo = halfnhalf.xyxy * sqrtOverPI.xyyy;

    vec4 sh = foo * vec4(1.0, lightDir.yzx);

    // know to work
    return vec3(
        dot(sh,cR),
        dot(sh,cG),
        dot(sh,cB)
    );
}

vec2 getLightmaps(float data)
{
	vec2 lightmaps = decodeVec2(data);
	return vec2(lightmaps.x, lightmaps.y * lightmaps.y);
}

#include "/lib/fragment/sky.glsl"
#include "/lib/uniform/shadowDistortion.glsl"
#include "/lib/fragment/volumetricLighting.glsl"
#include "/lib/fragment/directLighting.glsl"

/* DRAWBUFFERS:20 */

void main() {
	float depth = texture2D(depthtex1, texcoord).x;
	vec4 data0 = texture2D(colortex0, texcoord);

	mat2x3 position;
		   position[0] = calculateViewSpacePosition(texcoord, depth);
		   position[1] = calculateWorldSpacePosition(position[0]);

	vec3 viewVector = -normalize(position[0]);
	vec3 worldVector = mat3(gbufferModelViewInverse) * viewVector;
	vec3 shadowLightVector = shadowLightPosition * 0.01;

	if (depth >= 1.0) {
		float vDotL = dot(-viewVector, sunVector);

		vec3 color = vec3(0.0);
		     color += CalculateSunSpot(vDotL) * sunColorBase;
			 color += CalculateMoonSpot(-vDotL) * moonColorBase;

		vec3 sky = calculateAtmosphere(color, -viewVector, upVector, sunVector, moonVector, 25);
		gl_FragData[0] = encodeRGBE8(max0(sky));
		return;
	}

	vec4 data1 = texture2D(colortex1, texcoord);

	vec3 albedo = srgbToLinear(data0.rgb);
	vec3 normal = getNormal(data1.x);
	vec2 lightmaps = getLightmaps(data1.y);

	vec3 finalColor = calculateDirectLighting(albedo, position[1], normal, viewVector, shadowLightVector, wLightVector, lightmaps, 1.0);

	gl_FragData[0] = encodeRGBE8(max0(finalColor));
	gl_FragData[1] = vec4(0.0);
}
