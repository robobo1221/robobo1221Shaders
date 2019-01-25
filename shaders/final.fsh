#version 120
#define program_final
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex4;

#include "/lib/utilities.glsl"

vec3 vibranceSaturation(vec3 color){
	const float amountVibrance = VIBRANCE;
	const float amountSaturation = SATURATION;

	float lum = dot(color, lumCoeff);
	float mn = min3(color);
	float mx = max3(color);
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * lum * 5.0;
	vec3 lig = vec3((mn + mx) * 0.5);

	// Vibrance
	color = mix(color, mix(color, lig, -amountVibrance), sat);

	// Inverse Vibrance
	color = mix(color, lig, (1.0 - lig) * (1.0 - amountVibrance) * 0.5 * abs(amountVibrance));

	// saturation
	color = mix(color, vec3(lum), -amountSaturation);

	return color;
}

void main() {
	vec4 colorSample = texture2D(colortex4, texcoord);
	vec3 color = colorSample.rgb;

	color = vibranceSaturation(color);

	gl_FragColor = vec4(color, 1.0);
}
