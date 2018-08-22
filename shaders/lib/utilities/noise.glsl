#if defined program_composite0 && defined FRAGMENT
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

    float fbm(vec2 x, const float d, const float m, const int oct) {
        float v = 0.0;
        float a = 0.5;
        const vec2 shift = vec2(100.0);
        const mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));

        for (int i = 0; i < oct; ++i) {
            v += a * texture2D(noisetex, x).xy;
            x = rot * x * m + shift;
            a *= d;
        }
        return v;
    }


    float fbm(vec3 x, const float d, const float m, const int oct) {
        float v = 0.0;
        float a = 0.5;
        const vec3 shift = vec3(100.0);

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