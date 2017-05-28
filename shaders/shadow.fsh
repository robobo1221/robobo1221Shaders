#version 120

varying vec4 texcoord;
varying vec4 color;

varying vec2 lmcoord;

varying float iswater;
varying float translucentBlocks;

varying vec3 worldpos;
varying vec3 normal;

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

	fragcolor.rgb = mix(fragcolor.rgb, vec3(0.0), smoothstep(0.99, 1.0, fragcolor.a) * translucentBlocks);
	
/* DRAWBUFFERS:01 */	

	gl_FragData[0] = vec4(fragcolor.rgb * 0.1, fragcolor.a);
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, lmcoord.y * 0.8 + 0.2);
}