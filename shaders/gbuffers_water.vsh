#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;

varying vec3 wpos;

varying vec4 verts;

varying float mat;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

void main(){
	mat = 1.0;
	
	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	/* un-rotate */
	vec4 viewpos = gbufferModelViewInverse * position;

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;

	gl_Position = ftransform();
	
	color = gl_Color;
	
	tangent = vec3(0.0);
	binormal = vec3(0.0);
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
		if (gl_Normal.x > 0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  -1.0));
	} else if (gl_Normal.z > 0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( -1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	verts = gl_Vertex;
	
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) mat = 0.2;
	if (mat != 0.2) mat = 0.3;
}