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

float GSpecular(float alpha2, float NoV, float NoL) {
    float x = 2.0 * NoL * NoV;
    float y = (1.0 - alpha2);

    return x / (NoV * sqrt(alpha2 + y * (NoL * NoL)) + NoL * sqrt(alpha2 + y * (NoV * NoV)));
}

float GGXDistribution(const float alpha2, const float NoH) {
	float d = (NoH * alpha2 - NoH) * NoH + 1.0;

	return alpha2 / (PI * d * d);
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
    /*
    if(f0 > 0.985) {
		const vec3 chromeIOR = vec3(3.1800, 3.1812, 2.3230);
        const vec3 chromeK = vec3(3.3000, 3.3291, 3.1350);
 		return ExactFresnel(chromeIOR, chromeK, LoH);
	} else if(f0 > 0.965) {
        const vec3 goldIOR = vec3(0.18299, 0.42108, 1.3734);
        const vec3 goldK = vec3(3.4242, 2.3459, 1.7704);
         return ExactFresnel(goldIOR, goldK, LoH);
    } else if(f0 > 0.45) {
        const vec3 ironIOR = vec3(2.9114, 2.9497, 2.5845);
        const vec3 ironK = vec3(3.0893, 2.9318, 2.7670);
         return ExactFresnel(ironIOR, ironK, LoH);
    } else { */
        return vec3(SchlickFresnel(f0, f90, LoH));
    //}
}
