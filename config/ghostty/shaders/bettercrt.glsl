// Original shader collected from: https://www.shadertoy.com/view/WsVSzV
// Licensed under Shadertoy's default since the original creator didn't provide any license. (CC BY NC SA 3.0)
// Slight modifications were made to give a green-ish effect.

// This shader was modified by April Hall (arithefirst)
// Sourced from https://github.com/m-ahdal/ghostty-shaders/blob/main/retro-terminal.glsl
// Changes made:
// - Removed tint
// - Made the boundaries match ghostty's background color

float warp = 0.2; // simulate curvature of CRT monitor
float scan = 0.75; // simulate darkness between scanlines
float speed = 30.0; // scanline scroll speed

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // squared distance from center
    vec2 uv = fragCoord / iResolution.xy;
    vec2 dc = abs(0.5 - uv);
    dc *= dc;

    // warp the fragment coordinates
    uv.x -= 0.5; uv.x *= 1.0 + (dc.y * (0.3 * warp)); uv.x += 0.5;
    uv.y -= 0.5; uv.y *= 1.0 + (dc.x * (0.4 * warp)); uv.y += 0.5;

    // static fine scanlines (every other row)
    float fineScan = 0.5 + 0.5 * sin(fragCoord.y * 3.14159);

    // rolling band that sweeps upward across the screen
    float roll = sin(uv.y * 6.28318 - iTime * 1.5) * 0.5 + 0.5;
    roll = roll * roll * 1.5; // sharpen the band edge

    // combine: fine scanlines + gentle rolling band
    float apply = fineScan * 0.5 * scan + roll * 0.08;

    // sample the texture
    vec3 color = texture(iChannel0, uv).rgb;

    // mix the sampled color with the scanline intensity
    fragColor = vec4(mix(color, vec3(0.0), apply), 1.0);
}
