float calculateScatterIntergral(float opticalDepth, const float coeff){
    const float a = -coeff * rLOG2;
    const float b = -1.0 / coeff;
    const float c =  1.0 / coeff;

    return exp2(a * opticalDepth) * b + c;
}

vec3 calculateScatterIntergral(float opticalDepth, const vec3 coeff){
    const vec3 a = -coeff * rLOG2;
    const vec3 b = -1.0 / coeff;
    const vec3 c =  1.0 / coeff;

    return exp2(a * opticalDepth) * b + c;
}

float phaseG(float vDotL, const float g){
    const float gg = g * g;
    return 0.25 * (1.0 - gg) * pow(gg + 1.0 - 2.0 * g * vDotL, -1.5);
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float calculateCloudPhase(float vDotL){
    const float a = 0.7;
    const float mixer = 0.8;

    float g1 = phaseG(vDotL, 0.8 * a);
    float g2 = phaseG(vDotL, -0.5 * a);

    return mix(g2, g1, mixer);
}
