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