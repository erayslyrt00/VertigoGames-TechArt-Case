// Custom URP lit shader for the rifle. Single albedo map; metallic and
// smoothness are derived from albedo luminance and exposed as sliders, so the
// gun reads as mixed metal/polymer without extra texture maps. Optional detail
// normal is synthesized from the albedo gradient.
Shader "VertigoDemo/RifleLit"
{
    Properties
    {
        [MainTexture] _BaseMap        ("Albedo (MainTex)", 2D) = "white" {}
        [MainColor]   _BaseColor      ("Tint", Color) = (1,1,1,1)

        [Header(Surface)]
        _Metallic         ("Metallic", Range(0,1)) = 0.85
        _Smoothness       ("Smoothness", Range(0,1)) = 0.55
        _MetalLumInfluence  ("Metallic from Luminance", Range(0,1)) = 0.6
        _SmoothLumInfluence ("Smoothness from Luminance", Range(0,1)) = 0.4
        _LumPivot         ("Luminance Pivot", Range(0,1)) = 0.5
        _OcclusionStrength("Occlusion (from albedo)", Range(0,1)) = 0.25

        [Header(Procedural Detail Normal)]
        [Toggle(_PROCEDURAL_NORMAL)] _UseProcNormal ("Enable Detail Normal", Float) = 1
        _NormalStrength   ("Detail Normal Strength", Range(0,2)) = 0.4
        _NormalScale      ("Detail Normal Scale", Range(0.1,8)) = 2.0

        [Header(Specular Control)]
        _SpecularTint     ("Specular Tint", Color) = (1,1,1,1)
        _Reflectance      ("Dielectric Reflectance", Range(0,1)) = 0.5

        [Header(Rim)]
        [Toggle(_RIM_ON)] _UseRim ("Enable Rim", Float) = 0
        _RimColorHDR ("Rim Color (HDR)", Color) = (0.2,0.4,0.8,1)
        _RimPower         ("Rim Power", Range(0.5,16)) = 4.0
        _RimIntensity     ("Rim Intensity", Range(0,8)) = 1.0

        [Header(Rendering)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [Toggle(_RECEIVE_SHADOWS_OFF)] _ReceiveShadowsOff ("Disable Receive Shadows", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType"     = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Geometry"
            "IgnoreProjector"= "True"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull [_Cull]
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex   vert
            #pragma fragment frag

            #pragma shader_feature_local _PROCEDURAL_NORMAL
            #pragma shader_feature_local _RIM_ON
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseMap_TexelSize;
                half4  _BaseColor;
                half   _Metallic;
                half   _Smoothness;
                half   _MetalLumInfluence;
                half   _SmoothLumInfluence;
                half   _LumPivot;
                half   _OcclusionStrength;
                half   _NormalStrength;
                half   _NormalScale;
                half4  _SpecularTint;
                half   _Reflectance;
                half4  _RimColorHDR;
                half   _RimPower;
                half   _RimIntensity;
                float  _Cull;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                float2 staticLM   : TEXCOORD1;
                float2 dynamicLM  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : TEXCOORD2;
                half4  tangentWS  : TEXCOORD3; // xyz tangent, w sign
                half3  viewDirWS  : TEXCOORD4;
                half   fogFactor  : TEXCOORD5;
                DECLARE_LIGHTMAP_OR_SH(staticLM, vertexSH, 6);
            #ifdef DYNAMICLIGHTMAP_ON
                float2 dynamicLM  : TEXCOORD7;
            #endif
                float4 shadowCoord: TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            half Luminance709(half3 c) { return dot(c, half3(0.2126h, 0.7152h, 0.0722h)); }

            Varyings vert (Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs posIn = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrmIn = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = posIn.positionCS;
                OUT.positionWS = posIn.positionWS;
                OUT.normalWS   = nrmIn.normalWS;
                OUT.tangentWS  = half4(nrmIn.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
                OUT.viewDirWS  = GetWorldSpaceNormalizeViewDir(posIn.positionWS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.fogFactor  = ComputeFogFactor(posIn.positionCS.z);
                OUT.shadowCoord= GetShadowCoord(posIn);

                OUTPUT_LIGHTMAP_UV(IN.staticLM, unity_LightmapST, OUT.staticLM);
            #ifdef DYNAMICLIGHTMAP_ON
                OUT.dynamicLM = IN.dynamicLM.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            #endif
                OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);
                return OUT;
            }

            // Detail normal from the albedo luminance gradient (Sobel-lite).
            half3 ProceduralNormalTS(float2 uv, half strength, half scale)
            {
                float2 px = _BaseMap_TexelSize.xy * scale;
                half hL = Luminance709(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv - float2(px.x,0)).rgb);
                half hR = Luminance709(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv + float2(px.x,0)).rgb);
                half hD = Luminance709(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv - float2(0,px.y)).rgb);
                half hU = Luminance709(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv + float2(0,px.y)).rgb);
                half3 n = half3((hL - hR) * strength, (hD - hU) * strength, 1.0h);
                return normalize(n);
            }

            half4 frag (Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half  lum    = Luminance709(albedo.rgb);

                // metallic / smoothness / occlusion pulled from albedo luminance
                half lumSigned   = lum - _LumPivot;
                half metallic    = saturate(_Metallic + lumSigned * _MetalLumInfluence);
                half smoothness  = saturate(_Smoothness + lumSigned * _SmoothLumInfluence);
                half occlusion   = lerp(1.0h, saturate(lum * 1.5h), _OcclusionStrength);

                half3 normalWS = normalize(IN.normalWS);
            #ifdef _PROCEDURAL_NORMAL
                half3 tangentWS = normalize(IN.tangentWS.xyz);
                half3 bitangentWS = cross(normalWS, tangentWS) * IN.tangentWS.w;
                half3 nTS = ProceduralNormalTS(IN.uv, _NormalStrength, _NormalScale);
                half3x3 TBN = half3x3(tangentWS, bitangentWS, normalWS);
                normalWS = normalize(mul(nTS, TBN));
            #endif

                half3 viewDirWS = normalize(IN.viewDirWS);

                SurfaceData surf = (SurfaceData)0;
                surf.albedo     = albedo.rgb;
                surf.metallic   = metallic;
                surf.smoothness = smoothness;
                surf.occlusion  = occlusion;
                surf.emission   = half3(0,0,0);
                surf.alpha      = 1.0h;
                // dielectric reflectance tint (remaps the 0.04 baseline)
                surf.specular   = lerp(half3(0,0,0), _SpecularTint.rgb, (1.0h - metallic) * _Reflectance * 0.16h);

                InputData inData = (InputData)0;
                inData.positionWS      = IN.positionWS;
                inData.normalWS        = normalWS;
                inData.viewDirectionWS = viewDirWS;
            #if defined(_RECEIVE_SHADOWS_OFF)
                inData.shadowCoord     = float4(0,0,0,0);
            #else
                inData.shadowCoord     = IN.shadowCoord;
            #endif
                inData.fogCoord        = IN.fogFactor;
                inData.bakedGI         = SAMPLE_GI(IN.staticLM, IN.vertexSH, normalWS);
                inData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
                inData.shadowMask      = SAMPLE_SHADOWMASK(IN.staticLM);

                half4 color = UniversalFragmentPBR(inData, surf);

            #ifdef _RIM_ON
                half rim = pow(saturate(1.0h - dot(normalWS, viewDirWS)), _RimPower);
                color.rgb += _RimColorHDR.rgb * _RimIntensity * rim;
            #endif

                color.rgb = MixFog(color.rgb, IN.fogFactor);
                return half4(color.rgb, 1.0h);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex   ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseMap_TexelSize;
                half4  _BaseColor;
                half   _Metallic;
                half   _Smoothness;
                half   _MetalLumInfluence;
                half   _SmoothLumInfluence;
                half   _LumPivot;
                half   _OcclusionStrength;
                half   _NormalStrength;
                half   _NormalScale;
                half4  _SpecularTint;
                half   _Reflectance;
                half4  _RimColorHDR;
                half   _RimPower;
                half   _RimIntensity;
                float  _Cull;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings   { float4 positionCS:SV_POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };

            float4 GetShadowPositionHClip(Attributes IN)
            {
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 nrmWS = TransformObjectToWorldNormal(IN.normalOS);
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 dir = normalize(_LightPosition - posWS);
            #else
                float3 dir = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(posWS, nrmWS, dir));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                return cs;
            }

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                OUT.positionCS = GetShadowPositionHClip(IN);
                return OUT;
            }
            half4 ShadowFrag(Varyings IN):SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex   DepthVert
            #pragma fragment DepthFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; float4 _BaseMap_TexelSize; half4 _BaseColor;
                half _Metallic; half _Smoothness; half _MetalLumInfluence; half _SmoothLumInfluence;
                half _LumPivot; half _OcclusionStrength; half _NormalStrength; half _NormalScale;
                half4 _SpecularTint; half _Reflectance; half4 _RimColorHDR;
                half _RimPower; half _RimIntensity; float _Cull;
            CBUFFER_END

            struct A { float4 positionOS:POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            V DepthVert(A IN){ V O; UNITY_SETUP_INSTANCE_ID(IN); O.positionCS = TransformObjectToHClip(IN.positionOS.xyz); return O; }
            half4 DepthFrag(V IN):SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex   DNVert
            #pragma fragment DNFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; float4 _BaseMap_TexelSize; half4 _BaseColor;
                half _Metallic; half _Smoothness; half _MetalLumInfluence; half _SmoothLumInfluence;
                half _LumPivot; half _OcclusionStrength; half _NormalStrength; half _NormalScale;
                half4 _SpecularTint; half _Reflectance; half4 _RimColorHDR;
                half _RimPower; half _RimIntensity; float _Cull;
            CBUFFER_END

            struct A { float4 positionOS:POSITION; float3 normalOS:NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; half3 normalWS:TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
            V DNVert(A IN){ V O; UNITY_SETUP_INSTANCE_ID(IN);
                O.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                O.normalWS = TransformObjectToWorldNormal(IN.normalOS); return O; }
            half4 DNFrag(V IN):SV_Target { return half4(normalize(IN.normalWS) * 0.5h + 0.5h, 0.0h); }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
}
