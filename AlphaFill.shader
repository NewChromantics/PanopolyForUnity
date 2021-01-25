Shader "Panopoly/AlphaFill"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle]ApplyFill("ApplyFill",float)=1
        [Toggle]Debug_Filled("Debug_Filled",float)=0
        [Toggle]Debug_Failed("Debug_Failed",float)=0
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            float ApplyFill;
#define APPLY_FILL  (ApplyFill>0)
            float Debug_Filled;
            float Debug_Failed;
        #define DEBUG_FILLED    (Debug_Filled>0)
        #define DEBUG_FAILED    (Debug_Failed>0)

#define SOURCE_TEXTURE  _MainTex
#define SOURCE_TEXTURE_TEXELSIZE (_MainTex_TexelSize.xy)
#define NO_MAIN
#define vec2    float2
#define vec3    float3
#define vec4    float4

            #include "AlphaFill.frag.glsl"

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return AlphaFillFrag(i.uv);
            }
            ENDCG

        }
    }
}
