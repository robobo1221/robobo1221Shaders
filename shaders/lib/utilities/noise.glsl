const int noiseTextureResolution = 64;
const float rNoiseTexRes = 1.0 / noiseTextureResolution;

#if (defined program_composite0 || defined program_deferred || defined program_gbuffers_water) && defined FRAGMENT
    float calculate2DNoiseSmooth(vec2 p){
        p *= noiseTextureResolution;
        vec2 id = floor(p) * rNoiseTexRes;
        vec2 f = fract(p);
        f = cubeSmooth(f);

        float a = texture2D(noisetex, id).x;
        float b = texture2D(noisetex, id + vec2(1.0, 0.0) * rNoiseTexRes).x;
        float c = texture2D(noisetex, id + vec2(0.0, 1.0) * rNoiseTexRes).x;
        float d = texture2D(noisetex, id + vec2(1.0, 1.0) * rNoiseTexRes).x;

        float x1 = mix(a, b, f.x);
        float x2 = mix(c, d, f.x);

        return mix(x1, x2, f.y);
    }

    float calculate3DNoise(vec3 position){
        float yTile = floor(position.y);
        float yRep  = position.y - yTile;
              yRep = cubeSmooth(yRep);

        const float z = 17.0 * rNoiseTexRes;

        vec2 textureCoord = position.xz * rNoiseTexRes + (yTile * z);
        vec2 noiseTexture = texture2D(noisetex, textureCoord).xy;

        float noise = mix(noiseTexture.x, noiseTexture.y, yRep);

        return cubeSmooth(noise);
    }

    float fbm(vec2 x, vec2 shiftM, const float d, const float m, const int oct) {
        float v = 0.0;
        float a = 0.5;
        vec2 shift = vec2(100.0) * shiftM;
        const mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));

        for (int i = 0; i < oct; ++i) {
            v += a * texture2D(noisetex, x).y;
            x = rot * x * m + shift;
            a *= d;
        }
        return v;
    }


    float fbm(vec3 x, vec3 shiftM, const float d, const float m, const int oct) {
        float v = 0.0;
        float a = 0.5;
        vec3 shift = vec3(100.0) * shiftM;

        for (int i = 0; i < oct; ++i) {
            v += a * calculate3DNoise(x);
            x = x * m + shift;
            a *= d;
        }
        return v;
    }
#endif

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))

#define HASHSCALE1 443.8975
#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
#define HASHSCALE4 vec3(443.897, 441.423, 437.195, 444.129)

//  1 out, 3 in...
float hash13(vec3 p3)
{
	p3  = fract(p3 * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p){
    p = fract(p * HASHSCALE3);
    p += dot(p.zxy, p.yxz + 19.19);
    return fract(vec3(p.x * p.y, p.z * p.x, p.y * p.z));
}
