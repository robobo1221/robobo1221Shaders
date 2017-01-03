#version 120

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 moonlight;

varying float handLightMult;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform int worldTime;
uniform int heldItemId;
uniform int heldItemId2;

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

	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = sunVec;
	}

	else {
		lightVector = moonVec;
	}

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	#include "lib/lightColor.glsl"
	
	handLightMult = 0.0;
	
	float heldItemIdCombined = heldItemId + heldItemId2;
	
	if (heldItemId == 50 || heldItemId2 == 50 ) {
		// torch
		handLightMult = 0.5;
	}

	else if (heldItemId == 76 || heldItemId == 94 || heldItemId2 == 76 || heldItemId2 == 94) {
		// active redstone torch / redstone repeater
		handLightMult = 0.1;
	}

	else if (heldItemId == 89 || heldItemId2 == 89) {
		// lightstone
		handLightMult = 1.0;
	}

	else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51 || heldItemId2 == 10 || heldItemId2 == 11 || heldItemId2 == 51) {
		// lava / lava / fire
		handLightMult = 0.5;
	}

	else if (heldItemId == 91 || heldItemId2 == 91) {
		// jack-o-lantern
		handLightMult = 0.7;
	}

	else if (heldItemId == 327 || heldItemId2 == 327) {
		//lava bucket
		handLightMult = 1.5;
	}

		else if (heldItemId == 385 || heldItemId2 == 385) {
		//fire charger
		handLightMult = 0.2;
	}

		else if (heldItemId == 138 || heldItemId2 == 138) {
		//Beacon
		handLightMult = 1.0;
	}

		else if (heldItemId == 169 || heldItemId2 == 169) {
		//Sea lantern
		handLightMult = 1.0;
	}
	
	else if (heldItemId == 198 || heldItemId2 == 198) {
		//End rod
		handLightMult = 0.5;
	}
}