Shader "Unlit/03_moving"
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
                // goes downward fastly and upward slowly
                move.y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
                // animating drop position by (gridd - move)
                // gridd is stretched by grid_aspect, so normalized back
                fixed2 drop_pos = (gridd - move) / grid_aspect;
                
                // define drop shape (w/ signed distance field concept)
                float drop = smoothstep(0.05, 0.03, length(drop_pos));
                col += drop;

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
