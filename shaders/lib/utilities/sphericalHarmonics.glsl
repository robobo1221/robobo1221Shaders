vec4 ToSH(float value, vec3 dir) {
    const float transferl1 = 0.3849 * PI;
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(rPI * 3.0);

    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 transfer = vec2(PI * sqrt1OverPI, transferl1 * sqrt3OverPI);

    const vec4 foo = halfnhalf.xyxy * transfer.xyyy;

    return foo * vec4(1.0, dir.yzx) * value;
}

vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir) {
    const float sqrt1OverPI = sqrt(rPI);
    const float sqrt3OverPI = sqrt(3.0 * rPI);
    const vec2 halfnhalf = vec2(0.5, -0.5);
    const vec2 sqrtOverPI = vec2(sqrt1OverPI, sqrt3OverPI);
    const vec4 foo = halfnhalf.xyxy * sqrtOverPI.xyyy;

    vec4 sh = foo * vec4(1.0, lightDir.yzx);

    // know to work
    return vec3(
        dot(sh,cR),
        dot(sh,cG),
        dot(sh,cB)
    );
}