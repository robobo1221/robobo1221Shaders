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
    float time = TIME * 0.5;
    float waveAmplitude = 0.07;
    float waveSteepness = 0.7;
    vec2 waveDirection = vec2(1.0, 0.5);

    vec2 anpos = coord * 0.005;

    float waves = 0.0;

    const float r = 0.5;
    const vec2 sc = vec2(sin(r), cos(r));
    const mat2 rot = mat2(sc.y, -sc.x, sc.x, sc.y);

    for (int i = 0; i < 11; ++i){
        vec2 addNoise = (texture2D(noisetex, anpos * inversesqrt(waveLength)).xy * 2.0 - 1.0) * sqrt(waveLength);
        waves += calculateTrochoidalWave(coord + addNoise, waveLength, time, waveDirection, waveAmplitude, waveSteepness);

        waveLength *= 0.7;
        waveAmplitude *= 0.62;
        waveSteepness *= 1.03;

        waveDirection *= rot;
        anpos *= rot;
        time *= 1.1;
    }

    return -waves;
}

vec3 calculateWaveNormals(vec2 coord){
    const float delta = 0.01;
    
    vec2 waves;
    waves.x = generateWaves(coord + vec2(delta, -delta));
    waves.y = generateWaves(coord + vec2(-delta, delta));
    waves -= generateWaves(coord - vec2(delta));

    vec3 normal = vec3(-2.0 * delta, -2.0 * (delta * delta + delta), 4.0 * delta * delta);
    normal.xy *= waves;

    return normalize(normal);
}