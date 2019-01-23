#version 120
#define program_composite3
#define FRAGMENT

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

#include "/lib/utilities.glsl"

vec3 calculateViewSpacePosition(vec2 coord, float depth) {
	vec3 viewCoord = vec3(coord, depth) * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateViewSpacePosition(vec3 coord) {
	vec3 viewCoord = coord * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, viewCoord) / (viewCoord.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 calculateWorldSpacePosition(vec3 coord) {
	return transMAD(gbufferModelViewInverse, coord);
}

vec3 sampleCurrentFrame(vec2 p){
	return texture2D(colortex0, p).rgb;
}

vec3 samplePreviousFrame(vec2 p){
	return texture2D(colortex4, p).rgb;
}

float sampleDepth(vec2 p){
	return texture2D(depthtex0, p).x;
}

vec2 calculateVelocityVector(vec3 coord){
	vec3 velocity = calculateViewSpacePosition(coord);	
		 velocity = calculateWorldSpacePosition(velocity);
		 velocity = (cameraPosition - previousCameraPosition) + velocity;
		 velocity = transMAD(gbufferPreviousModelView, velocity);
		 velocity = (diagonal3(gbufferPreviousProjection) * velocity + gbufferPreviousProjection[3].xyz) / -velocity.z * 0.5 + 0.5;

	return coord.xy - velocity.xy;
}

vec3 calculateClosestFragment(vec2 p, vec2 pixelSize){
	vec3 depth1 = vec3(pixelSize.x, 0.0, sampleDepth(p + vec2(pixelSize.x, 0.0)));
	vec3 depth2 = vec3(-pixelSize.x, 0.0, sampleDepth(p + vec2(-pixelSize.x, 0.0)));
	vec3 depth3 = vec3(pixelSize.x, pixelSize.y, sampleDepth(p + vec2(pixelSize.x, pixelSize.y)));
	vec3 depth4 = vec3(-pixelSize.x, pixelSize.y, sampleDepth(p + vec2(-pixelSize.x, pixelSize.y)));
	vec3 depth5 = vec3(pixelSize.x, -pixelSize.y, sampleDepth(p + vec2(pixelSize.x, -pixelSize.y)));
	vec3 depth6 = vec3(-pixelSize.x, -pixelSize.y, sampleDepth(p + vec2(-pixelSize.x, -pixelSize.y)));
	vec3 depth7 = vec3(0.0, pixelSize.y, sampleDepth(p + vec2(0.0, pixelSize.y)));
	vec3 depth8 = vec3(0.0, -pixelSize.y, sampleDepth(p + vec2(0.0, -pixelSize.y)));

	vec3 depthMin = depth1;
	depthMin = depthMin.z > depth2.z ? depth2 : depthMin;
	depthMin = depthMin.z > depth3.z ? depth3 : depthMin;

	depthMin = depthMin.z > depth4.z ? depth4 : depthMin;
	depthMin = depthMin.z > depth5.z ? depth5 : depthMin;
	depthMin = depthMin.z > depth6.z ? depth6 : depthMin;

	depthMin = depthMin.z > depth7.z ? depth7 : depthMin;
	depthMin = depthMin.z > depth8.z ? depth8 : depthMin;

	return vec3(depthMin.xy + p, depthMin.z);
}

vec3 clipAABB(vec3 boxMin, vec3 boxMax, vec3 q) {
	vec3 p_clip = 0.5 * (boxMax + boxMin);
	vec3 e_clip = 0.5 * (boxMax - boxMin);

	vec3 v_clip = q - p_clip;
	vec3 v_unit = v_clip.xyz / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max3(a_unit);

	if (ma_unit > 1.0)
		return p_clip + v_clip / ma_unit;
	else
		return q;
}

vec3 temporalReprojection(vec2 p, vec2 pixelSize, vec2 pixelResolution, vec3 previousCol, vec3 currentCol, vec2 velocity){
	vec3 col1 = sampleCurrentFrame(p + vec2(pixelSize.x, 0.0));
	vec3 col2 = sampleCurrentFrame(p + vec2(-pixelSize.x, 0.0));
	vec3 col3 = sampleCurrentFrame(p + vec2(pixelSize.x, pixelSize.y));
	vec3 col4 = sampleCurrentFrame(p + vec2(-pixelSize.x, pixelSize.y));
	vec3 col5 = sampleCurrentFrame(p + vec2(pixelSize.x, -pixelSize.y));
	vec3 col6 = sampleCurrentFrame(p + vec2(-pixelSize.x, -pixelSize.y));
	vec3 col7 = sampleCurrentFrame(p + vec2(0.0, pixelSize.y));
	vec3 col8 = sampleCurrentFrame(p + vec2(0.0, -pixelSize.y));

	vec3 colMin = min(currentCol, min(min4(col1, col2, col3, col4), min4(col5, col6, col7, col8)));
	vec3 colMax = max(currentCol, max(max4(col1, col2, col3, col4), max4(col5, col6, col7, col8)));
	vec3 colAVG = (currentCol + col1 + col2 + col3 + col4 + col5 + col6 + col7 + col8) * (1.0 / 9.0);

	previousCol = clipAABB(colMin, colMax, previousCol);

	vec2 pixelVelocity = abs(fract(velocity * pixelResolution) - 0.5) * 2.0;

	float blendWeight = 0.97;
		  //Zombye's neat way to get rid of blurring and ghosting. Thanks <3
		  blendWeight *= sqrt(pixelVelocity.x * pixelVelocity.y) * 0.25 + 0.75;

	p -= velocity;
	blendWeight = clamp01(p) != p ? 0.0 : blendWeight;

	vec3 sharpening = (1.0 - exp(-(currentCol - clamp(colAVG, colMin, colMax)))) * TAA_SHARPENING;

	return mix(currentCol + sharpening, previousCol, blendWeight);
}

vec3 calculateMotionBlur(vec2 p, vec2 velocity, float dither){
	const int steps = 4;
	const float rSteps = 1.0 / steps;

	vec2 direction = velocity / (1.0 + length(velocity)) * rSteps * 0.15;
	p += dither * direction;

	vec3 color = vec3(0.0);
	float totalWeight = 0.0;

	for (int i = -steps; i < steps; i++)
	{
		float weight = 1.0;
		vec3 sample = sampleCurrentFrame(float(i) * direction + p) * weight;
		color += sample / (-sample * 0.99999 + 1.0);
		totalWeight += weight;
	}

	color /= totalWeight;

	return color / (color + 1.0);
}

vec3 calculateTAA(vec2 p, vec2 pixelSize, vec2 pixelResolution, float dither){
	vec3 currentCol = sampleCurrentFrame(p);

	#ifndef TAA
		return currentCol;
	#endif

	float tansparentDepth = texture2D(depthtex1, p).r;
	float handDepth = texture2D(depthtex2, p).r;

	bool handMask = handDepth > tansparentDepth;
	
	vec3 closest = calculateClosestFragment(p, pixelSize);
	vec2 velocity = calculateVelocityVector(closest);

	velocity = handMask ? vec2(0.0) : velocity;

	vec3 previousCol = samplePreviousFrame(p - velocity);
	vec3 reprojectedColor = temporalReprojection(p, pixelSize, pixelResolution, previousCol, currentCol, velocity);

	#ifdef MOTION_BLUR
		if (handMask) return reprojectedColor;
		vec3 motionBlur = calculateMotionBlur(p, velocity, dither);

		const float pixelTreshold = 100.0;

		float motionTreshhold = length(velocity * vec2(viewWidth, viewHeight));
			  motionTreshhold = clamp(motionTreshhold, 1.0, pixelTreshold) * (1.0 / pixelTreshold);

		return mix(reprojectedColor, motionBlur, motionTreshhold);
	#else
		return reprojectedColor;
	#endif
}

/* DRAWBUFFERS:4 */
void main() {
	vec2 pixelResolution = vec2(viewWidth, viewHeight);
	vec2 pixelSize = 1.0 / pixelResolution;

	float dither = bayer16(gl_FragCoord.xy);

	vec3 color = vec3(0.0);
	color = calculateTAA(texcoord, pixelSize, pixelResolution, dither);

	gl_FragData[0] = vec4(color, 1.0);
}
