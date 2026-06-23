Shader "VertigoDemo/VFX/WindLines"
{
    Properties
    {
        [NoScaleOffset] _NoiseTex ("Noise", 2D) = "gray" {}

        _WindColor ("Edge Color", Color) = (0.4, 0.345, 0.086, 1)
        [HDR] _LineColor ("Core Color", Color) = (1.977, 1.625, 0.31, 1)
        _Intensity ("Intensity", Range(0, 4)) = 1.3

        _CoreThickness ("Core Thickness", Range(0, 1)) = 0.25
        _EdgeSoftness ("Edge Softness", Range(0.01, 1)) = 0.4

        _AuraScale ("Aura Scale Y", Float) = 2
        _AuraStrength ("Aura Strength", Range(0, 1)) = 0.5

        _StreakScaleX ("Streak Scale X", Float) = 0.02
        _StreakScaleY ("Streak Scale Y", Float) = 15
        _StreakSpeed ("Streak Speed", Float) = 0.5
        _StreakThreshold ("Streak Threshold", Range(0, 1)) = 0.5
        _StreakSoftness ("Streak Softness", Range(0.01, 1.0)) = 0.1
        _StreakIntensity ("Streak Intensity", Float) = 2.0

        _StreakYPosition ("Streak Y Position", Range(0, 1)) = 0.4
        _StreakSpread ("Streak Spread", Range(0.05, 1)) = 0.4
        _StreakEdgeFade ("Streak Edge Fade", Range(0.001, 0.5)) = 0.12

        _WaveAmount ("Wave Amount (object space)", Float) = 0.02
        _WaveFreq ("Wave Frequency", Float) = 3
        _WaveSpeed ("Wave Speed", Float) = 1

        _FadeIn ("Fade In", Range(0, 0.5)) = 0.15
        _FadeOut ("Fade Out", Range(0, 0.5)) = 0.15
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _WindColor;
                half4 _LineColor;
                half _Intensity;
                half _CoreThickness;
                half _EdgeSoftness;
                half _AuraScale;
                half _AuraStrength;
                half _StreakScaleX;
                half _StreakScaleY;
                half _StreakSpeed;
                half _StreakThreshold;
                half _StreakSoftness;
                half _StreakIntensity;
                half _StreakYPosition;
                half _StreakSpread;
                half _StreakEdgeFade;
                half _WaveAmount;
                half _WaveFreq;
                half _WaveSpeed;
                half _FadeIn;
                half _FadeOut;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o;
                // snake the ribbon as geometry so the noise UVs stay put (no jitter)
                half wave = sin(v.uv.x * _WaveFreq - _Time.y * _WaveSpeed) * _WaveAmount;
                float3 posOS = v.positionOS.xyz + v.normalOS * wave;
                o.positionCS = TransformObjectToHClip(posOS);
                o.uv = (half2)v.uv;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half along = i.uv.x;
                half width = i.uv.y;

                // shared flow so aura and streaks break at the same spots
                float flowX = along * _StreakScaleX - _Time.y * _StreakSpeed;

                half streakN = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, float2(flowX, width * _StreakScaleY)).r;
                half streak = smoothstep(_StreakThreshold, _StreakThreshold + _StreakSoftness, streakN);

                half auraN = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, float2(flowX, width * _AuraScale)).r;
                half aura = auraN * _AuraStrength;

                half vBias = saturate((_StreakYPosition + _StreakSpread - width) / _StreakSpread);
                half vFade = saturate(min(width, 1.0 - width) / _StreakEdgeFade);

                half flow = saturate((aura + streak * _StreakIntensity) * vBias * vFade);

                half dist = abs(width * 2.0 - 1.0);
                half core = 1.0 - smoothstep(_CoreThickness, _CoreThickness + _EdgeSoftness, dist);

                half ends = smoothstep(0, _FadeIn, along) * smoothstep(0, _FadeOut, 1.0 - along);

                half mask = flow * core * ends;

                half3 col = lerp(_WindColor.rgb, _LineColor.rgb, mask);
                return half4(col, saturate(mask * _Intensity));
            }
            ENDHLSL
        }
    }
}
