#version 120

varying vec4 texcoord;
varying vec4 color;
varying vec3 worldpos;

varying float iswater;
varying float isTransparent;

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform float frameTimeCounter;

#include "lib/noise.glsl"
#include "lib/waterBump.glsl"
#include "lib/options.glsl"

#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
	#include "lib/caustics.glsl"
#endif

void main() {

	vec4 fragcolor = texture2D(tex,texcoord.xy) * color;
	
	#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
		vec3 caustics = waterCaustics();
	
		fragcolor.rgb = bool(iswater) ? caustics : fragcolor.rgb;
	#endif
	
	fragcolor.rgb = mix(vec3(0.0), mix(vec3(0.0),fragcolor.rgb, fragcolor.a), isTransparent) * 0.1;
	
/* DRAWBUFFERS:0 */	

	gl_FragData[0] = vec4(fragcolor);
}