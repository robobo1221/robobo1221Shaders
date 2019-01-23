float calculateScatterIntergral(float stepTransmittance, const float coeff){
    const float a = -1.0 / coeff;

    return stepTransmittance * a - a;
}

vec3 calculateScatterIntergral(float opticalDepth, const vec3 coeff){
    const vec3 a = -coeff * rLOG2;
    const vec3 b = -1.0 / coeff;

    return exp2(a * opticalDepth) * b - b;
}

float phaseG(float cosTheta, const float g){
	const float gg = g * g;
	return rPI * (gg * -0.25 + 0.25) * pow(-2.0 * (g * cosTheta) + (gg + 1.0), -1.5);
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) * rPI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float calculateCloudPhase(float vDotL){
    const float a = 0.7;
    const float mixer = 0.8;

    float g1 = phaseG(vDotL, 0.9 * a);
    float g2 = phaseG(vDotL, -0.5 * a);

    return mix(g2, g1, mixer);
}
