vec2 calculateTemporalJitter() {
    #ifndef TAA
        return vec2(0.0);
    #endif

    const vec2 bayerSequence4x4[16] = vec2[16](vec2(0, -3) / 16.0,
                                           vec2(-8, 11) / 16.0,
                                           vec2(2, 1) / 16.0,
                                           vec2(-10, -9) / 16.0,
                                           vec2(12, -15) / 16.0,
                                           vec2(-4, 7) / 16.0,
                                           vec2(14, 13) / 16.0,
                                           vec2(-6, -5) / 16.0,
                                           vec2(-3, 0) / 16.0,
                                           vec2(11, -8) / 16.0,
                                           vec2(-1, -2) / 16.0,
                                           vec2(9, 10) / 16.0,
                                           vec2(-15, 12) / 16.0,
                                           vec2(7, -4) / 16.0,
                                           vec2(-13, -14) / 16.0,
                                           vec2(5, 6) / 16.0);

    vec2 pixelSize = 0.5 / vec2(viewWidth, viewHeight);
    return (bayerSequence4x4[int(mod(frameCounter, 16))] * 2.0 - 1.0) * pixelSize;
}