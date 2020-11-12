Shader "Unlit/05_wiggle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize("Grid-Size", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _GridSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed t = _Time.y;
                fixed4 col = 0;
                fixed2 grid_aspect = fixed2(2, 1);
                // i.uv: 0 ~ 1 => uv: 0 ~ _GridSize * grid_aspect
                fixed2 uv = i.uv * _GridSize * grid_aspect;
                // animating the grid downward, so drops are falling
                uv.y += t * 0.25;
                // get fractional (-0.5 ~ 0.5)
                fixed2 gridd = frac(uv) - 0.5;

                fixed2 move = 0;
                // a more complex sin wave for animating drops
                // horizontal movement
                move.x = sin(20 * i.uv.y) * pow(sin(10 * i.uv.y), 6) * 0.45;
                // goes downward fastly and upward slowly
                move.y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
                // adjusts move.y to make sagged drop
                // takes x-bias movement into account to avoid distortion
                move.y -= (gridd.x - move.x) * (gridd.x - move.x);

                // animating drop position by (gridd - move)
                // gridd is stretched by grid_aspect, so normalized back
                fixed2 drop_pos = (gridd - move) / grid_aspect;
                // define drop shape (w/ signed distance field concept)
                fixed drop = smoothstep(0.05, 0.03, length(drop_pos));
                
                // define position for followed little trails
                // - (move.x, t * 0.25) makes it sticks at the same vertical position
                fixed2 trail_pos = (gridd - fixed2(move.x, t * 0.25)) / grid_aspect;
                // slice the grid into 8 pieces for trials, makes it (-0.5 ~ 0.5)
                trail_pos.y = frac(trail_pos.y * 8) - 0.5;
                // avoid squeezed distortion, devide by 8 back
                trail_pos.y /= 8;
                fixed trail = smoothstep(0.03, 0.01, length(trail_pos));
                // makes it multiplied by 0 if underneath or by 1 if above the main drop
                trail *= smoothstep(-0.05, 0.05, drop_pos.y);
                // makes trail faded out above the main drop
                trail *= smoothstep(0.5, move.y, gridd.y);
                
                // renders drops and trails
                col += drop + trail;

                // make grid line color at the edge of each grid
                if (gridd.x > 0.48 || gridd.y > 0.49)
                {
                    col = fixed4(1, 0, 0, 1);
                }

                return col;
            }
            ENDCG
        }
    }
}
