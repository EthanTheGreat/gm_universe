sampler2D frameBuffer : register(s0);  // Not using this anymore
sampler2D planetTexture : register(s1);  // Not using this anymore



struct PS_INPUT
{
    float4 pos   : POSITION;
    float2 uv    : TEXCOORD0;
    float4 fragPos : TEXCOORD1;
    float3 ray : TEXCOORD2;
};

// Constants (Passed from Lua)
const float4 Constants0 : register(c0);  // Planet center and radius
const float4 Constants1 : register(c1);  // Light direction (sun)
const float4 Constants2 : register(c2);  // Rayleigh scattering color (blue)
const float4 Constants3 : register(c3);  // Mie scattering color (sunlight glow)

const float2 ScreenSize : register(c5);  // Screen dimensions (width, height)
const float4 EyePosition : register( c11 );

float4x4 inverse(float4x4 m) {
    float n11 = m[0][0], n12 = m[1][0], n13 = m[2][0], n14 = m[3][0];
    float n21 = m[0][1], n22 = m[1][1], n23 = m[2][1], n24 = m[3][1];
    float n31 = m[0][2], n32 = m[1][2], n33 = m[2][2], n34 = m[3][2];
    float n41 = m[0][3], n42 = m[1][3], n43 = m[2][3], n44 = m[3][3];

    float t11 = n23 * n34 * n42 - n24 * n33 * n42 + n24 * n32 * n43 - n22 * n34 * n43 - n23 * n32 * n44 + n22 * n33 * n44;
    float t12 = n14 * n33 * n42 - n13 * n34 * n42 - n14 * n32 * n43 + n12 * n34 * n43 + n13 * n32 * n44 - n12 * n33 * n44;
    float t13 = n13 * n24 * n42 - n14 * n23 * n42 + n14 * n22 * n43 - n12 * n24 * n43 - n13 * n22 * n44 + n12 * n23 * n44;
    float t14 = n14 * n23 * n32 - n13 * n24 * n32 - n14 * n22 * n33 + n12 * n24 * n33 + n13 * n22 * n34 - n12 * n23 * n34;

    float det = n11 * t11 + n21 * t12 + n31 * t13 + n41 * t14;
    float idet = 1.0f / det;

    float4x4 ret;

    ret[0][0] = t11 * idet;
    ret[0][1] = (n24 * n33 * n41 - n23 * n34 * n41 - n24 * n31 * n43 + n21 * n34 * n43 + n23 * n31 * n44 - n21 * n33 * n44) * idet;
    ret[0][2] = (n22 * n34 * n41 - n24 * n32 * n41 + n24 * n31 * n42 - n21 * n34 * n42 - n22 * n31 * n44 + n21 * n32 * n44) * idet;
    ret[0][3] = (n23 * n32 * n41 - n22 * n33 * n41 - n23 * n31 * n42 + n21 * n33 * n42 + n22 * n31 * n43 - n21 * n32 * n43) * idet;

    ret[1][0] = t12 * idet;
    ret[1][1] = (n13 * n34 * n41 - n14 * n33 * n41 + n14 * n31 * n43 - n11 * n34 * n43 - n13 * n31 * n44 + n11 * n33 * n44) * idet;
    ret[1][2] = (n14 * n32 * n41 - n12 * n34 * n41 - n14 * n31 * n42 + n11 * n34 * n42 + n12 * n31 * n44 - n11 * n32 * n44) * idet;
    ret[1][3] = (n12 * n33 * n41 - n13 * n32 * n41 + n13 * n31 * n42 - n11 * n33 * n42 - n12 * n31 * n43 + n11 * n32 * n43) * idet;

    ret[2][0] = t13 * idet;
    ret[2][1] = (n14 * n23 * n41 - n13 * n24 * n41 - n14 * n21 * n43 + n11 * n24 * n43 + n13 * n21 * n44 - n11 * n23 * n44) * idet;
    ret[2][2] = (n12 * n24 * n41 - n14 * n22 * n41 + n14 * n21 * n42 - n11 * n24 * n42 - n12 * n21 * n44 + n11 * n22 * n44) * idet;
    ret[2][3] = (n13 * n22 * n41 - n12 * n23 * n41 - n13 * n21 * n42 + n11 * n23 * n42 + n12 * n21 * n43 - n11 * n22 * n43) * idet;

    ret[3][0] = t14 * idet;
    ret[3][1] = (n13 * n24 * n31 - n14 * n23 * n31 + n14 * n21 * n33 - n11 * n24 * n33 - n13 * n21 * n34 + n11 * n23 * n34) * idet;
    ret[3][2] = (n14 * n22 * n31 - n12 * n24 * n31 - n14 * n21 * n32 + n11 * n24 * n32 + n12 * n21 * n34 - n11 * n22 * n34) * idet;
    ret[3][3] = (n12 * n23 * n31 - n13 * n22 * n31 + n13 * n21 * n32 - n11 * n23 * n32 - n12 * n21 * n33 + n11 * n22 * n33) * idet;

    return ret;
}

