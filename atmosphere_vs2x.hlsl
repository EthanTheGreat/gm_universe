/*
    Written by EthanTheGreat. 03/11/2025 - 4:59AM EST
*/

const float4x4 cViewProj : register(c8); 
const float4 cViewProjZ  : register(c12);

const float2 ScreenSize : register(c5);  // Screen dimensions (width, height)

struct VS_INPUT
{
    float4 vPos  : POSITION;
    float2 uv    : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 pos   : POSITION; // Inaccessable via pixel shader
    float2 uv    : TEXCOORD0;
    float4 fragPos : TEXCOORD1; // Why not
    float3 ray : TEXCOORD2;
};

VS_OUTPUT main(const VS_INPUT v)
{
    // Transform to clip space
    float4 vProjPos = mul(v.vPos, cViewProj);
        vProjPos.z = dot(v.vPos, cViewProjZ);

    // Convert UV to NDC (-1 to 1)
    float2 ndc = v.uv * 2.0 - 1.0;
        ndc.y = -ndc.y; // Flip Y for correct orientation

    // View-space ray direction (Assuming full-screen quad)
   

    VS_OUTPUT o = (VS_OUTPUT)0;
        o.pos = vProjPos;
        o.uv = v.uv;
        o.fragPos = vProjPos; // We cannot pass pos
        o.ray = normalize(float3(ndc, 1.0));
    return o;
}