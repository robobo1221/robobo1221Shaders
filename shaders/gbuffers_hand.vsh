#version 120

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 color;
varying vec4 vtexcoordam;
varying vec4 vtexcoord;

varying vec3 normal;
varying vec3 viewVector;
varying mat3 tbnMatrix;

varying float mat;
varying float dist;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

void main(){
	mat = 0.86;
	
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	vec2 midcoord = (mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.st-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
	vtexcoordam.st  = min(texcoord.st,midcoord-texcoordminusmid);
	vtexcoord.st    = sign(texcoordminusmid) * 0.5 + 0.5;
	
	gl_Position = ftransform();
	
	color = gl_Color;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, normal));

	tbnMatrix = transpose(mat3(tangent, binormal, normal));
	 
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = sqrt(dot(gl_ModelViewMatrix * gl_Vertex,gl_ModelViewMatrix * gl_Vertex));
}