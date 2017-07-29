#version 120
#include "lib/util/fastMath.glsl"

/* DRAWBUFFERS:7 */	

#define SHADOW_DISTORTION 0.85

#include "lib/options/options.glsl"

varying vec4 texcoord;

uniform sampler2D gaux4;

#ifdef GLOBAL_ILLUMINATION
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float far;

uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;

uniform int isEyeInWater;

uniform float viewHeight;
uniform float viewWidth;

const float pi = 3.141592653589793238462643383279502884197169;

vec3 normal = 		texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
float pixeldepth = texture2D(depthtex1, texcoord.st).r;
float aux = 		texture2D(gaux1, texcoord.st).b;

mat2 rotate(float rad) {
    float c = cos(rad);
    float s = sin(rad);
    return mat2( c, -s, s, c );
}

/* #define g(a) abs(dot(mod(floor(a),2.),vec2(3,-2)))

float bayer32x32(vec2 p){
    float m0 = g( p * .0625 );
    float m1 = g( p * .125  );
    float m2 = g( p * .25   );
    float m3 = g( p * .5    );
    float m4 = g( p         );

    const float d0 = 1.   / 1023.;
    const float d1 = 4.   / 1023.;
    const float d2 = 16.  / 1023.;
    const float d3 = 64.  / 1023.;
    const float d4 = 256. / 1023.;

    return m0*d0 + m1*d1 + m2*d2 + m3*d3 + m4*d4;
}
float bayer64x64(vec2 p){
    float m0 = g(p * .03125 );
    float m1 = g(p * .0625  );
    float m2 = g(p * .125   );
    float m3 = g(p * .25    );
    float m4 = g(p * .5     );
    float m5 = g(p          );

    const float d0 = 1.    / 4096.;
    const float d1 = 4.    / 4096.;
    const float d2 = 16.   / 4096.;
    const float d3 = 64.   / 4096.;
    const float d4 = 256.  / 4096.;
    const float d5 = 1024. / 4096.;

    return m0*d0 + m1*d1 + m2*d2 + m3*d3 + m4*d4 + m5*d5;
}
*/
#include "lib/util/spaceConversions.glsl"
#include "lib/util/dither.glsl"
#include "lib/fragment/position/shadowPos.glsl"

vec3 getGi(){

	float weight = 0.0;
	vec3 indirectLight = vec3(0.0);

	vec3 fragpos = toScreenSpace(gbufferProjectionInverse, vec3(texcoord.st, pixeldepth));

	float rotateMult = dither * pi * 2.0;	//Make sure the offset rotates 360 degrees.
	mat2 rotationMatrix	= rotate(rotateMult);

	vec3 shadowSpaceNormal = mat3(shadowModelView) * toWorldSpaceNoMAD(gbufferModelViewInverse, normal);

	vec3 shadowPosition = toShadowSpace(fragpos);

	float blockDistance = fLength(fragpos);
	float diffTresh = 0.0025 * pow(smoothstep(0.0, 255.0, blockDistance), 0.75) + 0.0001;

	float giDistanceMask = clamp(1.0 - (blockDistance * 0.003125), 0.0, 1.0);
	
	const float giSteps = 1.0 / (6.0 * GI_QUALITY);

	vec2 circleDistribution = rotationMatrix * vec2(0.03125);

	for (float i = 1.0; i < 2.0; i += giSteps){
		
			vec2 offset = circleDistribution;
				 offset *= 0.0441942 * i * i * GI_RADIUS;

			vec2 offsetPosition = vec2(shadowPosition.rg + offset);
			vec2 biasedPosition = biasedShadows(vec3(offsetPosition, 0.0)).xy;

			float shadow = texture2D(shadowtex1, biasedPosition).x + diffTresh;
			      shadow = 5.0 * shadow - 2.5;

			vec3 sampleVector = vec3(offsetPosition, shadow) - shadowPosition.xyz;
			
			float distFromX2 = dot(sampleVector,sampleVector);
			vec3 lPos = sampleVector * inversesqrt(distFromX2);

			float diffuse = clamp(dot(vec3(lPos.xy, -lPos.z), shadowSpaceNormal), 0.0, 1.0);

			if (diffuse > 0.0) {

				vec4 normalSample = texture2D(shadowcolor1, biasedPosition);
					 normalSample.rgb = normalSample.rgb * 2.0 - 1.0;
					 normalSample.xy = -normalSample.xy;

				float sDir = clamp(dot(lPos, normalSample.rgb), 0.0, 1.0);

				float giFalloff = 0.0000000260146 / (distFromX2 + 0.000130073);
					
				float skyLM = normalSample.a - aux;
					  skyLM = 0.02 / (max(0.0, skyLM * skyLM) + 0.02);

				indirectLight = pow(texture2D(shadowcolor, biasedPosition).rgb, vec3(2.2)) * (sDir * diffuse) * (giFalloff * skyLM) + indirectLight;
			}

			weight++;
	}
	indirectLight /= weight;
	indirectLight = max(indirectLight * 15000000.0, 0.0) * GI_MULT * giDistanceMask;

	return indirectLight / (indirectLight + 1.0);
}
#endif

void main(){
#ifdef GLOBAL_ILLUMINATION

	vec3 globalIllumination = vec3(0.0);

	if (pixeldepth < 1.0){
		globalIllumination = getGi();
	}
	
	gl_FragData[0] = vec4(globalIllumination, texture2D(gaux4, texcoord.st).a);
#else
	gl_FragData[0] = texture2D(gaux4, texcoord.st);
#endif
}