#version 120

/* DRAWBUFFERS:013 */	

#define SHADOW_BIAS 0.85

#include "lib/directLightOptions.glsl" //Go here for shadowResolution, distance etc.
#include "lib/options.glsl"

//-------------------------------------------------//

/*
Standard shader configuration.
const bool 		shadowColor0Mipmap = true;

*/

//-------------------------------------------------//

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D composite;

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
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;

uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;

uniform int isEyeInWater;

uniform float viewHeight;
uniform float viewWidth;

const float pi = 3.141592653589793238462643383279502884197169;

vec3 normal = 		texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
float pixeldepth = 	texture2D(gdepthtex, texcoord.st).r;
float pixeldepth2 = texture2D(depthtex1, texcoord.st).r;
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

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

#include "lib/shadowPos.glsl"

vec3 getGi(){

	float weight = 0.0;
	vec3 indirectLight = vec3(0.0);

	float dither = bayer16x16(texcoord.st);
	
	float rotateMult = dither * pi * 2.0;	//Make sure the offset rotates 360 degrees.
	
	mat2 rotationMatrix	= mat2(cos(rotateMult), -sin(rotateMult),
						       sin(rotateMult), cos(rotateMult));

	vec4 shadowSpaceNormal = normalize(shadowModelView * getWorldSpace(vec4(normal, 0.0)));

	vec4 shadowPosition = getShadowSpace(pixeldepth2, texcoord.st);
	
	const int steps = 6;

	for (int i = 1; i < steps; i++){
		
			vec2 offset = rotationMatrix * vec2(float(i) + dither) / 16.0 / float(steps);
				 offset *= length(offset) * 4.0;

			vec4 offsetPosition = vec4(shadowPosition.rg + offset, 0.0, 0.0);
			vec2 biasedPosition = biasedShadows(offsetPosition).xy;

			vec4 normalSample = texture2D(shadowcolor1, biasedPosition.xy);
				 normalSample.rgb = normalSample.rgb * 2.0 - 1.0;
				 normalSample.xy = -normalSample.xy;

			float shadow = texture2D(shadowtex1, biasedPosition).x;

			shadow = -2.5 + 5.0 * (shadow + 0.0025 * pow(smoothstep(0.0, 255.0, length(fragpos)), 0.75) + 0.0001);
			vec3 samplePos = vec3(offsetPosition.xy, shadow);
			
			vec3 halfVector = samplePos.xyz - shadowPosition.xyz;
			
			vec3 lPos = normalize(halfVector);
			float distFromX = length(halfVector);

			float nDotL = clamp(dot(vec3(lPos.xy, -lPos.z), normalize(shadowSpaceNormal.xyz)), 0.0, 1.0);
			float sampleWeight = clamp(dot(lPos, normalSample.rgb), 0.0, 1.0);

			float distanceWeight = 1.0 / (pow(distFromX * 6200.0, 2.0) + 5000.0);
				  distanceWeight *= pow(length(offset), 2.0);
				  
			float skyLightMapShadow = 1.0 / (max(0.0, normalSample.a - aux) * 50.0 + 1.0);

			indirectLight += pow(texture2DLod(shadowcolor, biasedPosition.xy, .0).rgb, vec3(2.2)) * sampleWeight * nDotL * distanceWeight * skyLightMapShadow;

			weight++;
	}
	indirectLight /= weight;
	indirectLight *= 1000000000.0;

	return clamp(indirectLight / (indirectLight + 1.0), 0.0, 1.0);
}
#endif

void main(){
#ifdef GLOBAL_ILLUMINATION

	vec3 globalIllumination = vec3(0.0);

	if (pixeldepth2 < 1.0){
		globalIllumination = getGi();
	}
	
	gl_FragData[0] = vec4(texture2D(gcolor, texcoord.st).rgb, globalIllumination.r);
	gl_FragData[1] = vec4(texture2D(gdepth, texcoord.st).rgb, globalIllumination.g);
	gl_FragData[2] = vec4(texture2D(composite, texcoord.st).rgb, globalIllumination.b);
#else
	gl_FragData[0] = texture2D(gcolor, texcoord.st);
	gl_FragData[1] = texture2D(gdepth, texcoord.st);
	gl_FragData[2] = texture2D(composite, texcoord.st);
#endif
}