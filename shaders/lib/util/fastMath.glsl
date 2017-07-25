#define rcpln2 1.44269504089

#define fLengthSource(x) sqrt(dotX(x))
#define dotXSource(x) dot(x, x)

float dotX(vec2 x) {
    return dotXSource(x);
}

float dotX(vec3 x) {
    return dotXSource(x);
}

float dotX(vec4 x) {
    return dotXSource(x);
}

float fLength(vec4 x) {
    return fLengthSource(x);
}

float fLength(vec3 x) {
    return fLengthSource(x);
}

float fLength(vec2 x) {
    return fLengthSource(x);
}

vec2 fNormalize(vec2 x) {
    return x * inversesqrt(dotX(x));
}

vec3 fNormalize(vec3 x) {
    return x * inversesqrt(dotX(x));
}

vec4 fNormalize(vec4 x) {
    return x * inversesqrt(dotX(x));
}

float pow2(float x){return x*x;}
float pow3(float x){return pow2(x)*x;}
float pow4(float x){return pow2(pow2(x));}
float pow5(float x){return pow2(pow2(x))*x;}
float pow6(float x){return pow2(pow2(x)*x);}
float pow7(float x){return pow2(pow2(x)*x)*x;}
float pow8(float x){return pow2(pow2(pow2(x)));}
float pow9(float x){return pow2(pow2(pow2(x)))*x;}
float pow10(float x){return pow2(pow2(pow2(x))*x);}
float pow11(float x){return pow2(pow2(pow2(x))*x)*x;}
float pow12(float x){return pow2(pow2(pow2(x)*x));}
float pow13(float x){return pow2(pow2(pow2(x)*x))*x;}
float pow14(float x){return pow2(pow2(pow2(x)*x)*x);}
float pow15(float x){return pow2(pow2(pow2(x)*x)*x)*x;}
float pow16(float x){return pow2(pow2(pow2(pow2(x))));}
float pow32(float x){return pow2(pow2(pow2(pow2(pow2(x)))));}
float pow35(float x){return pow2(pow2(pow2(pow2(pow2(x))))*x)*x;}

vec2 pow2(vec2 x){return x*x;}
vec2 pow3(vec2 x){return pow2(x)*x;}
vec2 pow4(vec2 x){return pow2(pow2(x));}
vec2 pow5(vec2 x){return pow2(pow2(x))*x;}
vec2 pow6(vec2 x){return pow2(pow2(x)*x);}
vec2 pow7(vec2 x){return pow2(pow2(x)*x)*x;}
vec2 pow8(vec2 x){return pow2(pow2(pow2(x)));}
vec2 pow9(vec2 x){return pow2(pow2(pow2(x)))*x;}
vec2 pow10(vec2 x){return pow2(pow2(pow2(x))*x);}
vec2 pow11(vec2 x){return pow2(pow2(pow2(x))*x)*x;}
vec2 pow12(vec2 x){return pow2(pow2(pow2(x)*x));}
vec2 pow13(vec2 x){return pow2(pow2(pow2(x)*x))*x;}
vec2 pow14(vec2 x){return pow2(pow2(pow2(x)*x)*x);}
vec2 pow15(vec2 x){return pow2(pow2(pow2(x)*x)*x)*x;}
vec2 pow16(vec2 x){return pow2(pow2(pow2(pow2(x))));}
vec2 pow32(vec2 x){return pow2(pow2(pow2(pow2(pow2(x)))));}
vec2 pow35(vec2 x){return pow2(pow2(pow2(pow2(pow2(x))))*x)*x;}

vec3 pow2(vec3 x){return x*x;}
vec3 pow3(vec3 x){return pow2(x)*x;}
vec3 pow4(vec3 x){return pow2(pow2(x));}
vec3 pow5(vec3 x){return pow2(pow2(x))*x;}
vec3 pow6(vec3 x){return pow2(pow2(x)*x);}
vec3 pow7(vec3 x){return pow2(pow2(x)*x)*x;}
vec3 pow8(vec3 x){return pow2(pow2(pow2(x)));}
vec3 pow9(vec3 x){return pow2(pow2(pow2(x)))*x;}
vec3 pow10(vec3 x){return pow2(pow2(pow2(x))*x);}
vec3 pow11(vec3 x){return pow2(pow2(pow2(x))*x)*x;}
vec3 pow12(vec3 x){return pow2(pow2(pow2(x)*x));}
vec3 pow13(vec3 x){return pow2(pow2(pow2(x)*x))*x;}
vec3 pow14(vec3 x){return pow2(pow2(pow2(x)*x)*x);}
vec3 pow15(vec3 x){return pow2(pow2(pow2(x)*x)*x)*x;}
vec3 pow16(vec3 x){return pow2(pow2(pow2(pow2(x))));}
vec3 pow32(vec3 x){return pow2(pow2(pow2(pow2(pow2(x)))));}
vec3 pow35(vec3 x){return pow2(pow2(pow2(pow2(pow2(x))))*x)*x;}

vec4 pow2(vec4 x){return x*x;}
vec4 pow3(vec4 x){return pow2(x)*x;}
vec4 pow4(vec4 x){return pow2(pow2(x));}
vec4 pow5(vec4 x){return pow2(pow2(x))*x;}
vec4 pow6(vec4 x){return pow2(pow2(x)*x);}
vec4 pow7(vec4 x){return pow2(pow2(x)*x)*x;}
vec4 pow8(vec4 x){return pow2(pow2(pow2(x)));}
vec4 pow9(vec4 x){return pow2(pow2(pow2(x)))*x;}
vec4 pow10(vec4 x){return pow2(pow2(pow2(x))*x);}
vec4 pow11(vec4 x){return pow2(pow2(pow2(x))*x)*x;}
vec4 pow12(vec4 x){return pow2(pow2(pow2(x)*x));}
vec4 pow13(vec4 x){return pow2(pow2(pow2(x)*x))*x;}
vec4 pow14(vec4 x){return pow2(pow2(pow2(x)*x)*x);}
vec4 pow15(vec4 x){return pow2(pow2(pow2(x)*x)*x)*x;}
vec4 pow16(vec4 x){return pow2(pow2(pow2(pow2(x))));}
vec4 pow32(vec4 x){return pow2(pow2(pow2(pow2(pow2(x)))));}
vec4 pow35(vec4 x){return pow2(pow2(pow2(pow2(pow2(x))))*x)*x;}

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)

#define diagonal4(mat) vec4((mat)[0].x, (mat)[1].y, (mat)[2].zw)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, (mat)[2].z)

#define projMAD4(mat, v) (diagonal4(mat) * (v.xyzz) + (mat)[3].xyzw)
#define projMAD3(mat, v) (diagonal3(mat) * (v.xyz) + (mat)[3].xyz)