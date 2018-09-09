float encodeVec2(vec2 a) {
	const vec2 constant1 = vec2(1.0, 256.0) / 65535.0; //2^16-1
	return dot(floor(a * 255.0), constant1);
}

float encodeVec2(float x,float y) {
	return encodeVec2(vec2(x,y));
}

vec2 decodeVec2(float a) {
	const vec2 constant1 = 65535.0 / vec2(256.0, 65536.0);
	const float constant2 = 256.0 / 255.0;
	return fract(a * constant1) * constant2;
}

float encodeNormal(vec3 a) {
    vec3 b = abs(a);
    vec2 p = a.xy / dot(b, vec3(1.0));
    vec2 encoded = a.z <= 0. ? (1. - abs(p.yx)) * fsign(p) : p;
    encoded = encoded * .5 + .5;
	return encodeVec2(encoded);
}

vec3 decodeNormal(float encoded) {
	vec2 a = decodeVec2(encoded);
	     a = a * 2.0 - 1.0;
	vec2 b = abs(a);
	float z = 1.0 - b.x - b.y;

	return normalize(vec3(z < 0.0 ? (1.0 - b.yx) * fsign(a) : a, z));
}

vec3 decodeNormal(float encoded, mat4 gbufferModelView) {
	return mat3(gbufferModelView) * decodeNormal(encoded);
}

vec4 encodeRGBE8(vec3 rgb) {
    float exponentPart = floor(log2(max3(rgb)));
    vec3  mantissaPart = clamp01((128.0 / 255.0) * rgb * exp2(-exponentPart));
          exponentPart = clamp01((exponentPart + 127.0) * (1.0 / 255.0));

    return vec4(mantissaPart, exponentPart);
}

vec3 decodeRGBE8(vec4 rgbe) {
    float exponentPart = exp2(rgbe.a * 255.0 - 127.0);
    vec3  mantissaPart = (510.0 / 256.0) * rgbe.rgb;

    return exponentPart * mantissaPart;
}
