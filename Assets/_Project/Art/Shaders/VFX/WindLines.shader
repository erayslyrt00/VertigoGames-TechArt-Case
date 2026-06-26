Shader "VertigoDemo/VFX/WindLines"
{
    Properties
    {
        [NoScaleOffset] _NoiseTex ("Noise", 2D) = "gray" {}

        _WindColor ("Edge Color", Color) = (0.4, 0.345, 0.086, 1)
        [HDR] _LineColor ("Core Color", Color) = (1.977, 1.625, 0.31, 1)
        _Intensity ("Intensity", Range(0, 4)) = 1.3

        [Header(Aura)]
        _AuraScaleX ("Aura Scale X", Float) = 0.05
        _AuraScaleY ("Aura Scale Y", Float) = 2
        _AuraSpeed ("Aura Speed", Float) = 0.3
        _AuraStrength ("Aura Strength", Range(0, 1)) = 0.5
        _AuraEdgeFade ("Aura Edge Fade", Range(0.001, 0.5)) = 0.2

        [Header(Streak)]
        _StreakScaleX ("Streak Scale X", Float) = 15.0
        _StreakSpeed ("Streak Speed", Float) = 5.0
        _StreakIntensity ("Streak Intensity", Float) = 2.0
        _StreakHeight ("Streak Max Height", Range(0.01, 1)) = 0.3
        _StreakEdge ("Streak Vertical Softness", Range(0.001, 1)) = 0.1
        _UVEdgeFade ("UV Edge Fade", Range(0.001, 0.5)) = 0.05

        _StreakDashSpread ("Dash Gap Spread", Range(0.0, 1.0)) = 0.5
        _StreakDashSoftness ("Dash Gradient Softness", Range(0.01, 1.0)) = 0.3
        _StreakDashMinThickness ("Dash Min Thickness Multiplier", Range(0.0, 1.0)) = 0.5
        _StreakDashMinOpacity ("Dash Min Opacity", Range(0.0, 1.0)) = 0.25

        [Header(Ribbon)]
        _WaveAmount ("Wave Amount (UV Space)", Float) = 0.05
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
                half _AuraScaleX;
                half _AuraScaleY;
                half _AuraSpeed;
                half _AuraStrength;
                half _AuraEdgeFade;
                half _StreakScaleX;
                half _StreakSpeed;
                half _StreakIntensity;
                half _StreakHeight;
                half _StreakEdge;
                half _UVEdgeFade;
                half _StreakDashSpread;
                half _StreakDashSoftness;
                half _StreakDashMinThickness;
                half _StreakDashMinOpacity;
                half _WaveAmount;
                half _WaveFreq;
                half _WaveSpeed;
                half _FadeIn;
                half _FadeOut;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = (half2)v.uv;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half along = i.uv.x;

                // ribbon ripple, shifted on the V axis
                half wave = sin(along * _WaveFreq - _Time.y * _WaveSpeed) * _WaveAmount;
                half width = i.uv.y + wave;

                // aura: soft scrolling glow, independent scale/speed, fills the band
                float auraX = along * _AuraScaleX - _Time.y * _AuraSpeed;
                half auraN = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, float2(auraX, width * _AuraScaleY)).r;
                half auraV = saturate(min(width, 1.0 - width) / _AuraEdgeFade);
                half aura = auraN * _AuraStrength * auraV;

                // streak: continuous line whose height/opacity dip on the moving gaps
                float dashWave = sin(along * _StreakScaleX - _Time.y * _StreakSpeed) * 0.5 + 0.5;
                half dashMask = smoothstep(_StreakDashSpread, _StreakDashSpread + _StreakDashSoftness, dashWave);

                half currentThickness = lerp(_StreakHeight * _StreakDashMinThickness, _StreakHeight, dashMask);
                half currentOpacity = lerp(_StreakDashMinOpacity, 1.0, dashMask);

                half topCut = 1.0 - smoothstep(currentThickness - _StreakEdge, currentThickness, width);
                half waveBottomCut = smoothstep(0.0, _UVEdgeFade, width);
                // clamp to the raw UV so the wave can't bleed past the ribbon
                half uvBounds = smoothstep(0.0, _UVEdgeFade, i.uv.y) * smoothstep(1.0, 1.0 - _UVEdgeFade, i.uv.y);

                half streakShape = topCut * waveBottomCut * uvBounds;
                half streak = streakShape * currentOpacity * _StreakIntensity;

                half ends = smoothstep(0, _FadeIn, along) * smoothstep(0, _FadeOut, 1.0 - along);

                half mask = saturate(aura + streak) * ends;
                half3 col = lerp(_WindColor.rgb, _LineColor.rgb, mask);
                return half4(col, saturate(mask * _Intensity));
            }
            ENDHLSL
        }
    }
}
