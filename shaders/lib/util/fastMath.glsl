#define inversesqrt(x) (1.0 / sqrt(x))

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

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)

#define diagonal4(mat) vec4((mat)[0].x, (mat)[1].y, (mat)[2].zw)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, (mat)[2].z)

#define projMAD4(mat, v) (diagonal4(mat) * (v.xyzz) + (mat)[3].xyzw)
#define projMAD3(mat, v) (diagonal3(mat) * (v.xyz) + (mat)[3].xyz)