#ifndef _PBRLIBRARY_HLSL_
#define _PBRLIBRARY_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float BlinnPhong(float3 normal, float3 lightDir, float3 viewDir, float smoothness)
{
    float3 halfDir = normalize(lightDir+viewDir);
    return pow(saturate(dot(halfDir, normal)), smoothness);
}

float NormalDistributionFunction(float3 normal, float3 halfDir, float roughness)
{
    // Trowbridge-Reitz GGX
    float roughness2 = roughness*roughness;
    float NoH = saturate(dot(normal, halfDir));
    float NoH2 = NoH*NoH;

    float nom = roughness2;
    float denom = (NoH2*(roughness2-1.0)+1.0);
    denom = PI*denom*denom;
    return nom/denom;
}

float GeometrySchlickGGX(float NoV, float k)
{
    float nom = NoV;
    float denom = NoV*(1.0-k) + k;
    return nom/denom;
}

float GeometrySmith(float3 normal, float3 viewDir, float3 lightDir, float k)
{
    float NoV = saturate(dot(normal, viewDir));
    float NoL = saturate(dot(normal, lightDir));
    return GeometrySchlickGGX(NoV, k)*GeometrySchlickGGX(NoL, k);
}

float GeometryFunction(float3 normal, float3 viewDir, float3 lightDir, float roughness)
{
    float k = (roughness+1)*(roughness+1)/8; // direct light remapping
    return GeometrySmith(normal, viewDir, lightDir, k);
}

float3 FresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float3 FresnelFunction(float3 normal, float3 viewDir, float3 surfaceColor, float metalness)
{
    float cosTheta = saturate(dot(normal, viewDir));
    float3 F0 = float3(0.04, 0.04, 0.04);
    F0 = lerp(F0, surfaceColor, metalness); // 非金属表面反射率默认0.04, 金属为表面颜色
    return FresnelSchlick(cosTheta, F0);
}


float3 DirectLightBRDF(float3 lightDir, float3 viewDir, float3 normal, float3 surfaceColor, float roughness, float metallic)
{
    // Lambert
    float3 diffuse = surfaceColor/PI;

    // cook-torrance
    float3 halfDir = normalize(lightDir+viewDir);
    float D = NormalDistributionFunction(normal, halfDir, roughness); // 法线分布函数
    float G = GeometryFunction(normal, viewDir, lightDir, roughness); // 几何遮蔽函数
    float3 F = FresnelFunction(normal, viewDir, surfaceColor, metallic); // 菲涅尔项: 表示光线被反射的百分比
    float3 specular = D*G*F/(4*saturate(dot(lightDir, normal))*saturate(dot(viewDir, normal))+0.001); // 注意除0错误
    
    float3 Ks = F; // 菲涅尔项表示光线被反射的百分比, 即Ks
    float3 kD = (float3(1,1,1)-Ks);
    kD *= 1.0-metallic; // 物体为金属时metallic为1, 没有漫反射
    return kD*diffuse+specular; // specular没有乘Ks, 因为cook-torrance brdf公式中已经乘了F, F与Ks是相等的
}

float3 DirectLightFunction(float3 lightDir, float3 viewDir, float3 normal, float3 lightIn, float3 surfaceColor, float roughness, float metallic)
{
    float cosTheta = saturate(dot(normal, lightDir));
    return DirectLightBRDF(lightDir, viewDir, normal, surfaceColor, roughness, metallic) * cosTheta * lightIn * PI; // 为符合Unity的光照, 多乘以一个系数PI
}

float3 IndirectDiffuse(float3 normal, float3 viewDir, float3 surfaceColor)
{
    float3 sh = SampleSH(normal);
    float cosTheta = saturate(dot(normal, viewDir));
    return sh*cosTheta*surfaceColor/PI;
}

// 预积分BRDF 使用 Split sum 方法
TEXTURE2D(BRDFIntegrationMap);
SAMPLER(sampler_BRDFIntegrationMap);

// Env BRDF
float3 IndirectSpecular(float3 viewDir, float3 normal, float roughness, float3 F)
{
    float3 reflectDir = reflect(-viewDir, normal);
    float3 envColor = GlossyEnvironmentReflection(reflectDir, sqrt(roughness), 1);
    float NoV = saturate(dot(viewDir, normal));
    float2 envBRDF = SAMPLE_TEXTURE2D(BRDFIntegrationMap, sampler_BRDFIntegrationMap, float2(NoV, roughness)).rg;
    return envColor * (F * envBRDF.x + envBRDF.y); // Split Sum
}

float3 IndirectLighting(float3 normal, float3 viewDir, float3 surfaceColor, float roughness, float metallic)
{
    float3 diffuse = IndirectDiffuse(normal, viewDir, surfaceColor);

    float3 F = FresnelFunction(normal, viewDir, surfaceColor, metallic);
    float3 Kd = float3(1,1,1)-F;
    Kd*=(1-metallic);

    float3 specular = IndirectSpecular(viewDir, normal, roughness, F);
    
    return (specular+Kd*diffuse);
    
}

#endif