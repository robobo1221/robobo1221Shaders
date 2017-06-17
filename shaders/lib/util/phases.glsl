#define mc max(c, 0.0)

float RayleighPhase(float c)
{
	/*
	Rayleigh phase function.
			   3
	p(θ) =	________   [1 + cos(θ)^2]
			   16π
	*/

	return (3.0 / (16.0 * pi)) * (mc*mc + 1.0);
}

#undef c

float hgPhase(float c, float g)
{

	/*
	Henyey-Greenstein phase function.
			   1		 		1 − g^2 
	p(θ) =	________   ____________________________
			   4π		[1 + g^2 − 2g cos(θ)]^(3/2)
	*/


	return (1.0 / (4.0 * pi)) * ((1.0 - g*g) / pow((g*g + 1.0) - 2.0*g * c, 1.5));
}

vec3 totalMie(vec3 lambda, vec3 K, float T, float v)
{
	float c = (0.2 * T ) * 10E-18;
	return 0.4343 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
}

vec3 totalRayleigh(vec3 lambda, float n, float N, float pn){
	return (24.0 * pow(pi, 3.0) * ((n*n - 1.0) * (n*n - 1.0)) * (6.0 + 3.0 * pn))
	/ (N * pow(lambda, vec3(4.0)) * ((n*n + 2.0) * (n*n + 2.0)) * (6.0 - 7.0 * pn));
}