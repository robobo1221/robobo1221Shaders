const float PI 		= acos(-1.0);
const float TAU 	= PI * 2.0;
const float hPI 	= PI * 0.5;
const float rPI 	= 1.0 / PI;
const float rTAU 	= 1.0 / TAU;

const float PHI		= sqrt(5.0) * 0.5 + 0.5;
const float rLOG2	= 1.0 / log(2.0);

#define clamp01(x) clamp(x, 0.0, 1.0)
#define max0(x) max(x, 0.0)
#define min0(x) min(x, 0.0)
#define max3(a) max(max(a.x, a.y), a.z)

#define fsign(x) (clamp01(x * 1e35) * 2.0 - 1.0)
#define fstep(x,y) clamp01((y - x) * 1e35)

#define diagonal2(m) vec2((m)[0].x, (m)[1].y)
#define diagonal3(m) vec3(diagonal2(m), m[2].z)
#define diagonal4(m) vec4(diagonal3(m), m[2].w)

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)
#define projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define encodeColor(x) (x * 0.001)
#define decodeColor(x) (x * 1000.0)

#define lumCoeff vec3(0.2125, 0.7154, 0.0721)

vec3 clampNormal(vec3 n, vec3 v){
    float NoV = clamp( dot(n, -v), 0., 1. );
    return normalize( NoV * v + n );
}

const vec3 blackbody(const float t){
    // http://en.wikipedia.org/wiki/Planckian_locus

    const vec4 vx = vec4(-0.2661239e9,-0.2343580e6,0.8776956e3,0.179910);
    const vec4 vy = vec4(-1.1063814,-1.34811020,2.18555832,-0.20219683);
    const float it = 1./t;
    const float it2= it*it;
    const float x = dot(vx,vec4(it*it2,it2,it,1.));
    const float x2 = x*x;
    const float y = dot(vy,vec4(x*x2,x2,x,1.));
    const float z = 1. - x - y;
    
    // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    const mat3 xyzToSrgb = mat3(
         3.2404542,-1.5371385,-0.4985314,
        -0.9692660, 1.8760108, 0.0415560,
         0.0556434,-0.2040259, 1.0572252
    );

    const vec3 srgb = vec3(x/y,1.,z/y) * xyzToSrgb;
    return max(srgb,0.);
}

vec3 srgbToLinear(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}

vec3 linearToSRGB(vec3 linear){
    return mix(
        linear * 12.92,
        pow(linear, vec3(1./2.4) ) * 1.055 - .055,
        step( .0031308, linear )
    );
}

#include "/lib/options/lightingOptions.glsl"
#include "/lib/options/cameraOptions.glsl"

#include "/lib/utilities/pow.glsl"
#include "/lib/utilities/encoding.glsl"
