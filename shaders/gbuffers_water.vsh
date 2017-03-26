#version 120

#define WAVING_WATER  //Makes water wave

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;

varying vec3 wpos;
varying vec3 viewVector;

varying float mat;
varying float dist;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform float frameTimeCounter;

attribute vec4 mc_Entity;

void main(){
	mat = 1.0;
	
	gl_Position = gl_ModelViewMatrix * gl_Vertex;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	vec4 viewpos = gbufferModelViewInverse * gl_Position;

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;

	#ifdef WAVING_WATER
	//Checks if the bottom of a block is touching the block beneath the block it's checking. (Good explaination huh)
	float fy = fract(worldpos.y + 0.001);
	if (fy > 0.02) {

		//Vertex Displacement
		viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 3.0) * 0.5 + 0.5) * (sin(frameTimeCounter) * 0.5 + 0.5) * 0.05;
		viewpos.y += (sin((worldpos.x - worldpos.z) + frameTimeCounter * 4.0) * 0.5 + 0.5) * 0.05;
	}
	#endif

	viewpos = gbufferModelView * viewpos;
	gl_Position = gl_ProjectionMatrix * viewpos;
	
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

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
	  tangent.y, binormal.y, normal.y,
	  tangent.z, binormal.z, normal.z);
	
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);

	dist = length(gl_ModelViewMatrix * gl_Vertex);
	
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) mat = 0.2;
	if (mat != 0.2) mat = 0.3;
}