float GeometrySchlickGGX(float NdotV, float k){
    float denom = NdotV * (1.0 - k) + k;

    return NdotV / denom;
}

vec3 GeometrySmithGGX(vec3 diffuseColor, vec3 N, vec3 V, vec3 L, float r){
	float k = pow2(r + 1.0) * (1.0 / 8.0);

	vec3 H = L + V;

    float NdotH = clamp01(dot(N + H, H));
    float NdotL = clamp01(dot(N, L));

    float ggx1 = GeometrySchlickGGX(NdotH, k);
    float ggx2 = GeometrySchlickGGX(NdotL, k);

    float multiScattering = 0.1159 * r;

    return (diffuseColor * multiScattering + ggx1 * ggx2) * sqrt(NdotL);
}

float specularGGX(vec3 n, vec3 v, vec3 l, float r, float F0) {
  r*=r;r*=r;

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp01(dot(h,l)*hn);
  float dotNH = clamp01(dot(h,n)*hn);
  float dotNL = clamp01(dot(n,l));

  float denom = (dotNH * r - dotNH) * dotNH + 1.;
  float D = r / (PI * denom * denom);
  float F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}

float DistributionGGX(vec3 N, vec3 H, float a)
{
    float a2     = a*a;
    float NdotH  = clamp01(dot(N, H));
    float NdotH2 = NdotH*NdotH;

    float denom  = (NdotH2 * (a2 - 1.0) + 1.0);

    return a2 * pow(denom, -2.0) * rPI;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0){
	cosTheta = 1.0 - cosTheta;
    return (1.0 - F0) * pow5(cosTheta) + F0;
}
