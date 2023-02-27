/*
 Copyright (c) 2023 sieken

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


 /* Based on Jorge Jimenez (Activision, 2014),
  * http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
  * Creating a bloom effect using a custom 13 tap weighted downsampling together with a
  * tent filter upsampling.
*/

#include "ReShade.fxh"
#include "Util.fxh"

// ++++ Uniforms, predefines and consts

#ifndef LERP_COMBINE
    #define LERP_COMBINE 1
#endif
#ifndef USE_THRESHOLD
    #define USE_THRESHOLD 1
#endif

uniform float fBloomEffect < ui_type = "slider"; ui_min = 0.f; ui_max = 1.f; > = 1.f;
uniform float fBloomRadius < ui_type = "slider"; ui_min = 0.f; ui_max = 1.f; > = .25f;
uniform float fExposure < ui_type = "slider"; ui_min = 0.f; ui_max = 10.f; > = .85f;
uniform float fBrightnessThreshold < ui_type = "slider"; ui_min = 0.f; ui_max = 10.f; > = 1.f;

// ++++ Textures/Samplers

texture Downsample_1_Target { Width = BUFFER_WIDTH / 2.f; Height = BUFFER_HEIGHT / 2.f; Format = RGBA16; };
texture Downsample_2_Target { Width = BUFFER_WIDTH / 4.f; Height = BUFFER_HEIGHT / 4.f; Format = RGBA16; };
texture Downsample_3_Target { Width = BUFFER_WIDTH / 8.f; Height = BUFFER_HEIGHT / 8.f; Format = RGBA16; };
texture Downsample_4_Target { Width = BUFFER_WIDTH / 16.f; Height = BUFFER_HEIGHT / 16.f; Format = RGBA16; };
texture Downsample_5_Target { Width = BUFFER_WIDTH / 32.f; Height = BUFFER_HEIGHT / 32.f; Format = RGBA16; };
texture Downsample_6_Target { Width = BUFFER_WIDTH / 64.f; Height = BUFFER_HEIGHT / 64.f; Format = RGBA16; };
texture Downsample_7_Target { Width = BUFFER_WIDTH / 128.f; Height = BUFFER_HEIGHT / 128.f; Format = RGBA16; };
texture Downsample_8_Target { Width = BUFFER_WIDTH / 256.f; Height = BUFFER_HEIGHT / 256.f; Format = RGBA16; };

sampler Downsample_8_Sampler { Texture = Downsample_8_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_7_Sampler { Texture = Downsample_7_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_6_Sampler { Texture = Downsample_6_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_5_Sampler { Texture = Downsample_5_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_4_Sampler { Texture = Downsample_4_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_3_Sampler { Texture = Downsample_3_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_2_Sampler { Texture = Downsample_2_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Downsample_1_Sampler { Texture = Downsample_1_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

texture Upsample_1_Target { Width = BUFFER_WIDTH / 2.f; Height = BUFFER_HEIGHT / 2.f; Format = RGBA16; };
texture Upsample_2_Target { Width = BUFFER_WIDTH / 4.f; Height = BUFFER_HEIGHT / 4.f; Format = RGBA16; };
texture Upsample_3_Target { Width = BUFFER_WIDTH / 8.f; Height = BUFFER_HEIGHT / 8.f; Format = RGBA16; };
texture Upsample_4_Target { Width = BUFFER_WIDTH / 16.f; Height = BUFFER_HEIGHT / 16.f; Format = RGBA16; };
texture Upsample_5_Target { Width = BUFFER_WIDTH / 32.f; Height = BUFFER_HEIGHT / 32.f; Format = RGBA16; };
texture Upsample_6_Target { Width = BUFFER_WIDTH / 64.f; Height = BUFFER_HEIGHT /  64.f; Format = RGBA16; };
texture Upsample_7_Target { Width = BUFFER_WIDTH / 128.f; Height = BUFFER_HEIGHT / 128.f; Format = RGBA16; };

sampler Upsample_7_Sampler { Texture = Upsample_7_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_6_Sampler { Texture = Upsample_6_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_5_Sampler { Texture = Upsample_5_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_4_Sampler { Texture = Upsample_4_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_3_Sampler { Texture = Upsample_3_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_2_Sampler { Texture = Upsample_2_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler Upsample_1_Sampler { Texture = Upsample_1_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

texture Brightness_Threshold_Target { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16; };
sampler Brightness_Threshold_Sampler { Texture = Brightness_Threshold_Target; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

// ++++ Shader funcs

float4 PS_Brightness_Threshold(float4 pos : SV_Position, float2 uv :  TEXCOORD) : SV_Target {
    float4 input_col = tex2D(ReShade::BackBuffer, uv);
    #if USE_THRESHOLD
        float4 comp_value = greyscale(input_col.rgb).r;
        input_col = (comp_value <= fBrightnessThreshold) ? float4(0.f, 0.f, 0.f, input_col.a) : input_col;
    #endif
    return input_col;
}

float4 PS_Downsample_1(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Brightness_Threshold_Sampler, uv, 2.f).rgb, 1.f);
}
float4 PS_Downsample_2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_1_Sampler, uv, 4.f).rgb, 1.f);
}
float4 PS_Downsample_3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_2_Sampler, uv, 8.f).rgb, 1.f);
}
float4 PS_Downsample_4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_3_Sampler, uv, 16.f).rgb, 1.f);
}
float4 PS_Downsample_5(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_4_Sampler, uv, 32.f).rgb, 1.f);
}
float4 PS_Downsample_6(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_5_Sampler, uv, 64.f).rgb, 1.f);
}
float4 PS_Downsample_7(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_6_Sampler, uv, 128.f).rgb, 1.f);
}
float4 PS_Downsample_8(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(Downsample13(Downsample_7_Sampler, uv, 256.f).rgb, 1.f);
}

