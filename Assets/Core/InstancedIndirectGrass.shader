Shader "MobileDrawMeshInstancedIndirect/SingleGrass"
{
    //This is litteraly the grass shader of Colin Leung from his repo:
    //https://github.com/ColinLeung-NiloCat/UnityURP-MobileDrawMeshInstancedIndirectExample
    //If you want a better documented version check his repo
    //The only changes I did here is instead of having two Buffers we have only one that simply stores the positions + adding a random offset to it
    //also removing the grass bending logic

    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        _BaseColorTexture("_BaseColorTexture", 2D) = "white" {}
        _GroundColor("_GroundColor", Color) = (0.5,0.5,0.5)

        [Header(Grass Shape)]
        _GrassWidth("_GrassWidth", Float) = 1
        _GrassHeight("_GrassHeight", Float) = 1

        [Header(Wind)]
        _WindAIntensity("_WindAIntensity", Float) = 1.77
        _WindAFrequency("_WindAFrequency", Float) = 4
        _WindATiling("_WindATiling", Vector) = (0.1,0.1,0)
        _WindAWrap("_WindAWrap", Vector) = (0.5,0.5,0)

        _WindBIntensity("_WindBIntensity", Float) = 0.25
        _WindBFrequency("_WindBFrequency", Float) = 7.7
        _WindBTiling("_WindBTiling", Vector) = (.37,3,0)
        _WindBWrap("_WindBWrap", Vector) = (0.5,0.5,0)


        _WindCIntensity("_WindCIntensity", Float) = 0.125
        _WindCFrequency("_WindCFrequency", Float) = 11.7
        _WindCTiling("_WindCTiling", Vector) = (0.77,3,0)
        _WindCWrap("_WindCWrap", Vector) = (0.5,0.5,0)

        [Header(Lighting)]
        _RandomNormal("_RandomNormal", Float) = 0.15
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            Cull Back
            ZTest Less
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                half3 color        : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float _GrassWidth;
                float _GrassHeight;

                float _WindAIntensity;
                float _WindAFrequency;
                float2 _WindATiling;
                float2 _WindAWrap;

                float _WindBIntensity;
                float _WindBFrequency;
                float2 _WindBTiling;
                float2 _WindBWrap;

                float _WindCIntensity;
                float _WindCFrequency;
                float2 _WindCTiling;
                float2 _WindCWrap;

                half3 _BaseColor;
                float4 _BaseColorTexture_ST;
                half3 _GroundColor;

                half _RandomNormal;
                float _OffsetRange;

                StructuredBuffer<float3> _InstancesPosWSBuffer;
            CBUFFER_END

            sampler2D _BaseColorTexture;

            half3 ApplySingleDirectLight(Light light, half3 N, half3 V, half3 albedo, half positionOSY)
            {
                half3 H = normalize(light.direction + V);

                half directDiffuse = dot(N, light.direction) * 0.5 + 0.5;

                float directSpecular = saturate(dot(N,H));
                directSpecular *= directSpecular;
                directSpecular *= directSpecular;
                directSpecular *= directSpecular;

                directSpecular *= 0.1 * positionOSY;

                half3 lighting = light.color * (light.shadowAttenuation * light.distanceAttenuation);
                half3 result = (albedo * directDiffuse + directSpecular) * lighting;

                return result; 
            }

            float murmurHash3(float input) {
                uint h = abs(input);
                h ^= h >> 16;
                h *= 0x85ebca6b;
                h ^= h >> 13;
                h *= 0xc2b2ae3d;
                h ^= h >> 16;
                float t = h / 4294967295.0;
                return t * 2 - 1;
            }

            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT;

                float3 perGrassPivotPosWS = _InstancesPosWSBuffer[instanceID];

                //Adding a random offset to the position
                perGrassPivotPosWS.x += murmurHash3(perGrassPivotPosWS.x * 23.4643 + perGrassPivotPosWS.z) * _OffsetRange;
                perGrassPivotPosWS.z += murmurHash3(perGrassPivotPosWS.x * 12.9898 + perGrassPivotPosWS.z * 78.233) * _OffsetRange;

                //Billboard Logic
                float3 cameraTransformRightWS = UNITY_MATRIX_V[0].xyz;
                float3 cameraTransformUpWS = UNITY_MATRIX_V[1].xyz;
                float3 cameraTransformForwardWS = -UNITY_MATRIX_V[2].xyz;

                float3 positionOS = IN.positionOS.x * cameraTransformRightWS * _GrassWidth * (sin(perGrassPivotPosWS.x*95.4643 + perGrassPivotPosWS.z) * 0.45 + 0.55);
                positionOS += IN.positionOS.y * cameraTransformUpWS;

                //Per grass height scale
                float perGrassHeight = lerp(2, 5, (sin(perGrassPivotPosWS.x * 23.4643 + perGrassPivotPosWS.z) * 0.45 + 0.55)) * _GrassHeight;
                positionOS.y *= perGrassHeight;

                //Camera distance scale (make grass width larger if grass is far away to camera, to hide smaller than pixel size triangle flicker)        
                float3 viewWS = _WorldSpaceCameraPos - perGrassPivotPosWS;
                float ViewWSLength = length(viewWS);
                positionOS += cameraTransformRightWS * IN.positionOS.x * max(0, ViewWSLength * 0.0225);

                //posOS -> posWS
                float3 positionWS = positionOS + perGrassPivotPosWS;

                //wind animation (biilboard Left Right direction only sin wave)            
                float wind = 0;
                wind += (sin(_Time.y * _WindAFrequency + perGrassPivotPosWS.x * _WindATiling.x + perGrassPivotPosWS.z * _WindATiling.y)*_WindAWrap.x+_WindAWrap.y) * _WindAIntensity;
                wind += (sin(_Time.y * _WindBFrequency + perGrassPivotPosWS.x * _WindBTiling.x + perGrassPivotPosWS.z * _WindBTiling.y) * _WindBWrap.x + _WindBWrap.y) * _WindBIntensity;
                wind += (sin(_Time.y * _WindCFrequency + perGrassPivotPosWS.x * _WindCTiling.x + perGrassPivotPosWS.z * _WindCTiling.y)*_WindCWrap.x+_WindCWrap.y) * _WindCIntensity;
                wind *= IN.positionOS.y;
                float3 windOffset = cameraTransformRightWS * wind;
                positionWS.xyz += windOffset;
                
                //posWS -> posCS
                OUT.positionCS = TransformWorldToHClip(positionWS);

                //Lighting Stuff
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(positionWS));
                half3 randomAddToN = (_RandomNormal* sin(perGrassPivotPosWS.x * 82.32523 + perGrassPivotPosWS.z) + wind * -0.25) * cameraTransformRightWS;
                half3 N = normalize(half3(0,1,0) + randomAddToN - cameraTransformForwardWS*0.5);
                half3 V = viewWS / ViewWSLength;

                half3 baseColor = tex2Dlod(_BaseColorTexture, float4(TRANSFORM_TEX(positionWS.xz,_BaseColorTexture),0,0)) * _BaseColor;
                half3 albedo = lerp(_GroundColor,baseColor, IN.positionOS.y);

                half3 lightingResult = SampleSH(0) * albedo;

                lightingResult += ApplySingleDirectLight(mainLight, N, V, albedo, positionOS.y);

                int additionalLightsCount = GetAdditionalLightsCount();
                for (int i = 0; i < additionalLightsCount; ++i)
                {
                    Light light = GetAdditionalLight(i, positionWS);
                    lightingResult += ApplySingleDirectLight(light, N, V, albedo, positionOS.y);
                }

                float fogFactor = ComputeFogFactor(OUT.positionCS.z);
                OUT.color = MixFog(lightingResult, fogFactor);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(IN.color,1);
            }
            ENDHLSL
        }
    }
}