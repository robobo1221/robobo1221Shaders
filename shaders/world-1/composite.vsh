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

	handLightMult = 0.1 * float(heldItemId == 76 || heldItemId == 94 || heldItemId2 == 76 || heldItemId2 == 94 || heldItemId == 385 || heldItemId2 == 385);

	handLightMult = 0.9 * float(heldItemId == 89 || heldItemId2 == 89 || heldItemId == 91 || heldItemId2 == 91 || heldItemId == 138 || heldItemId2 == 138 || heldItemId == 169 || heldItemId2 == 169
	|| heldItemId == 198 || heldItemId2 == 198 || heldItemId == 327 || heldItemId2 == 327 || heldItemId == 50 || heldItemId2 == 50 || heldItemId == 10 || heldItemId == 11 || heldItemId == 51
	|| heldItemId2 == 10 || heldItemId2 == 11 || heldItemId2 == 51) + handLightMult;
}