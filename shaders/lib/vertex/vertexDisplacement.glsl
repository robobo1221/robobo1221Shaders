

vec3 calculateWavingGrass(vec3 pos, float t, bool hasTop){
    bool topVertex = texcoord.y < mc_midTexCoord.y;
    bool topBlock  = mc_Entity.z > 8.0;

    float magnitude = 0.2;

    if (hasTop) 
    {
        magnitude *= mix(float(topVertex) * 0.5, float(topVertex) * 0.5 + 0.5, float(topBlock));
    } else {
        magnitude *= float(topVertex);
    }

    vec3 windVolume = vec3(0.0);

    windVolume.x = (cos(pos.x * 4.0 + t * 4.0) * 0.5 + 0.5) * 0.5 - cos(pos.z * 2.0 + t * 3.0) * 0.5;
    windVolume.z = cos(pos.z * 1.5 - t * 2.0) * 0.5 - (sin(pos.z * 6.0 - t * 2.5) * 0.5 + 0.5) * 0.5;

    return windVolume * magnitude;
}

vec3 calculateWavingLeaves(vec3 pos, float t){
    float magnitude = 0.07;

    vec3 windVolume = vec3(0.0);

    windVolume.x = (cos(pos.x * 2.0 + t * 4.0) * 0.5 + 0.5) * 0.5 - cos(pos.y + t * 2.0) * 0.5;
    windVolume.y = (cos(pos.x * 4.0 - t * 3.0) * 0.5 + 0.5) * 0.8 - sin(pos.z * 2.0 + t * 2.0) * 0.5;
    windVolume.z = cos(pos.y * 3.0 - t) * 0.5 - (sin(pos.z * 3.0 - t * 2.5) * 0.5 + 0.5) * 0.5;

    return windVolume * magnitude;
}

vec3 doWavingPlants(vec3 pos){
    #if !defined program_gbuffers_terrain && !defined program_shadow
        return pos;
    #endif

    float t = TIME;

    pos += cameraPosition;

    switch(int(mc_Entity.x)){
        case 31:
        case 37:
        case 38: pos += calculateWavingGrass(pos, t, false); break;
        case 175: pos += calculateWavingGrass(pos, t, true); break;
        case 18:
        case 161: pos += calculateWavingLeaves(pos, t); break;
    }
    
    
    pos -= cameraPosition;

    return pos;
}