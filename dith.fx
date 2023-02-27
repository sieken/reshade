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

/* Two color (or simulated 1 bit) dithering FX shader, inspired by, and trying to achieve a similar effect as seen in,
 * Return of the Obra Dinn by applying ordered dithering. I think Obra Dinn uses blue
 * noise in their effect, which is possibly something to add as an option to this shader,
 * but I am partial to the look of ordered dithering, and decided that I wanted to see how
 * that looks. */

#include "ReShade.fxh"
#include "Util.fxh"

uniform float3 fDither_Color1 < ui_type = "color"; > = float3(1.f, 1.f, 1.f);
uniform float3 fDither_Color2 < ui_type = "color"; > = float3(0.f, 0.f, 0.f);
uniform float fBayer_R < ui_type = "slider"; ui_min = 0.f; ui_max = 10.f; > = 3.127f;
uniform float fInput_Color_Range < ui_type = "slider"; ui_min = 1.f; ui_max = 8.f; > = 3.761f;
uniform float fThreshold_Divider < ui_type = "slider"; ui_min = .1f; ui_max = 8.f; > = 2.259f;
uniform float fBayer_N < ui_type = "slider"; ui_min = 4.f; ui_max = 8.f; ui_step = 4.f; > = 8.f;

// 8x8 Bayer matrix, when fBayer_N = 8
static const float Bayer8[] = {
          0.f,      0.5f,    0.125f,    0.625f,  0.03125f,  0.53125f,  0.15625f,  0.65625f,
        0.75f,     0.25f,    0.875f,    0.375f,  0.78125f,  0.28125f,  0.90625f,  0.40625f,
      0.1875f,   0.6875f,   0.0625f,   0.5625f,  0.21875f,  0.71875f,  0.09375f,  0.59375f,
      0.9375f,   0.4375f,   0.8125f,   0.3125f,  0.96875f,  0.46875f,  0.84375f,  0.34375f,
    0.046875f, 0.546875f, 0.171875f, 0.671875f, 0.015625f, 0.515625f, 0.140625f, 0.640625f,
    0.796875f, 0.296875f, 0.921875f, 0.421875f, 0.765625f, 0.265625f, 0.890625f, 0.390625f,
    0.234375f, 0.734375f, 0.109375f, 0.609375f, 0.203125f, 0.703125f, 0.078125f, 0.578125f,
    0.984375f, 0.484375f, 0.859375f, 0.359375f, 0.953125f, 0.453125f, 0.828125f, 0.328125f
};

// ++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++

void PS_Dither_Apply(
    float4 vpos : SV_Position,
    float2 texcoord : TEXCOORD,
    out float4 col : SV_Target0
) {
    float3 input_col = tex2D(ReShade::BackBuffer, texcoord.xy).rgb;
    float2 bayer_index = (float2) mod(vpos, fBayer_N);
    float bayer_val = Bayer8[int(bayer_index.y * fBayer_N + bayer_index.x)] * .5;
    float output_col = greyscale(input_col * .8 + fBayer_R * bayer_val).r;

    col.rgb = output_col <= (fInput_Color_Range / fThreshold_Divider)
        ? fDither_Color2
        : fDither_Color1;
}

// ++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++

technique Dither {
    pass Dither_Apply {
        VertexShader = PostProcessVS;
        PixelShader = PS_Dither_Apply;
    }
}