float calculateTrochoidalWave(vec2 coord, float waveLength, float time, vec2 waveDirection, float waveAmplitude, float waveSteepness){
    const float g = 19.6;

    float k = TAU / waveLength;
    float w = sqrt(g * k);

    // Count waves
    float x = w * time - k * dot(waveDirection, coord);
    float wave = sin(x) * 0.5 + 0.5;

    return waveAmplitude * pow(wave, waveSteepness);
}

float generateWaves(vec2 coord){
    float waveLength = 10.0;
    float time = TIME;
    float waveAmplitude = 0.1;
    float waveSteepness = 0.6;
    vec2 waveDirection = vec2(0.5, 1.0);

    float waves = 0.0;

    for (int i = 0; i < 13; ++i){
        waves += calculateTrochoidalWave(coord, waveLength, time, waveDirection, waveAmplitude, waveSteepness);

        waveLength *= 0.7;
        waveDirection = rotate(waveDirection, 1.0);
        waveAmplitude *= 0.6;
        waveSteepness *= 1.03;
        time *= 0.8;
    }

    return -waves;
}

vec3 calculateWaveNormals(vec2 coord){
    const float delta = 0.001;
    const float rDelta = 1.0 / delta;

    float c = generateWaves(coord);
    float h = generateWaves(coord + vec2(delta, 0.0));
    float v = generateWaves(coord + vec2(0.0, delta));

    float dx = (c - h) * rDelta;
    float dy = (c - v) * rDelta;

    return normalize(vec3(dx, dy, 1.0));
}