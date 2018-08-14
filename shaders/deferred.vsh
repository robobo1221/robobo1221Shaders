#version 120
#define program_deferred
#define VERTEX

varying vec2 texcoord;
varying mat4 shadowMatrix;

varying mat3x4 skySH;

varying vec3 sunVector;
varying vec3 moonVector;
varying vec3 upVector;

varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 skyColor;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float eyeAltitude;

#include "/lib/utilities.glsl"
#include "/lib/fragment/sky.glsl"

vec4 ToSH(float value, vec3 dir) {
    const float transferl1 = 0.3849 * PI;
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(rPI * 3.0);

    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 transfer = vec2(PI * sqrt1OverPI, transferl1 * sqrt3OverPI);

    const vec4 foo = halfnhalf.xyxy * transfer.xyyy;

    return foo * vec4(1.0, dir.yzx) * value;
}

void CalculateSkySH(vec3 sunVector, vec3 moonVector, vec3 upVector, vec3 ambientColor) {
	const int latSamples = 5;
	const int lonSamples = 5;
	const float rLatSamples = 1.0 / latSamples;
	const float rLonSamples = 1.0 / lonSamples;
	const float sampleCount = rLatSamples * rLonSamples;

	const float latitudeSize = rLatSamples * PI;
	const float longitudeSize = rLonSamples * TAU;

	vec4 shR = vec4(0.0), shG = vec4(0.0), shB = vec4(0.0);
	const float offset = 0.1;

	for (int i = 0; i < latSamples; ++i) {
		float latitude = float(i) * latitudeSize;

		for (int j = 0; j < lonSamples; ++j) {
			float longitude = float(j) * longitudeSize;

			float c = cos(latitude);
			vec3 kernel = vec3(c * cos(longitude), sin(latitude), c * sin(longitude));

			vec3 skyCol = calculateAtmosphere(vec3(0.0), mat3(gbufferModelView) * normalize(kernel + vec3(0.0, offset, 0.0)), upVector, sunVector, moonVector, 10);
		
			shR += ToSH(skyCol.r, kernel);
			shG += ToSH(skyCol.g, kernel);
			shB += ToSH(skyCol.b, kernel);
		}
	}

	skySH = mat3x4(shR, shG, shB) * sampleCount;
}

void main() {
	gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
	texcoord = gl_MultiTexCoord0.xy;

	upVector = upPosition * 0.01;
	sunVector = sunPosition * 0.01;
	moonVector = -sunVector;

	vec3 wSunVector = mat3(gbufferModelViewInverse) * sunVector;
	vec3 wMoonVector = mat3(gbufferModelViewInverse) * moonVector;

	sunColor = atmosphere_transmittance(vec3(0.0, atmosphere_planetRadius, 0.0), wSunVector, 3) * sunColorBase;
	moonColor = atmosphere_transmittance(vec3(0.0, atmosphere_planetRadius, 0.0), wMoonVector, 3) * moonColorBase;
	
	skyColor = calculateAtmosphere(vec3(0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), wSunVector, wMoonVector, 10);

	shadowMatrix = shadowProjection * shadowModelView;

	CalculateSkySH(sunVector, moonVector, upVector, skyColor);
}
