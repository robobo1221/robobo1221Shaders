#version 120
#include "lib/util/fastMath.glsl"

varying vec4 texcoord;
varying vec4 color;

varying vec4 lmcoord;

varying float iswater;
varying float translucentBlocks;

varying vec3 worldpos;
varying vec3 normal;

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;

uniform float frameTimeCounter;

#include "lib/util/noise.glsl"
#include "lib/displacement/normalDisplacement/waterBump.glsl"
#include "lib/options/options.glsl"

#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
	#include "lib/fragment/caustics.glsl"
#endif

void main() {

	vec4 fragcolor = texture2D(tex,texcoord.xy) * color;
	
	#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS
		vec3 caustics = waterCaustics(worldpos);
	
		fragcolor.rgb = bool(iswater) ? caustics : fragcolor.rgb;
	#endif

	fragcolor.rgb *= mix(1.0, fragcolor.a, translucentBlocks);
	fragcolor.rgb = mix(fragcolor.rgb, vec3(0.0), smoothstep(0.99, 1.0, fragcolor.a) * translucentBlocks);
	
/* DRAWBUFFERS:01 */	

	gl_FragData[0] = vec4(fragcolor.rgb * 0.1, fragcolor.a);
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, lmcoord.y * 0.8 + 0.2);
}