float GeometrySchlickGGX(float NdotV, float k){
    float denom = NdotV * (1.0 - k) + k;

    return NdotV / denom;
}

vec3 GeometrySmithGGX(vec3 diffuseColor, vec3 N, vec3 V, vec3 L, float r){
	float k = pow2(r + 1.0) * 0.125;
    float NdotL = clamp01(dot(N, L));

    float multiScattering = 0.1159 * r;

    return (diffuseColor * multiScattering * NdotL + GeometrySchlickGGX(NdotL, k)) * rPI;
}

float ExactCorrelatedG2(float alpha2, float NoV, float NoL) {
    float x = 2.0 * NoL * NoV;
    float y = (1.0 - alpha2);

    return x / (NoV * sqrt(alpha2 + y * (NoL * NoL)) + NoL * sqrt(alpha2 + y * (NoV * NoV)));
}

float GGX(float alpha2, float NoH) {
	float d = (NoH * alpha2 - NoH) * NoH + 1.0;

	return alpha2 / (d * d);
}

float SchlickFresnel(float f0, float f90, float LoH) {
    return (f90 - f0) * pow5(1. - LoH) + f0;
}

vec3 ExactFresnel(const vec3 n, const vec3 k, float c) {
    const vec3 k2= k * k;
	const vec3 n2k2 = n * n + k2;

    vec3 c2n = (c * 2.0) * n;
    vec3 c2 = vec3(c * c);

    vec3 rs_num = n2k2 - c2n + c2;
    vec3 rs_den = n2k2 + c2n + c2;

    vec3 rs = rs_num / rs_den;

    vec3 rp_num = n2k2 * c2 - c2n + 1.0;
    vec3 rp_den = n2k2 * c2 + c2n + 1.0;

    vec3 rp = rp_num / rp_den;

    return clamp01(0.5 * (rs + rp));
}

vec3 Fresnel(float f0, float f90, float LoH) {
        return vec3(SchlickFresnel(f0, f90, LoH));
}
