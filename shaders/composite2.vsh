#version 120

varying vec4 texcoord;

varying vec3 upVec;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform int worldTime;

float timefract = worldTime;

void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = sunVec;
	}

	else {
		lightVector = moonVec;
	}
}