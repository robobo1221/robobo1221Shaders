#define rcpln2 1.44269504089

#define fLengthSource(x) sqrt(dotX(x))
#define fExpSource(x) exp2(x * rcpln2)
#define dotXSource(x) dot(x, x)

float dotX(in vec2 x) {
    return dotXSource(x);
}

float dotX(in vec3 x) {
    return dotXSource(x);
}

float dotX(in vec4 x) {
    return dotXSource(x);
}

float fExp(in float x) {
    return fExpSource(x);
}

vec2 fExp(in vec2 x) {
    return fExpSource(x);
}

vec3 fExp(in vec3 x) {
    return fExpSource(x);
}

float fLength(in vec4 x) {
    return fLengthSource(x);
}

float fLength(in vec3 x) {
    return fLengthSource(x);
}

float fLength(in vec2 x) {
    return fLengthSource(x);
}

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)

#define diagonal4(mat) vec4((mat)[0].x, (mat)[1].y, (mat)[2].zw)
#define projMAD4(mat, v) (diagonal4(mat) * (v.xyzz) + (mat)[3].xyzw)