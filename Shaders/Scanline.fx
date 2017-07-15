#include "ReShade.fxh"

float fmod(float a, float b) {
    float c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

float4 PS_Scanline(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    float3 col = tex2D(ReShade::BackBuffer, uv).rgb;
    float isBlack = fmod(floor(uv.y * BUFFER_HEIGHT), 2.0);
    col *= isBlack;
    return float4(col, 1.0);
}

technique Scanline {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_Scanline;
    }
}