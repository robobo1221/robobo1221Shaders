#define g(a) (-4.*a.x*a.y+3.*a.x+a.y*2.)

float bayer16x16(vec2 p){

    vec2 m0 = vec2(mod(floor(p * 0.125), 2.));
    vec2 m1 = vec2(mod(floor(p * 0.25 ), 2.));
    vec2 m2 = vec2(mod(floor(p * 0.5  ), 2.));
    vec2 m3 = vec2(mod(floor(p        ), 2.));

    return (g(m0)+g(m1)*4.0+g(m2)*16.0+g(m3)*64.0)/255.;
}
#undef g

float dither = bayer16x16(gl_FragCoord.xy);