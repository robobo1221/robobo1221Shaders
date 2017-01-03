#version 120

varying vec4 texcoord;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 moonlight;
varying vec3 upVec;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform int worldTime;

float timefract = worldTime;

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f)),
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),
				
				vec2(
				
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and midnight.

void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = sunVec;
	}

	else {
		lightVector = moonVec;
	}
	
	#include "lib/lightColor.glsl"
}