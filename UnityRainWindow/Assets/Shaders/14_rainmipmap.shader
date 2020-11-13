﻿Shader "Unlit/14_rainmipmap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize("Grid-Size", float) = 1
        _Distort("Distortion", range(-4, 4)) = 1
        _Blur("Blur", range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent" }
        LOD 100

        // define pre-pass to grab pre-rendered screen as render texture
        GrabPass { "_GrabTex" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 grabuv : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex, _GrabTex;
            float4 _MainTex_ST;
            float _GridSize, _Distort, _Blur;

            float rand21(fixed2 pos)
            {
                // multiplied by very large floating point and extracts fractional part
                pos = frac(pos * float2(123.34, 345.56));
                // mathematical screw tweak
                pos += dot(pos, pos + 34.987);
                return frac(pos.x * pos.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // ComputeGrabScreenPos(): computes texture coordinate for sampling a GrabPass texure
                // UNITY_PROJ_COORD(): returns a texture coordinate suitable for projected Texture reads
                // ref: https://forum.unity.com/threads/unity_proj_coord-where-is-the-explanation-i-cannot-find-it.154404/
                //o.grabuv = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex));
                o.grabuv = ComputeGrabScreenPos(o.vertex);

                return o;
            }

            float3 RainLayer(float2 fraguv, float t)
            {
                float2 grid_aspect = fixed2(2, 1);
                // fraguv: 0 ~ 1 => uv: 0 ~ _GridSize * grid_aspect
                float2 uv = fraguv * _GridSize * grid_aspect;
                // animating the grid downward, so drops are falling
                uv.y += t * 0.25;
                // get fractional (-0.5 ~ 0.5)
                float2 gridd = frac(uv) - 0.5;
                float2 id = floor(uv);

                // rand21: 0 ~ 1
                float rn = rand21(id);
                // offset time-factor by 0 ~ 2_PI for each grid
                t += rn * 6.2831;

                float2 move = 0;
                // a more complex sin wave for animating drops
                // horizontal movement
                move.x = (rn - 0.5) * 0.8; // randomly in (-0.4 ~ 0.4)
                // horiz_factor is (0 ~ 0.4), 0 means around the edge of grid
                float horiz_factor = (0.4 - abs(move.x));
                move.x = sin(30 * fraguv.y) * pow(sin(10 * fraguv.y), 6) * horiz_factor;
                // goes downward fastly and upward slowly
                move.y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
                // adjusts move.y to make sagged drop
                // takes x-bias movement into account to avoid distortion
                move.y -= (gridd.x - move.x) * (gridd.x - move.x);

                // animating drop position by (gridd - move)
                // gridd is stretched by grid_aspect, so normalized back
                float2 drop_pos = (gridd - move) / grid_aspect;
                // define drop shape (w/ signed distance field concept)
                float drop = smoothstep(0.05, 0.03, length(drop_pos));

                // define position for followed little trails
                // - (move.x, t * 0.25) makes it sticks at the same vertical position
                float2 trail_pos = (gridd - float2(move.x, t * 0.25)) / grid_aspect;
                // slice the grid into 8 pieces for trials, makes it (-0.5 ~ 0.5)
                trail_pos.y = frac(trail_pos.y * 8) - 0.5;
                // avoid squeezed distortion, devide by 8 back
                trail_pos.y /= 8;
                float trail = smoothstep(0.03, 0.01, length(trail_pos));
                // makes it multiplied by 0 if underneath or by 1 if above the main drop
                float fog_trail = smoothstep(-0.05, 0.05, drop_pos.y);
                // makes trail faded out above the main drop
                fog_trail *= smoothstep(0.5, move.y, gridd.y);
                // controls shape of fog_trail via drop x-position
                fog_trail *= smoothstep(0.05, 0.033, abs(drop_pos.x));

                trail *= fog_trail;

                // drop: distortion intensity of main drop, drop_pos: factor with respect to the drop
                // trail: distortion intensity of trails, trail_pos: factor with respect to the trail
                fixed2 offset = drop * drop_pos + trail * trail_pos;

                return float3 (offset, fog_trail);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 3600); // restart from every 1 hour
                float4 col = 0;

                float3 rain = RainLayer(i.uv, t);
                rain += RainLayer(i.uv * 1.25 + 6.48, t * 1.05);
                rain += RainLayer(i.uv * 1.37 + 7.51, t);
                rain += RainLayer(i.uv * 1.89 - 11.1, t * 2);

                // fwidth(): sum of the absolute value of derivatives in x and y
                float mipfade = fwidth(i.uv);
                // when far away, mipfade ~> 0, when nearby, mipfade ~> 1
                mipfade = 1 - saturate(mipfade * 60);
                float blur = _Blur * 7; // blurriness mimics mipmap level (0, 1, 2, 3, 4, 5, 6, 7)
                // clear inside of fog-trail, blurry outside of fog-trail
                blur *= 1 - rain.z * mipfade; // rain-drops effect multiplied by mipfade

                // input clip-space UV needs to be normalized by w-component
                float2 grabuv = i.grabuv.xy / i.grabuv.w;
                grabuv += rain.xy * _Distort * mipfade; // adds drop effect (multiplied by mipfade)

                float a = rand21(i.uv) * 6.2831; // initial random start-rotation for each pixel sampling
                blur *= 0.011;
                const float nsamples = 32;
                // iterate nsamples times to sample pixels nearby, and then finally average it
                // because render texture (_GrabTex) has no mipmap
                for (int i = 0; i < nsamples; ++i)
                {
                    // calculate rotation by a with radius = blur
                    float2 sampleloc = float2(sin(a), cos(a)) * blur;
                    // randomize 'sampleloc' for more natural random sampling
                    float noiz = frac(sin((i + 1) * 546.7) * 5424.21);
                    sampleloc *= sqrt(noiz);
                    col += tex2D(_GrabTex, grabuv + sampleloc);
                    a ++;
                }
                col /= nsamples;

                return col;
            }
            ENDCG
        }
    }
}
