precision lowp float;
varying vec2 vTextureCoord;
varying vec4 vColor;

uniform sampler2D uSampler;

uniform float _Time;
uniform float _GridSize;
uniform float _Blur;
uniform float _Distort;

float rand21(vec2 pos)
{
    // multiplied by very large floating point and extracts fractional part
    pos = fract(pos * vec2(123.34, 345.56));
    // mathematical screw tweak
    pos += dot(pos, pos + 34.987);
    return fract(pos.x * pos.y);
}

vec3 RainLayer(vec2 fraguv, float t)
{
    vec2 grid_aspect = vec2(2, 1);
    // fraguv: 0 ~ 1 => uv: 0 ~ _GridSize * grid_aspect
    vec2 uv = fraguv * _GridSize * grid_aspect;
    // animating the grid downward, so drops are falling
    uv.y -= t * 0.25; // up-side down
    // get fractional (-0.5 ~ 0.5)
    vec2 gridd = fract(uv) - 0.5;
    vec2 id = floor(uv);

    // rand21: 0 ~ 1
    float rn = rand21(id);
    // offset time-factor by 0 ~ 2_PI for each grid
    t += rn * 6.2831;

    vec2 move = vec2(0);
    // a more complex sin wave for animating drops
    // horizontal movement
    move.x = (rn - 0.5) * 0.8; // randomly in (-0.4 ~ 0.4)
    // horiz_factor is (0 ~ 0.4), 0 means around the edge of grid
    float horiz_factor = (0.4 - abs(move.x));
    move.x = sin(30.0 * fraguv.y) * pow(sin(10.0 * fraguv.y), 6.0) * horiz_factor;
    // goes downward fastly and upward slowly
    move.y = sin(t + sin(t + sin(t) * 0.5)) * 0.45;
    // adjusts move.y to make sagged drop
    // takes x-bias movement into account to avoid distortion
    move.y += (gridd.x - move.x) * (gridd.x - move.x);

    // animating drop position by (gridd - move)
    // gridd is stretched by grid_aspect, so normalized back
    vec2 drop_pos = (gridd - move) / grid_aspect;
    // define drop shape (w/ signed distance field concept)
    float drop = smoothstep(0.05, 0.03, length(drop_pos));

    // define position for followed little trails
    // - (move.x, -t * 0.25) makes it sticks at the same vertical position
    vec2 trail_pos = (gridd - vec2(move.x, -t * 0.25)) / grid_aspect;
    // slice the grid into 8 pieces for trials, makes it (-0.5 ~ 0.5)
    trail_pos.y = fract(trail_pos.y * 8.0) - 0.5;
    // avoid squeezed distortion, devide by 8 back
    trail_pos.y /= 8.0;
    float trail = smoothstep(0.03, 0.01, length(trail_pos));
    // makes it multiplied by 0 if underneath or by 1 if above the main drop
    float fog_trail = smoothstep(0.05, -0.05, drop_pos.y);
    // makes trail faded out above the main drop
    fog_trail *= smoothstep(-0.5, move.y, gridd.y);
    // controls shape of fog_trail via drop x-position
    fog_trail *= smoothstep(0.05, 0.033, abs(drop_pos.x));

    trail *= fog_trail;

    // drop: distortion intensity of main drop, drop_pos: factor with respect to the drop
    // trail: distortion intensity of trails, trail_pos: factor with respect to the trail
    vec2 offset = drop * drop_pos + trail * trail_pos;

    return vec3 (offset, fog_trail);
}

void main(void)
{
    vec2 uv = vTextureCoord.xy;
    
    float t = mod(_Time, 3600.0); // restart from every 1 hour
    vec3 rain = RainLayer(uv, t);
    rain += RainLayer(uv * 1.25 + 6.48, t * 1.05);
    rain += RainLayer(uv * 1.37 + 7.51, t);
    rain += RainLayer(uv * 1.89 - 11.1, t * 2.01);

    float blur = _Blur * 7.0; // mipmap level (0, 1, 2, 3, 4, 5, 6, 7)
    // clear inside of fog-trail, blurry outside of fog-trail
    blur *= 1.0 - rain.z;

    // seems texture2D with mipmap-LOD not work, no mipmap with input texture?
    //gl_FragColor = texture2D(uSampler, uv + rain.xy * _Distort, blur);
    uv += rain.xy * _Distort;

    vec4 col = vec4(0.0);
    float a = rand21(uv) * 6.2831; // initial random start-rotation for each pixel sampling
    blur *= 0.011;
    const float nsamples = 32.0;
    // iterate nsamples times to sample pixels nearby, and then finally average it
    // because render texture (_GrabTex) has no mipmap
    for (float i = 0.0; i < nsamples; ++i)
    {
        // calculate rotation by a with radius = blur
        vec2 sampleloc = vec2(sin(a), cos(a)) * blur;
        // randomize 'sampleloc' for more natural random sampling
        float noiz = fract(sin((i + 1.0) * 546.7) * 5424.21);
        sampleloc *= sqrt(noiz);
        col += texture2D(uSampler, uv + sampleloc);
        a ++;
    }
    gl_FragColor = col / nsamples;
}

