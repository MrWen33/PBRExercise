Shader "Unlit/PBR Shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_MetallicMap ("Metallic Map", 2D) = "black" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _NormalMap("Normal map", 2D) = "bump" {}
        _BumpScale("Bump Scale", Range(0, 5)) = 1
        _Specular("Specular", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0
        _BRDFIntegrationMap("BRDF IntegrationMap", 2D) = "white"
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "PBRLibrary.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
                float4 tangent: TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                float3 tangent: TEXCOORD3;
                float3 bitangent: TEXCOORD4;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            TEXTURE2D(_MetallicMap);
            SAMPLER(sampler_MetallicMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            float4 _MainTex_ST;
            float _Specular;
            float _Smoothness;
            float _BumpScale;
            float _Metallic;

            // From SurfaceInput.hlsl
            half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = 1.0h)
            {
            #ifdef _NORMALMAP
                half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
                #if BUMP_SCALE_NOT_SUPPORTED
                    return UnpackNormal(n);
                #else
                    return UnpackNormalScale(n, scale);
                #endif
            #else
                return half3(0.0h, 0.0h, 1.0h);
            #endif
            }

            v2f vert (appdata v)
            {
                v2f o;
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.tangent = normalInput.tangentWS;
                o.normal = normalInput.normalWS;
                o.bitangent = normalInput.bitangentWS;
                o.worldPos = TransformObjectToWorld(v.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float3 lightDir = normalize(GetMainLight().direction);
                float3 viewDir = normalize(GetCameraPositionWS()-i.worldPos);
                Light light = GetMainLight();
                float3 lightColor = light.color*light.distanceAttenuation;

                float3 tangentNormal = SampleNormal(i.uv, TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), _BumpScale);
                float3 normalWS = TransformTangentToWorld(tangentNormal,
                    float3x3(normalize(i.tangent), normalize(i.bitangent), normal));

                // sample the texture
                float4 surfaceColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float metallic = SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, i.uv).g;
                metallic = _Metallic;
                float3 result = DirectLightFunction(lightDir, viewDir, normalWS, lightColor, surfaceColor, 1-_Smoothness, metallic);
                result +=IndirectLighting(normalWS, viewDir, surfaceColor, 1-_Smoothness, metallic);

                
                return float4(result, 1);
            }
            ENDHLSL
        }
    }
}
