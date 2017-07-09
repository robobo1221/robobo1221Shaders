vec3 toScreenSpace(mat4 matrix, vec3 p) {
        vec3 p3 = vec3(p) * 2. - 1.;
        vec4 fragposition = projMAD4(matrix, p3);
        return fragposition.xyz / fragposition.w;
}

vec3 toClipSpace(mat4 matrix, vec3 p) {
        vec4 clipPosition = projMAD4(matrix, p);
             clipPosition /= clipPosition.w;
        return clipPosition.xyz * 0.5 + 0.5;
}


vec3 toWorldSpace(mat4 matrix, vec3 fragpos){
	return transMAD(matrix, fragpos);
}

vec3 toWorldSpaceNoMAD(mat4 matrix, vec3 fragpos){
	return mat3(matrix) * fragpos;
}