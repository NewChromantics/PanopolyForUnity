Shader "Panopoly/NoiseMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange]Steps("Steps",Range(1,10) ) = 4
        [IntRange]MaxSampleDiffR_8("MaxSampleDiffR_8",Range(0,50))=10
        [IntRange]MaxSampleDiffG_8("MaxSampleDiffG_8",Range(0,50))=10
        [IntRange]MaxSampleDiffB_8("MaxSampleDiffB_8",Range(0,50))=10
        [Toggle]Debug_Loners("Debug_Loners",float)=0
        SampleWalkWeight("SampleWalkWeight",Range(0,1)) = 0.5
        [IntRange]LonerMaxWidth("LonerMaxWidth",Range(0,10))=1
        WalkStepSize("WalkStepSize",Range(0.5,5))=1
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

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

#define vec2    float2
#define vec3    float3
#define vec4    float4
#define GLSL_NO_MAIN
#define varying 
            #include "NoiseMask.frag.glsl"

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                return NoiseMask(i.uv);
            }
            ENDCG
        }
    }
}
