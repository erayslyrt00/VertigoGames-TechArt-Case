Shader "VertigoDemo/VFX/WindLines"
{
    Properties
    {
        _WindColor ("Wind Color", Color) = (0.4, 0.345, 0.086, 1)
        [HDR] _LineColor ("Line Color", Color) = (1.977, 1.625, 0.31, 1)
        _Intensity ("Intensity", Range(0, 4)) = 1.3

        _LineCount ("Line Count", Range(1, 8)) = 3
        _LineSharpness ("Line Sharpness", Range(1, 16)) = 6

        _WindSpeed ("Wind Speed", Float) = 0.6
        _FlowTiling ("Flow Tiling", Float) = 3
        _FlowFloor ("Flow Floor", Range(0, 1)) = 0.4

        _WaveAmount ("Wave Amount", Range(0, 0.5)) = 0.08
        _WaveFreq ("Wave Frequency", Float) = 4
        _WaveSpeed ("Wave Speed", Float) = 1.2

        _EndFade ("End Fade", Range(0, 4)) = 0.7
        _Desync ("Desync", Range(0, 4)) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Blend One One
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float seed : TEXCOORD1;
                float flowZ : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _WindColor;
                half4 _LineColor;
                half _Intensity;
                half _LineCount;
                half _LineSharpness;
                half _WindSpeed;
                half _FlowTiling;
                half _FlowFloor;
                half _WaveAmount;
                half _WaveFreq;
                half _WaveSpeed;
                half _EndFade;
                half _Desync;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                o.seed = dot(v.positionOS.xyz, float3(1.7, 2.3, 1.1)) * _Desync;
                o.flowZ = v.positionOS.z;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                float t = _Time.y;
                float2 uv = i.uv.yx;
                half along = uv.x;
                half across = uv.y;

                half wave = sin(along * _WaveFreq + t * _WaveSpeed + i.seed) * _WaveAmount;
                half d = abs(frac(across * _LineCount + wave) * 2 - 1);
                half lines = pow(saturate(1 - d), _LineSharpness);

                float phase = i.flowZ * _FlowTiling - t * _WindSpeed + i.seed;
                half flow = sin(phase * 6.2831) * 0.5 + 0.5;
                flow *= sin(phase * 2.7 + 1.3) * 0.25 + 0.75;
                flow = lerp(_FlowFloor, 1, flow);

                half ends = pow(saturate(4 * along * (1 - along)), _EndFade);

                half mask = saturate(lines * flow * ends * _Intensity);
                clip(mask - 0.003);

                half3 col = lerp(_WindColor.rgb, _LineColor.rgb, mask) + _LineColor.rgb * mask * mask;
                return half4(col * mask, mask);
            }
            ENDHLSL
        }
    }
}
