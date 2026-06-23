Shader "UI/ScrollingTextureWithGlow"
{
    Properties
    {
        [Header(Base)]
        _Color ("Base Color", Color) = (0.18, 0.07, 0.36, 1)

        [Header(Pattern)]
        [NoScaleOffset] _PatternTex ("Pattern (Repeat wrap)", 2D) = "black" {}
        _PatternColor ("Pattern Tint", Color) = (0.45, 0.22, 0.8, 1)
        _PatternOpacity ("Pattern Opacity", Range(0, 1)) = 0.35
        _PatternScale ("Pattern Scale (repeats / height)", Float) = 5
        _PatternRotation ("Pattern Rotation (deg)", Range(0, 360)) = 18
        _ScrollSpeed ("Scroll Speed (X,Y)", Vector) = (0.01, 0.015, 0, 0)

        [Header(Center Glow)]
        [HDR] _GlowColor ("Glow Color", Color) = (0.6, 0.35, 1, 1)
        _GlowIntensity ("Glow Intensity", Range(0, 2)) = 0.5
        _GlowSize ("Glow Size", Range(0.05, 2)) = 0.7
        _GlowCenter ("Glow Center (X,Y)", Vector) = (0.5, 0.55, 0, 0)

        [Header(Vignette)]
        _VignetteStrength ("Vignette Strength", Range(0, 1)) = 0.35
        _VignetteSoftness ("Vignette Softness", Range(0.01, 1)) = 0.6

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        ColorMask [_ColorMask]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP
            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
                float4 color  : COLOR;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float4 color    : COLOR;
                float4 worldPos : TEXCOORD1;
            };

            sampler2D _PatternTex;
            float4 _Color;
            float4 _PatternColor;
            float  _PatternOpacity;
            float  _PatternScale;
            float  _PatternRotation;
            float4 _ScrollSpeed;
            float4 _GlowColor;
            float  _GlowIntensity;
            float  _GlowSize;
            float4 _GlowCenter;
            float  _VignetteStrength;
            float  _VignetteSoftness;
            float4 _ClipRect;

            v2f vert(appdata v)
            {
                v2f o;
                o.worldPos = v.vertex;
                o.vertex   = UnityObjectToClipPos(o.worldPos);
                o.uv       = v.uv;
                o.color    = v.color;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float aspect = _ScreenParams.x / _ScreenParams.y;

                float2 p = i.uv - 0.5;
                p.x *= aspect;

                float a = radians(_PatternRotation);
                float sa = sin(a), ca = cos(a);
                p = float2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);

                float2 patternUV = p * _PatternScale + _ScrollSpeed.xy * _Time.y;
                fixed4 pattern = tex2D(_PatternTex, patternUV);

                fixed3 col = _Color.rgb;
                col = lerp(col, _PatternColor.rgb, _PatternOpacity * pattern.a);

                float2 delta = i.uv - _GlowCenter.xy;
                delta.x *= aspect;
                float gd = length(delta);
                float glow = exp(-(gd * gd) / max(_GlowSize * _GlowSize, 1e-4));
                col += _GlowColor.rgb * glow * _GlowIntensity;

                float2 vd = (i.uv - 0.5) * 2.0;
                float vignette = 1.0 - smoothstep(_VignetteSoftness, 1.0, length(vd)) * _VignetteStrength;
                col *= vignette;

                fixed4 outColor = fixed4(col * i.color.rgb, i.color.a);

                #ifdef UNITY_UI_CLIP_RECT
                outColor.a *= UnityGet2DClipping(i.worldPos.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(outColor.a - 0.001);
                #endif

                return outColor;
            }
            ENDCG
        }
    }
}
