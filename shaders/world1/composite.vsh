#version 120

varying vec4 texcoord;

varying float handLightMult;

uniform int heldItemId;
uniform int heldItemId2;

void main()
{


	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
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