const vec2 bayerSequence4x4[16] = vec2[16](vec2(0, 3),
                                           vec2(8, 11),
                                           vec2(2, 1),
                                           vec2(10, 9),
                                           vec2(12, 15),
                                           vec2(4, 7),
                                           vec2(14, 13),
                                           vec2(6, 5),
                                           vec2(3, 0),
                                           vec2(11, 8),
                                           vec2(1, 2),
                                           vec2(9, 10),
                                           vec2(15, 12),
                                           vec2(7, 4),
                                           vec2(13, 14),
                                           vec2(5, 6));

vec2 calculateTemporalJitter() {
    vec2 pixelSize = 2.0 / vec2(viewWidth, viewHeight);
    return (bayerSequence4x4[int(mod(frameCounter, 16))] * (2.0 / 15.0) - 1.0) * pixelSize;
}