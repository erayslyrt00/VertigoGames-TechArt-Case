Shader "VertigoDemo/Vignette"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _VignetteColor ("Vignette Color", Color) = (0, 0, 0, 1)
        _Center ("Center", Vector) = (0.5, 0.5, 0, 0)
        _Intensity ("Intensity", Range(0, 5)) = 1.0
        _Roundness ("Roundness", Range(0.01, 2)) = 1.0
        _Smoothness ("Smoothness", Range(0.001, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 _BaseColor;
            float4 _VignetteColor;
            float4 _Center;
            float _Intensity;
            float _Roundness;
            float _Smoothness;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float2 center = _Center.xy;

                // Offset from center
                float2 d = uv - center;

                // Apply roundness: 1 = circle, <1 = horizontal ellipse, >1 = vertical ellipse
                d.y *= _Roundness;

                // Distance from center
                float dist = length(d);

                // Edge of the vignette circle/ellipse
                float edge = 1.0 / max(_Intensity, 0.001);

                // Smoothness controls the transition width
                // Low smoothness = hard cut, high smoothness = soft fade
                float halfSmooth = _Smoothness * edge;
                float vignette = smoothstep(edge - halfSmooth, edge + halfSmooth, dist);

                // Lerp between base and vignette color
                float4 col = lerp(_BaseColor, _VignetteColor, vignette);

                return col;
            }

            ENDHLSL
        }
    }

    FallBack "Unlit/Color"
}