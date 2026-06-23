Shader "VertigoDemo/VFX/WindFlow"
{
    Properties
    {
        [Header(Base)]
        _BaseColor ("Base Color", Color) = (0.2, 0.6, 1.0, 0.5)
        _NoiseTex ("Noise Texture (R)", 2D) = "white" {}
        _SecondNoiseTex ("Second Noise (R)", 2D) = "white" {}

        [Header(Flow)]
        _FlowSpeed ("Flow Speed", Range(0, 5)) = 1.0
        _FlowDirection ("Flow Direction (XY)", Vector) = (1, 0.3, 0, 0)
        _DistortionStrength ("Distortion Strength", Range(0, 1)) = 0.15
        _SecondLayerSpeed ("Second Layer Speed", Range(0, 3)) = 0.7
        _SecondLayerScale ("Second Layer Tiling", Range(0.5, 4)) = 1.5

        [Header(Vertex Displacement)]
        _DisplacementStrength ("Displacement Strength", Range(0, 0.5)) = 0.05
        _DisplacementSpeed ("Displacement Speed", Range(0, 3)) = 1.2

        [Header(Emission)]
        _EmissionColor ("Emission Color", Color) = (0.3, 0.7, 1.0, 1)
        [HDR] _EmissionHDR ("Emission HDR", Color) = (0.5, 1.2, 2.0, 1)
        _EmissionIntensity ("Emission Intensity", Range(0, 5)) = 1.5
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 2.5
        _FresnelIntensity ("Fresnel Intensity", Range(0, 3)) = 1.0

        [Header(Alpha)]
        _AlphaClip ("Alpha Clip", Range(0, 1)) = 0.1
        _SoftEdge ("Soft Edge Width", Range(0, 0.5)) = 0.1

        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
        [Toggle] _ZWrite ("Z Write", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "WindFlow"
            Tags { "LightMode" = "UniversalForward" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 viewDirWS   : TEXCOORD2;
                float  fogFactor   : TEXCOORD3;
            };

            TEXTURE2D(_NoiseTex);       SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_SecondNoiseTex); SAMPLER(sampler_SecondNoiseTex);

            CBUFFER_START(UnityPerMaterial)
                half4  _BaseColor;
                float4 _NoiseTex_ST;
                float4 _SecondNoiseTex_ST;
                half   _FlowSpeed;
                float4 _FlowDirection;
                half   _DistortionStrength;
                half   _SecondLayerSpeed;
                half   _SecondLayerScale;
                half   _DisplacementStrength;
                half   _DisplacementSpeed;
                half4  _EmissionColor;
                half4  _EmissionHDR;
                half   _EmissionIntensity;
                half   _FresnelPower;
                half   _FresnelIntensity;
                half   _AlphaClip;
                half   _SoftEdge;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                float time = _Time.y;
                float2 flowDir = normalize(_FlowDirection.xy);

                float noiseUV_x = dot(input.uv, flowDir) + time * _DisplacementSpeed;
                float noiseSample = sin(noiseUV_x * 6.2831) * 0.5 + 0.5;

                float3 displaced = input.positionOS.xyz
                    + input.normalOS * noiseSample * _DisplacementStrength;

                VertexPositionInputs posInputs = GetVertexPositionInputs(displaced);
                VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS);

                output.positionCS = posInputs.positionCS;
                output.uv = input.uv;
                output.normalWS = normInputs.normalWS;
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(posInputs.positionWS);
                output.fogFactor = ComputeFogFactor(posInputs.positionCS.z);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float time = _Time.y;
                float2 flowDir = normalize(_FlowDirection.xy);

                float2 uv1 = input.uv + flowDir * time * _FlowSpeed;
                half noise1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv1 * _NoiseTex_ST.xy + _NoiseTex_ST.zw).r;

                float2 uv2 = input.uv * _SecondLayerScale - flowDir * time * _SecondLayerSpeed;
                half noise2 = SAMPLE_TEXTURE2D(_SecondNoiseTex, sampler_SecondNoiseTex, uv2 * _SecondNoiseTex_ST.xy + _SecondNoiseTex_ST.zw).r;

                half combinedNoise = noise1 * noise2;

                float2 distortedUV = input.uv + (combinedNoise - 0.5) * _DistortionStrength;
                half distortedNoise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, distortedUV + flowDir * time * _FlowSpeed * 0.8).r;

                half flowMask = saturate(distortedNoise * combinedNoise * 2.0);

                half3 color = lerp(_BaseColor.rgb, _EmissionColor.rgb, flowMask);

                half fresnel = pow(1.0 - saturate(dot(input.normalWS, input.viewDirWS)), _FresnelPower);
                fresnel *= _FresnelIntensity;

                half3 emission = _EmissionHDR.rgb * _EmissionIntensity * (flowMask + fresnel);
                color += emission;

                half alpha = saturate(flowMask * _BaseColor.a + fresnel * 0.5);

                half clipEdge = smoothstep(_AlphaClip, _AlphaClip + _SoftEdge, alpha);
                alpha *= clipEdge;

                color = MixFog(color, input.fogFactor);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
