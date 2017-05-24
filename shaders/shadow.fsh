#version 120

varying vec4 texcoord;
varying vec4 color;

varying float iswater;
varying float isTransparent;

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;

uniform float frameTimeCounter;

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

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