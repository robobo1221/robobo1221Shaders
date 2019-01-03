#version 120
#define program_shadow
#define FRAGMENT

varying vec2 texcoord;
varying vec4 color;

varying vec2 lightmaps;

flat varying float material;
flat varying vec3 normals;

uniform sampler2D tex;

#include "/lib/utilities.glsl"

/* DRAWBUFFERS:01 */
void main()
{
	//if(!gl_FrontFacing) discard;

	vec4 albedo = texture2D(tex, texcoord) * color;

	if (albedo.a == 0.0) discard;
	
	bool isWater = material == 8 || material == 9;

	albedo = isWater ? vec4(1.0, 1.0, 1.0, 0.0) : albedo;

	gl_FragData[0] = vec4(albedo.rgb * (1.0 - albedo.a), lightmaps.y * 0.5 + 0.5);
	gl_FragData[1] = vec4(normals * 0.5 + 0.5, float(isWater) * 0.5 + 0.5);
}
