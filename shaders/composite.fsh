#version 120

/* DRAWBUFFERS:7 */	

#define SHADOW_BIAS 0.85

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.
#include "lib/options.glsl"

varying vec4 texcoord;

uniform sampler2D gaux4;

#ifdef GLOBAL_ILLUMINATION
varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying float handLightMult;

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

vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

vec3 toScreenSpace(vec3 p) {
        vec3 p3 = vec3(p) * 2. - 1.;
        vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
        return fragposition.xyz / fragposition.w;
}

vec3 fragpos = toScreenSpace(vec3(texcoord.st, pixeldepth));

vec4 getWorldSpace(vec4 fragpos){

	vec4 wpos = gbufferModelViewInverse * fragpos;

	return wpos;
}

mat2 rotate(float rad) {
	return mat2(
	vec2(cos(rad), -sin(rad)),
	vec2(sin(rad), cos(rad))
	);
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
#define g(a) (-4.*a.x*a.y+3.*a.x+a.y*2.)

float bayer16x16(vec2 p){

	p *= vec2(viewWidth,viewHeight);

    vec2 m0 = vec2(mod(floor(p/8.), 2.));
    vec2 m1 = vec2(mod(floor(p/4.), 2.));
    vec2 m2 = vec2(mod(floor(p/2.), 2.));
    vec2 m3 = vec2(mod(floor(p)   , 2.));

    return (g(m0)+g(m1)*4.0+g(m2)*16.0+g(m3)*64.0)/255.;
}
#undef g
float dither = bayer16x16(texcoord.st);

#include "lib/shadowPos.glsl"

vec3 getGi(vec3 viewVector){

	float weight = 0.0;
	vec3 indirectLight = vec3(0.0);

	float rotateMult = dither * pi * 2.0;	//Make sure the offset rotates 360 degrees.
	mat2 rotationMatrix	= rotate(rotateMult);

	vec4 shadowSpaceNormal = normalize(shadowModelView * getWorldSpace(vec4(normal, 0.0)));

	vec3 shadowPosition = toShadowSpace(viewVector);

	float blockDistance = sqrt(dot(fragpos, fragpos));
	float diffTresh = 0.0025 * pow(smoothstep(0.0, 255.0, blockDistance), 0.75) + 0.0001;

	float giDistanceMask = clamp(1.0 - (blockDistance / 320.0), 0.0, 1.0);
	
	const float giSteps = 1.0 / (6.0 * GI_QUALITY);

	vec2 circleDistribution = rotationMatrix * vec2(1.0) / 32.0;

	for (float i = 1.0; i < 2.0; i += giSteps){
		
			vec2 offset = (circleDistribution * i);
				 offset *= sqrt(dot(offset, offset)) * GI_RADIUS;

			vec2 offsetPosition = vec2(shadowPosition.rg + offset);
			vec2 biasedPosition = biasedShadows(vec3(offsetPosition, 0.0)).xy;

			float shadow = texture2D(shadowtex1, biasedPosition).x + diffTresh;
			      shadow = 5.0 * (shadow - 0.5);

			vec3 samplePos = vec3(offsetPosition, shadow) - shadowPosition.xyz;
			
			vec3 lPos = normalize(samplePos);
			float distFromX = sqrt(dot(samplePos, samplePos));

			float nDotL = clamp(dot(vec3(lPos.xy, -lPos.z), shadowSpaceNormal.xyz), 0.0, 1.0);

			if (nDotL > 0.0) {

				vec4 normalSample = texture2D(shadowcolor1, biasedPosition);
					 normalSample.rgb = normalSample.rgb * 2.0 - 1.0;
					 normalSample.xy = -normalSample.xy;

				float sampleWeight = clamp(dot(lPos, normalSample.rgb), 0.0, 1.0);

				float distanceWeight = 1.0 / (pow(distFromX * 6200.0, 2.0) + 5000.0);
					
				float skyLightWeight = normalSample.a - aux;
					  skyLightWeight = 1.0 / (max(0.0, skyLightWeight * skyLightWeight) * 50.0 + 1.0);

				indirectLight += pow(texture2D(shadowcolor, biasedPosition).rgb, vec3(2.2)) * (sampleWeight * nDotL) * (distanceWeight * skyLightWeight);
			}

			weight++;
	}
	indirectLight /= weight;
	indirectLight = max(indirectLight * 15000000.0, 0.0) * giDistanceMask;

	return indirectLight / (indirectLight + 1.0);
}
#endif

void main(){
#ifdef GLOBAL_ILLUMINATION

	vec3 globalIllumination = vec3(0.0);

	if (pixeldepth < 1.0){
		globalIllumination = getGi(fragpos);
	}
	
	gl_FragData[0] = vec4(globalIllumination, texture2D(gaux4, texcoord.st).a);
#else
	gl_FragData[0] = texture2D(gaux4, texcoord.st);
#endif
}