// Rayleigh phase function
float RayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * 3.14159265358979323846)) * (1.0 + cosTheta * cosTheta);
}

// Mie phase function
float MiePhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265358979323846 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}


float4 main(PS_INPUT i) : COLOR
{
    float4x4 inverseViewMatrix = inverse(float4x4(
        Constants0,
        Constants1,
        Constants2,
        float4(0, 0, 0, 1)
    ));
    
    float aspectRatio = ScreenSize.x / ScreenSize.y;
    float3 correctedRay = float3(i.ray.x / aspectRatio, i.ray.y, i.ray.z);
    float4 rayView = float4(correctedRay, 1.0);
    float4 rayWorld = mul(rayView, inverseViewMatrix);
    float3 rayDir = normalize(rayWorld.xyz / rayWorld.w);

    // Sphere setup
    float3 sphereCenter = Constants3.xyz;
    float sphereRadius = 0.5;           // Planet radius
    float atmosphereRadius = 0.55;       // Make the atmosphere much bigger for debugging

    float3 oc = EyePosition.xyz - sphereCenter;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(oc, rayDir);
    float cPlanet = dot(oc, oc) - sphereRadius * sphereRadius;
    float cAtmosphere = dot(oc, oc) - atmosphereRadius * atmosphereRadius;

    float discriminantPlanet = b * b - 4 * a * cPlanet;
    float discriminantAtmosphere = b * b - 4 * a * cAtmosphere;
    
    bool hitPlanet = (discriminantPlanet >= 0.0);
    bool hitAtmosphere = (discriminantAtmosphere >= 0.0);
    
    if (!hitPlanet && !hitAtmosphere) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // ---- Planet Rendering ----
    if (hitPlanet) {
        float t = (-b - sqrt(discriminantPlanet)) / (2.0 * a);
        if(t > 0){
            float3 hitPoint = EyePosition.xyz + t * rayDir;
            float3 normal = normalize(hitPoint - sphereCenter);
            
            // Texture mapping
            float phi = atan2(normal.z, normal.x);
            float theta = acos(normal.y);
            float u = (phi + 3.14159265358979323846) / (2.0 * 3.14159265358979323846);
            float v = theta / 3.14159265358979323846;

            float4 planetColor = tex2D(planetTexture, float2(u, v));
            // ---- Shadow Calculation ----
            float3 lightDir = normalize(float3(0, 0, 1)); // Sun direction
            float cosTheta = dot(normal, -lightDir); // Shadow factor
            
            // Apply shadow factor: higher cosTheta means more light, lower means more shadow
            float shadowFactor = max(cosTheta, 0.01); // Ensure a default shadow factor to make UV visible
            
            // Apply the shadow to the planet color
            planetColor.rgb *= shadowFactor;
            
            return planetColor;
        }
    }

    // ---- Atmosphere Debug Rendering ----
    if (hitAtmosphere) {
        float t = (-b - sqrt(discriminantAtmosphere)) / (2.0 * a);


        if(t < 0 && length(oc) > atmosphereRadius){ // Eliminate inverse when outside, when inside allow it to pass.
            return float4( 0, 0, 0, 1);
        }

        if(t<0){
            t = -t;
            rayDir = -rayDir;
        }

        float3 lightDir = normalize(float3(0, 0, 1)); // Sun direction
        float cosTheta = dot(rayDir, lightDir);

        // 🔵 Rayleigh: More blue tint farther from the surface
        float3 rayleighCoeff = float3(0.2, 0.4, 1.0) * 3.0; // Balanced strength
        float rayleighPhase = RayleighPhase(cosTheta);
        float3 rayleighScattering = rayleighCoeff * rayleighPhase;
        
        // ☀️ Mie: More glow near light direction
        float3 mieCoeff = float3(1.0, 0.8, 0.6) * 1.0; // Balanced strength
        float miePhase = MiePhase(cosTheta, 0.76);
        float3 mieScattering = mieCoeff * miePhase;

        float3 scattering = rayleighScattering + mieScattering;

        // Blending atmosphere with planet (soft overlay)
        // 🌌 Fade into space
        float blendFactor = smoothstep(0.1, 0.5, t); // Smooth transition at edges
        float3 finalColor = lerp(float3(0.3, 0.5, 0.7), scattering, blendFactor);

        // In Eye Check


        return float4(finalColor, 1.0);
    }


    return float4(0.0, 0.0, 0.0, 1.0);
}