float4 PS_Upsample_7(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Downsample_8_Sampler, uv, float2(2.f, 2.f), float2(2.f, 2.f));
    float4 input_col = tex2D(Downsample_7_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_6(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_7_Sampler, uv, float2(4.f, 4.f), float2(4.f, 4.f));
    float4 input_col = tex2D(Downsample_6_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_5(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_6_Sampler, uv, float2(8.f, 8.f), float2(8.f, 8.f));
    float4 input_col = tex2D(Downsample_5_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_4(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_5_Sampler, uv, float2(16.f, 16.f), float2(16.f, 16.f));
    float4 input_col = tex2D(Downsample_4_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_4_Sampler, uv, float2(32.f, 32.f), float2(32.f, 32.f));
    float4 input_col = tex2D(Downsample_3_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_3_Sampler, uv, float2(64.f, 64.f), float2(64.f, 64.f));
    float4 input_col = tex2D(Downsample_2_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}
float4 PS_Upsample_1(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 upsampled_col = UpsampleTent(Upsample_2_Sampler, uv, float2(128.f, 128.f), float2(128.f, 128.f));
    float4 input_col = tex2D(Downsample_1_Sampler, uv);
    #if defined(LERP_COMBINE)
        return lerp(upsampled_col, input_col, fBloomRadius);
    #else
        return input_col + upsampled_col;
    #endif
}

void PS_Blend(float4 pos : SV_Position, float2 uv : TEXCOORD, out float4 col : SV_Target0) {
    float4 input_col = tex2D(ReShade::BackBuffer, uv);
    float4 up1 = UpsampleTent(Upsample_1_Sampler, uv, 256.f, 256.f);
    col = input_col + GLTonemapper(lerp(float4(0., 0., 0., 0.), up1, fBloomEffect), fExposure);
}

// +++++ Passes

technique Bloom {
    // TODO: Resampling in compute shaders?

    // Only sample colors above threshold
    pass Brightness_Threshold { VertexShader = PostProcessVS; PixelShader = PS_Brightness_Threshold; RenderTarget = Brightness_Threshold_Target; }

    // Number of downsamples should correspond to resolution, I usually run
    // on 1920x1080, so 8 downsamples makes sense for me. Could possibly base
    // number of downsamples on a predefine later on
    pass Downsample_1 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_1; RenderTarget = Downsample_1_Target; }
    pass Downsample_2 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_2; RenderTarget = Downsample_2_Target; }
    pass Downsample_3 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_3; RenderTarget = Downsample_3_Target; }
    pass Downsample_4 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_4; RenderTarget = Downsample_4_Target; }
    pass Downsample_5 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_5; RenderTarget = Downsample_5_Target; }
    pass Downsample_6 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_6; RenderTarget = Downsample_6_Target; }
    pass Downsample_7 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_7; RenderTarget = Downsample_7_Target; }
    pass Downsample_8 { VertexShader = PostProcessVS; PixelShader = PS_Downsample_8; RenderTarget = Downsample_8_Target; }

    // Upsample + combine until we're back to original resolution and then...
    pass Upsample_7 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_7; RenderTarget = Upsample_7_Target; }
    pass Upsample_6 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_6; RenderTarget = Upsample_6_Target; }
    pass Upsample_5 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_5; RenderTarget = Upsample_5_Target; }
    pass Upsample_4 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_4; RenderTarget = Upsample_4_Target; }
    pass Upsample_3 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_3; RenderTarget = Upsample_3_Target; }
    pass Upsample_2 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_2; RenderTarget = Upsample_2_Target; }
    pass Upsample_1 { VertexShader = PostProcessVS; PixelShader = PS_Upsample_1; RenderTarget = Upsample_1_Target; }

    // ... Blend it with input
    pass Blend { VertexShader = PostProcessVS; PixelShader = PS_Blend; }
}