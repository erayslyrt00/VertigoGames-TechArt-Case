Shader "UI/GradientFadeWithMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _FadeStart ("Fade Start", Range(0,1)) = 0.5
        _FadeEnd ("Fade End", Range(0,1)) = 0.0
        _SoftnessMask ("Softness Mask", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct appdata 
            { 
                float4 vertex : POSITION; 
                float2 uv : TEXCOORD0; 
                float4 color : COLOR; 
            };
            
            struct v2f 
            { 
                float2 uv : TEXCOORD0; 
                float4 vertex : SV_POSITION; 
                float4 color : COLOR; 
                float4 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _Color;
            float _FadeStart;
            float _FadeEnd;
            float4 _ClipRect;
            float4 _SoftnessMask;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color * _Color;
                o.worldPos = v.vertex;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * i.color;
                
                // Alttan gradient fade
                col.a *= smoothstep(_FadeEnd, _FadeStart, i.uv.y);
                
                // Rect Mask 2D desteği
                float2 inside = saturate((_ClipRect.zw - _ClipRect.xy - abs(i.worldPos.xy * 2 - _ClipRect.xy - _ClipRect.zw)) * 0.5 / max(0.001, _SoftnessMask.xy));
                col.a *= inside.x * inside.y;
                
                return col;
            }
            ENDCG
        }
    }
}